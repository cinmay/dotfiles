local M = {}

M.config = {
	command = "codex",
	done_sound = vim.fn.stdpath("config") .. "/lua/custom/codex/done.mp3",
	prompt_height = 18,
}

local state = { items = {}, item_index = {}, status = "Ready", busy = false }
local client, requests, timer
local history_buf, prompt_buf, history_win, prompt_win
local render_pending = false
local return_state, history_view, prompt_view
local changing_layout = false
local drafts = {}

local function notify(message, level)
	vim.notify("Codex: " .. message, level or vim.log.levels.INFO)
end

local function valid(win)
	return win and vim.api.nvim_win_is_valid(win)
end

local function stop_timer()
	if timer then
		timer:stop()
		timer:close()
		timer = nil
	end
end

local function title()
	if not valid(history_win) then
		return
	end
	local elapsed = state.elapsed or 0
	if state.started then
		elapsed = math.floor((vim.uv.hrtime() - state.started) / 1e9)
	end
	local status = requests and #requests.queue > 0 and "Response required" or state.status
	vim.wo[history_win].winbar = string
		.format(
			" Codex · %s · %s · %s · %02d:%02d ",
			state.model or "loading model",
			state.effort or "default effort",
			status,
			math.floor(elapsed / 60),
			elapsed % 60
		)
		:gsub("%%", "%%%%")
end

local function find_item(turn_id, item_id)
	local index = state.item_index[turn_id .. ":" .. item_id]
	return index and state.items[index].item
end

local function put_item(turn_id, item)
	local key = turn_id .. ":" .. item.id
	local index = state.item_index[key]
	if not index then
		index = #state.items + 1
		state.item_index[key] = index
	end
	state.items[index] = { turnId = turn_id, item = item }
end

local function render()
	if not history_buf or not vim.api.nvim_buf_is_valid(history_buf) then
		return
	end
	local lines = { "# " .. (state.name or "Codex"), "", "Directory: " .. (state.cwd or vim.fn.getcwd()) }
	if state.thread_id then
		table.insert(lines, "Session: " .. state.thread_id)
	end
	local function add(text)
		vim.list_extend(lines, vim.split(text, "\n", { plain = true }))
	end
	for _, entry in ipairs(state.items) do
		local item = entry.item
		if item.type == "userMessage" then
			add("\n## You\n")
			for _, content in ipairs(item.content or {}) do
				add(content.text or content.path or content.url or "[Attachment]")
			end
		elseif item.type == "agentMessage" or item.type == "plan" then
			add("\n## Codex\n\n" .. (item.text or ""))
		elseif item.type == "commandExecution" then
			add("\n• Ran " .. (item.command or "command") .. " · " .. (item.status or "running"))
		elseif item.type == "fileChange" then
			local paths = {}
			for _, change in ipairs(item.changes or {}) do
				table.insert(paths, change.path)
			end
			add("\n• Changed " .. (#paths > 0 and table.concat(paths, ", ") or "files") .. " · " .. (item.status or "in progress"))
		elseif item.type == "mcpToolCall" then
			add("\n• Tool " .. item.server .. "/" .. item.tool .. " · " .. (item.status or "running"))
		elseif item.type == "webSearch" then
			add("\n• Search: " .. item.query)
		end
	end
	if state.error then
		add("\n## Error\n\n" .. state.error)
	end
	if #state.items == 0 then
		add("\nWrite a prompt below. <leader>as sends; <leader>ar resumes a session.")
	end
	local follow = valid(history_win)
		and vim.api.nvim_win_get_cursor(history_win)[1] >= vim.api.nvim_buf_line_count(history_buf) - 1
	vim.bo[history_buf].modifiable = true
	vim.api.nvim_buf_set_lines(history_buf, 0, -1, false, lines)
	vim.bo[history_buf].modifiable = false
	if follow then
		vim.api.nvim_win_set_cursor(history_win, { #lines, 0 })
	end
	title()
end

local function schedule_render()
	if render_pending then
		return
	end
	render_pending = true
	vim.defer_fn(function()
		render_pending = false
		render()
	end, 40)
end

local function finish(status, err)
	if state.started then
		state.elapsed = math.floor((vim.uv.hrtime() - state.started) / 1e9)
	end
	state.started, state.turn_id = nil, nil
	state.busy, state.status, state.error = false, status, err
	stop_timer()
	requests:clear()
	schedule_render()
end

local function fail(err)
	state.loaded = false
	finish("Error", err)
	notify(err, vim.log.levels.ERROR)
end

local function notification(method, p)
	if method == "serverRequest/resolved" then
		requests:resolve(p.requestId)
		return
	end
	if p.threadId ~= state.thread_id then
		return
	end
	if method == "turn/started" then
		state.turn_id, state.busy, state.status = p.turn.id, true, "Running"
	elseif method == "turn/completed" then
		if state.turn_id and p.turn.id ~= state.turn_id then
			return
		end
		finish(p.turn.status, p.turn.error and p.turn.error.message)
		if p.turn.status == "completed" then
			local sound = M.config.done_sound
			if sound and vim.fn.filereadable(sound) == 1 and vim.fn.executable("mpv") == 1 then
				vim.fn.jobstart({ "mpv", "--no-video", "--really-quiet", sound }, { detach = true })
			end
		end
		notify("Turn " .. p.turn.status)
	elseif method == "item/started" or method == "item/completed" then
		put_item(p.turnId, p.item)
	elseif method == "item/agentMessage/delta" then
		local item = find_item(p.turnId, p.itemId)
		if not item then
			item = { id = p.itemId, type = "agentMessage", text = "" }
			put_item(p.turnId, item)
		end
		item.text = item.text .. p.delta
	elseif method == "item/commandExecution/outputDelta" then
		local item = find_item(p.turnId, p.itemId)
		if item then
			item.aggregatedOutput = (item.aggregatedOutput or "") .. p.delta
		end
	elseif method == "thread/name/updated" then
		state.name = p.threadName
	elseif method == "thread/settings/updated" then
		state.model = p.threadSettings.model
		state.effort = p.threadSettings.effort
	elseif method == "model/rerouted" then
		state.model = p.toModel
	elseif method == "thread/closed" then
		state.loaded = false
	elseif method == "error" then
		state.error = p.error and p.error.message or "Codex reported an error"
		if not p.willRetry then
			notify(state.error, vim.log.levels.ERROR)
		end
	end
	schedule_render()
end

local function ensure_client(callback)
	if not client then
		requests = require("custom.codex.requests").new(function(id, result, err)
			return client:reply(id, result, err)
		end, find_item, title)
		client = require("custom.codex.server").new(M.config.command, {
			notification = notification,
			request = function(request)
				if request.params.threadId ~= state.thread_id then
					client:reply(request.id, nil, { code = -32602, message = "This session is not open in Neovim" })
					return
				end
				requests:add(request)
			end,
			exit = function(err)
				if not state.exiting then
					fail(err)
				end
			end,
		})
	end
	client:start(function(err)
		if err then
			fail(err)
		else
			callback()
		end
	end)
end

local function prompt_text()
	if not prompt_buf or not vim.api.nvim_buf_is_valid(prompt_buf) then
		return ""
	end
	return table.concat(vim.api.nvim_buf_get_lines(prompt_buf, 0, -1, false), "\n")
end

local function remember_views()
	if valid(history_win) and vim.api.nvim_win_get_buf(history_win) == history_buf then
		history_view = vim.api.nvim_win_call(history_win, vim.fn.winsaveview)
	end
	if valid(prompt_win) and vim.api.nvim_win_get_buf(prompt_win) == prompt_buf then
		prompt_view = vim.api.nvim_win_call(prompt_win, vim.fn.winsaveview)
	end
end

local function restore_views()
	if valid(history_win) and history_view then
		vim.api.nvim_win_call(history_win, function()
			vim.fn.winrestview(history_view)
		end)
	end
	if valid(prompt_win) and prompt_view then
		vim.api.nvim_win_call(prompt_win, function()
			vim.fn.winrestview(prompt_view)
		end)
	end
end

-- When :q closes one Codex window, its sibling becomes the code window.
-- Let the original :q finish normally instead of mapping or replacing the command.
local function leave_view(keep, restore_buffer, quitting)
	changing_layout = true
	remember_views()
	local old_history, old_prompt = history_win, prompt_win
	history_win, prompt_win = nil, nil
	if valid(keep) then
		if restore_buffer then
			local buf = return_state and return_state.buf
			if not buf or not vim.api.nvim_buf_is_valid(buf) then
				buf = vim.api.nvim_create_buf(true, false)
			end
			vim.api.nvim_win_set_buf(keep, buf)
		end
		if return_state then
			for option, value in pairs(return_state.options) do
				vim.wo[keep][option] = value
			end
			if restore_buffer then
				vim.api.nvim_win_call(keep, function()
					vim.fn.winrestview(return_state.view)
				end)
			end
		end
	end
	for _, win in ipairs({ old_prompt, old_history }) do
		if valid(win) and win ~= keep and win ~= quitting then
			vim.api.nvim_win_close(win, true)
		end
	end
	if not quitting and valid(keep) then
		vim.api.nvim_set_current_win(keep)
	end
	changing_layout = false
end

function M.hide()
	if not history_win and not prompt_win then
		return
	end
	local keep = valid(history_win) and history_win or prompt_win
	leave_view(keep, true)
end

function M.is_buffer(buf)
	buf = buf or vim.api.nvim_get_current_buf()
	return buf == history_buf or buf == prompt_buf
end

local function show()
	if valid(prompt_win) and valid(history_win) then
		vim.api.nvim_set_current_win(prompt_win)
		return
	end
	M.hide()
	changing_layout = true
	for _, kind in ipairs({ "history", "prompt" }) do
		local buf
		if kind == "history" then
			buf = history_buf
		else
			buf = prompt_buf
		end
		if not buf or not vim.api.nvim_buf_is_valid(buf) then
			buf = vim.api.nvim_create_buf(true, true)
			vim.bo[buf].bufhidden = "hide"
			vim.bo[buf].filetype = "markdown"
			vim.api.nvim_buf_set_name(buf, "codex://" .. kind)
			if kind == "history" then
				history_buf = buf
			else
				prompt_buf = buf
			end
		end
	end
	local current = vim.api.nvim_get_current_win()
	if vim.api.nvim_win_get_config(current).relative ~= "" then
		current = vim.fn.win_getid(vim.fn.winnr("#"))
		vim.api.nvim_set_current_win(current)
	end
	if not M.is_buffer(vim.api.nvim_win_get_buf(current)) then
		return_state = {
			buf = vim.api.nvim_win_get_buf(current),
			view = vim.fn.winsaveview(),
			options = { winbar = vim.wo.winbar, wrap = vim.wo.wrap, winfixheight = vim.wo.winfixheight },
		}
	end
	history_win = current
	vim.api.nvim_win_set_buf(history_win, history_buf)
	vim.cmd("belowright " .. M.config.prompt_height .. "split")
	prompt_win = vim.api.nvim_get_current_win()
	vim.api.nvim_win_set_buf(prompt_win, prompt_buf)
	vim.wo[prompt_win].winbar = " Prompt · <leader>as send "
	vim.wo[prompt_win].winfixheight = true
	vim.wo[history_win].wrap, vim.wo[prompt_win].wrap = true, true
	changing_layout = false
	render()
	restore_views()
end

function M.toggle()
	if valid(history_win) or valid(prompt_win) then
		M.hide()
	else
		M.open()
	end
end

function M.bookmark()
	if not M.is_buffer() then
		return nil
	end
	if not state.thread_id or state.status == "Loading" then
		notify("Wait until the session is ready before bookmarking", vim.log.levels.WARN)
		return nil
	end
	local name = state.name
	if not name then
		for _, entry in ipairs(state.items) do
			if entry.item.type == "userMessage" then
				for _, content in ipairs(entry.item.content or {}) do
					if content.text then
						name = content.text:match("[^\n]+")
						break
					end
				end
				if name then
					break
				end
			end
		end
	end
	return { value = "codex://" .. state.thread_id, context = { title = name or "New conversation" } }
end

function M.select_bookmark(id)
	if id == state.thread_id then
		M.open()
	else
		M.resume(id)
	end
end

local function load_history(thread, callback)
	local items = {}
	if thread.historyMode ~= "paginated" then
		client:request("thread/read", { threadId = thread.id, includeTurns = true }, function(result, err)
			if err then
				callback(nil, err)
				return
			end
			for _, turn in ipairs(result.thread.turns or {}) do
				for _, item in ipairs(turn.items) do
					table.insert(items, { turnId = turn.id, item = item })
				end
			end
			callback(items)
		end)
		return
	end
	local function page(cursor)
		client:request(
			"thread/items/list",
			{ threadId = thread.id, sortDirection = "asc", limit = 100, cursor = cursor },
			function(result, err)
				if err then
					callback(nil, err)
					return
				end
				vim.list_extend(items, result.data)
				if result.nextCursor then
					page(result.nextCursor)
				else
					callback(items)
				end
			end
		)
	end
	page()
end

local function load_session(id, cwd, callback)
	state.busy, state.status = true, "Loading"
	title()
	ensure_client(function()
		local params = { approvalPolicy = "on-request", approvalsReviewer = "user", sandbox = "workspace-write" }
		if id then
			params.threadId, params.excludeTurns = id, true
		else
			params.cwd = cwd
		end
		client:request(id and "thread/resume" or "thread/start", params, function(result, err)
			if err then
				fail(err)
				return
			end
			if result.thread.status.type == "active" then
				fail("This session is active. Finish or interrupt it in its current client before resuming here.")
				return
			end
			local function loaded(items, history_err)
				if history_err then
					fail(history_err)
					return
				end
				if state.thread_id and state.thread_id ~= result.thread.id then
					client:request("thread/unsubscribe", { threadId = state.thread_id }, function() end)
					remember_views()
					drafts[state.thread_id] =
						{ text = prompt_text(), history_view = history_view, prompt_view = prompt_view }
					local draft = drafts[result.thread.id] or { text = "" }
					vim.api.nvim_buf_set_lines(prompt_buf, 0, -1, false, vim.split(draft.text, "\n", { plain = true }))
					history_view, prompt_view = draft.history_view, draft.prompt_view
				end
				state.thread_id, state.cwd, state.name = result.thread.id, result.cwd, result.thread.name
				state.model, state.effort = result.model, result.reasoningEffort
				state.items, state.item_index = {}, {}
				for _, entry in ipairs(items) do
					put_item(entry.turnId, entry.item)
				end
				state.loaded, state.busy, state.status, state.error = true, false, "Ready", nil
				state.elapsed = 0
				requests:clear()
				render()
				restore_views()
				if callback then
					callback()
				end
			end
			if id then
				load_history(result.thread, loaded)
			else
				loaded({})
			end
		end)
	end)
end

function M.open(on_ready)
	show()
	if not state.loaded and not state.busy then
		load_session(state.thread_id, vim.fn.getcwd(), type(on_ready) == "function" and on_ready or nil)
	elseif state.loaded and not state.busy and type(on_ready) == "function" then
		on_ready()
	end
end

function M.send()
	if state.busy then
		notify("A turn or session operation is already in progress")
		return
	end
	local text = prompt_text()
	if not text:match("%S") then
		M.open()
		return
	end
	if not state.loaded then
		notify("Open or resume the session before sending", vim.log.levels.WARN)
		M.open()
		return
	end
	show()
	state.busy, state.status, state.error = true, "Starting", nil
	state.started = vim.uv.hrtime()
	timer = vim.uv.new_timer()
	timer:start(0, 1000, vim.schedule_wrap(title))
	client:request("turn/start", {
		threadId = state.thread_id,
		input = { { type = "text", text = text } },
		model = state.model,
		effort = state.effort,
	}, function(result, err)
		if err then
			fail(err)
			return
		end
		-- A very short turn may complete before the start response arrives.
		if state.busy then
			state.turn_id = result.turn.id
		end
		if prompt_text() == text then
			vim.api.nvim_buf_set_lines(prompt_buf, 0, -1, false, { "" })
		end
		title()
	end)
end

function M.new()
	if state.busy then
		notify("Finish or interrupt the current turn first")
		return
	end
	show()
	load_session(nil, vim.fn.getcwd())
end

function M.resume(id)
	if state.busy then
		notify("Finish or interrupt the current turn first")
		return
	end
	show()
	-- Another client may have appended turns since this process loaded the session.
	-- Restart before a handoff so both agent context and displayed history come from disk.
	if client then
		state.busy, state.status = true, "Loading"
		title()
		client:restart(function(err)
			if err then
				fail(err)
			else
				load_session(id, vim.fn.getcwd())
			end
		end)
	else
		load_session(id, vim.fn.getcwd())
	end
end

function M.sessions(all)
	if state.busy then
		notify("Finish or interrupt the current turn first")
		return
	end
	ensure_client(function()
		local entries = {}
		local function page(cursor)
			client:request("thread/list", {
				cwd = not all and vim.fn.getcwd() or nil,
				limit = 100,
				cursor = cursor,
				sortKey = "updated_at",
				sourceKinds = { "cli", "vscode", "exec", "appServer", "unknown" },
			}, function(result, err)
				if err then
					notify(err, vim.log.levels.ERROR)
					return
				end
				vim.list_extend(entries, result.data)
				if result.nextCursor then
					page(result.nextCursor)
					return
				end
				if #entries == 0 then
					notify("No saved sessions here. :CodexSessions! searches all projects.")
					return
				end
				local actions = require("telescope.actions")
				require("telescope.pickers")
					.new({}, {
						prompt_title = all and "Codex sessions · all projects"
							or "Codex sessions · current directory",
						finder = require("telescope.finders").new_table({
							results = entries,
							entry_maker = function(thread)
								local label = (thread.name or thread.preview or thread.id):gsub("\n", " ")
								label = os.date("%Y-%m-%d %H:%M", thread.updatedAt) .. "  " .. label
								if all then
									label = label .. "  [" .. thread.cwd .. "]"
								end
								return { value = thread, display = label, ordinal = label }
							end,
						}),
						sorter = require("telescope.config").values.generic_sorter({}),
						attach_mappings = function(buf)
							actions.select_default:replace(function()
								local entry = require("telescope.actions.state").get_selected_entry()
								actions.close(buf)
								if entry then
									M.resume(entry.value.id)
								end
							end)
							return true
						end,
					})
					:find()
			end)
		end
		page()
	end)
end

function M.models()
	if state.busy then
		notify("Select a model after the current turn finishes")
		return
	end
	if not state.loaded then
		M.open(M.models)
		return
	end
	local thread_id = state.thread_id
	local models = {}
	local function page(cursor)
		client:request("model/list", { limit = 100, cursor = cursor }, function(result, err)
			if err then
				notify(err, vim.log.levels.ERROR)
				return
			end
			vim.list_extend(models, result.data)
			if result.nextCursor then
				page(result.nextCursor)
				return
			end
			vim.ui.select(models, {
				prompt = "Codex model (current: " .. state.model .. ")",
				format_item = function(model)
					return model.displayName .. " · " .. model.model
				end,
			}, function(model)
				if not model then
					return
				end
				vim.ui.select(model.supportedReasoningEfforts, {
					prompt = "Reasoning effort",
					format_item = function(effort)
						return effort.reasoningEffort .. " — " .. effort.description
					end,
				}, function(effort)
					if not effort or state.busy or state.thread_id ~= thread_id then
						return
					end
					state.model, state.effort = model.model, effort.reasoningEffort
					title()
					notify("Next message: " .. state.model .. " · " .. state.effort)
				end)
			end)
		end)
	end
	page()
end

function M.files()
	if not state.loaded then
		M.open(M.files)
		return
	end
	local cwd, thread_id = state.cwd, state.thread_id
	vim.system({ "rg", "--files", "--hidden", "-g", "!.git", "-0" }, { cwd = cwd }, function(result)
		vim.schedule(function()
			if result.code > 1 then
				notify(result.stderr, vim.log.levels.ERROR)
				return
			end
			local paths, seen = { "./" }, { ["./"] = true }
			for path in result.stdout:gmatch("[^%z]+") do
				table.insert(paths, path)
				local directory = vim.fs.dirname(path)
				while directory and directory ~= "." do
					if not seen[directory] then
						table.insert(paths, directory .. "/")
						seen[directory] = true
					end
					directory = vim.fs.dirname(directory)
				end
			end
			table.sort(paths)
			local actions = require("telescope.actions")
			require("telescope.pickers")
				.new({}, {
					prompt_title = "Codex files / directories · Tab select · Enter add",
					finder = require("telescope.finders").new_table({ results = paths }),
					sorter = require("telescope.config").values.generic_sorter({}),
					attach_mappings = function(buf)
						actions.select_default:replace(function()
							local picker = require("telescope.actions.state").get_current_picker(buf)
							local selections = picker:get_multi_selection()
							if #selections == 0 then
								selections = { require("telescope.actions.state").get_selected_entry() }
							end
							actions.close(buf)
							if state.thread_id ~= thread_id then
								notify("Session changed; select files again")
								return
							end
							local lines = { "", "Files/directories to use as context (read from disk):" }
							for _, entry in ipairs(selections) do
								-- JSON quoting keeps paths containing whitespace or newlines unambiguous.
								table.insert(lines, "- " .. vim.json.encode(vim.fs.joinpath(cwd, entry.value)))
							end
							show()
							vim.api.nvim_buf_set_lines(prompt_buf, -1, -1, false, lines)
						end)
						return true
					end,
				})
				:find()
		end)
	end)
end

function M.interrupt()
	if not state.turn_id then
		notify("No running turn to interrupt")
		return
	end
	client:request("turn/interrupt", { threadId = state.thread_id, turnId = state.turn_id }, function(_, err)
		if err then
			notify(err, vim.log.levels.ERROR)
		end
	end)
end

function M.approval()
	if requests and #requests.queue > 0 then
		requests:show()
	else
		notify("No pending requests")
	end
end

function M.setup(opts)
	M.config = vim.tbl_deep_extend("force", M.config, opts or {})
	for _, entry in ipairs({
		{ "Codex", "<leader>ac", M.toggle, "switch code / chat" },
		{ "CodexNew", "<leader>an", M.new, "new session" },
		{ "CodexSend", "<leader>as", M.send, "send prompt" },
		{ "CodexModel", "<leader>am", M.models, "select model / effort" },
		{ "CodexFiles", "<leader>af", M.files, "add files / directories" },
		{ "CodexApproval", "<leader>ap", M.approval, "pending approval / question" },
		{ "CodexInterrupt", "<leader>ax", M.interrupt, "interrupt turn" },
	}) do
		vim.api.nvim_create_user_command(entry[1], entry[3], { desc = "Codex: " .. entry[4] })
		vim.keymap.set("n", entry[2], entry[3], { desc = "Codex: " .. entry[4] })
	end
	vim.api.nvim_create_user_command("CodexSessions", function(args)
		M.sessions(args.bang)
	end, { bang = true })
	vim.keymap.set("n", "<leader>ar", function()
		M.sessions(false)
	end, { desc = "Codex: resume session" })
	vim.api.nvim_create_user_command("CodexResume", function(args)
		M.resume(args.args)
	end, { nargs = 1 })
	vim.api.nvim_create_user_command("CodexRefresh", function()
		if state.thread_id then
			M.resume(state.thread_id)
		else
			M.open()
		end
	end, {})
	vim.api.nvim_create_user_command("CodexRun", M.send, { desc = "Codex: send prompt" })
	local group = vim.api.nvim_create_augroup("CustomCodex", { clear = true })
	vim.api.nvim_create_autocmd("VimLeavePre", {
		group = group,
		callback = function()
			state.exiting = true
			stop_timer()
			if client then
				client:stop()
			end
		end,
	})
	vim.api.nvim_create_autocmd("QuitPre", {
		group = group,
		callback = function()
			if changing_layout then
				return
			end
			local win = vim.api.nvim_get_current_win()
			if win ~= history_win and win ~= prompt_win then
				return
			end
			local sibling = win == prompt_win and history_win or prompt_win
			if valid(sibling) then
				leave_view(sibling, true, win)
			end
		end,
	})
	vim.api.nvim_create_autocmd("BufEnter", {
		group = group,
		callback = function(args)
			if changing_layout then
				return
			end
			local win = vim.api.nvim_get_current_win()
			if (win == history_win or win == prompt_win) and not M.is_buffer(args.buf) then
				-- Telescope, :buffer, and ordinary file navigation replace the whole chat view.
				leave_view(win, false)
			elseif not history_win and not prompt_win and M.is_buffer(args.buf) then
				vim.schedule(function()
					if vim.api.nvim_get_current_buf() == args.buf and not history_win then
						M.open()
					end
				end)
			end
		end,
	})
	vim.api.nvim_create_autocmd("BufLeave", {
		group = group,
		callback = function(args)
			if not changing_layout and M.is_buffer(args.buf) then
				remember_views()
			end
		end,
	})
	vim.api.nvim_create_autocmd("WinClosed", {
		group = group,
		callback = function(args)
			if changing_layout then
				return
			end
			local closed = tonumber(args.match)
			if closed == history_win or closed == prompt_win then
				vim.schedule(function()
					if closed == history_win or closed == prompt_win then
						M.hide()
					end
				end)
			end
		end,
	})
end

return M
