local M = {}

M.config = {
	command = "claude",
	done_sound = vim.fn.stdpath("config") .. "/lua/custom/codex/done.mp3",
	desktop_notify = "notify-send",
	prompt_height = 18,
}

local mode_names = {
	default = "Manual",
	acceptEdits = "Accept edits",
	plan = "Plan",
	auto = "Auto",
	dontAsk = "Don't ask",
	bypassPermissions = "Bypass permissions",
}

local state = { entries = {}, tools = {}, requests = {}, status = "Ready", busy = false }
local process, timer
local history_buf, prompt_buf, request_buf, history_win, prompt_win
local render_pending = false
local return_state, history_view, prompt_view
local changing_layout = false

local function notify(message, level)
	vim.notify("Claude: " .. message, level or vim.log.levels.INFO)
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

local function model_name()
	for _, model in ipairs(state.models or {}) do
		if model.value ~= "default" and model.resolvedModel == state.model then
			return model.displayName
		end
	end
	return state.model or "default model"
end

local function title()
	if not valid(history_win) then
		return
	end
	local elapsed = state.elapsed or 0
	if state.started then
		elapsed = math.floor((vim.uv.hrtime() - state.started) / 1e9)
	end
	local status = #state.requests > 0 and "Response required" or state.status
	vim.wo[history_win].winbar = string
		.format(
			" Claude · %s · %s · %s · %02d:%02d ",
			model_name(),
			mode_names[state.mode] or state.mode or "loading mode",
			status,
			math.floor(elapsed / 60),
			elapsed % 60
		)
		:gsub("%%", "%%%%")
end

local function add(entry)
	table.insert(state.entries, entry)
	return entry
end

local function describe_tool(block)
	local input = block.input or {}
	local detail = input.command
		or input.file_path
		or input.notebook_path
		or input.pattern
		or input.url
		or input.query
		or input.description
		or input.skill
		or (input.questions and input.questions[1] and input.questions[1].question)
	if type(detail) ~= "string" then
		return block.name
	end
	detail = detail:gsub("\n.*", " …")
	if state.cwd and vim.startswith(detail, state.cwd .. "/") then
		detail = detail:sub(#state.cwd + 2)
	end
	return block.name .. " " .. detail
end

local function render()
	if not history_buf or not vim.api.nvim_buf_is_valid(history_buf) then
		return
	end
	local lines = { "# Claude", "", "Directory: " .. (state.cwd or vim.fn.getcwd()) }
	if state.session_id then
		table.insert(lines, "Session: " .. state.session_id)
	end
	local function add_text(text)
		vim.list_extend(lines, vim.split(text, "\n", { plain = true }))
	end
	for _, entry in ipairs(state.entries) do
		if entry.kind == "user" then
			add_text("\n## You\n\n" .. entry.text)
		elseif entry.kind == "assistant" then
			add_text("\n## Claude\n\n" .. entry.text)
		elseif entry.kind == "plan" then
			add_text("\n## Plan\n\n" .. entry.text)
		elseif entry.kind == "tool" then
			add_text("\n• " .. entry.text .. " · " .. entry.status)
		elseif entry.kind == "notice" then
			add_text("\n> " .. entry.text:gsub("\n", "\n> "))
		end
	end
	if state.error then
		add_text("\n## Error\n\n" .. state.error)
	end
	if #state.entries == 0 then
		add_text("\nWrite a prompt below. <leader>as sends.")
	end
	local follow = valid(history_win)
		and vim.api.nvim_win_get_buf(history_win) == history_buf
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

-- Swapping the prompt window's buffer is a layout change, not navigation away from the chat.
local function set_prompt_window(buf, winbar)
	changing_layout = true
	vim.api.nvim_win_set_buf(prompt_win, buf)
	vim.wo[prompt_win].winbar = winbar
	vim.wo[prompt_win].wrap = true
	changing_layout = false
end

local function show_request()
	local request = state.requests[1]
	title()
	if not valid(prompt_win) then
		if request then
			notify("needs your response. Open the chat to answer.", vim.log.levels.WARN)
		end
		return
	end
	if not request then
		if vim.api.nvim_win_get_buf(prompt_win) ~= prompt_buf then
			set_prompt_window(prompt_buf, " Prompt · <leader>as send ")
		end
		return
	end
	local view = require("custom.claude.requests").view(request.request)
	local step = {}
	request.step = step
	local function current()
		return not request.resolved and request.step == step
	end
	local function respond(response)
		if not current() then
			return
		end
		request.resolved = true
		table.remove(state.requests, 1)
		process:respond(request.request_id, response)
		show_request()
	end
	local lines = vim.list_extend({}, view.lines)
	table.insert(lines, "")
	for _, action in ipairs(view.actions) do
		table.insert(lines, "[" .. action.key .. "] " .. action.label)
	end
	table.insert(lines, "")
	table.insert(lines, ":q leaves this waiting; it returns when you open the chat.")
	local buf = vim.api.nvim_create_buf(false, true)
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].filetype = "markdown"
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].modifiable = false
	for _, action in ipairs(view.actions) do
		-- Only the step on screen may answer; keys from an earlier step do nothing.
		vim.keymap.set("n", action.key, function()
			if current() then
				action.run(respond, show_request)
			end
		end, { buffer = buf, nowait = true, desc = "Claude: " .. action.label })
	end
	request_buf = buf
	set_prompt_window(buf, " " .. view.title .. " · press a number to answer ")
	vim.api.nvim_set_current_win(prompt_win)
	vim.api.nvim_win_set_cursor(prompt_win, { 1, 0 })
	vim.cmd.stopinsert()
end

local function clear_requests()
	for _, request in ipairs(state.requests) do
		request.resolved = true
	end
	state.requests = {}
	show_request()
end

local function finish(status, err)
	if state.started then
		state.elapsed = math.floor((vim.uv.hrtime() - state.started) / 1e9)
	end
	state.started, state.interrupting, state.live = nil, nil, nil
	state.busy, state.status, state.error = false, status, err
	stop_timer()
	clear_requests()
	schedule_render()
end

local function fail(err)
	state.ready = false
	finish("Error", err)
	notify(err, vim.log.levels.ERROR)
end

local function on_result(message)
	if message.subtype == "success" and not message.is_error then
		finish("Done")
		local sound = M.config.done_sound
		if sound and vim.fn.filereadable(sound) == 1 and vim.fn.executable("mpv") == 1 then
			vim.fn.jobstart({ "mpv", "--no-video", "--really-quiet", sound }, { detach = true })
		end
	elseif state.interrupting then
		finish("Interrupted")
	else
		local err = message.result
		if message.errors and #message.errors > 0 then
			err = table.concat(message.errors, "\n")
		end
		finish("Error", err or message.subtype)
		notify(err or message.subtype, vim.log.levels.ERROR)
	end
end

local function on_message(message)
	if message.parent_tool_use_id then
		return -- Subagent traffic; the Agent tool line summarises it.
	end
	if message.type == "system" then
		if message.subtype == "init" then
			state.session_id, state.model = message.session_id, message.model
			state.mode, state.cwd = message.permissionMode, message.cwd
		elseif message.subtype == "status" then
			state.mode = message.permissionMode or state.mode
		elseif type(message.content) == "string" then
			add({ kind = "notice", text = message.content })
		end
	elseif message.type == "stream_event" then
		local event = message.event
		if event.type == "content_block_start" and event.content_block.type == "text" then
			state.live = add({ kind = "assistant", text = "" })
		elseif event.type == "content_block_delta" and event.delta.type == "text_delta" and state.live then
			state.live.text = state.live.text .. event.delta.text
		end
	elseif message.type == "assistant" then
		for _, block in ipairs(message.message.content or {}) do
			if block.type == "text" then
				-- The finished block is authoritative; it replaces what was streamed.
				if state.live then
					state.live.text, state.live = block.text, nil
				else
					add({ kind = "assistant", text = block.text })
				end
			elseif block.type == "tool_use" and block.name == "ExitPlanMode" then
				add({ kind = "plan", text = block.input.plan or "" })
			elseif block.type == "tool_use" then
				state.tools[block.id] = add({ kind = "tool", text = describe_tool(block), status = "running" })
			end
		end
	elseif message.type == "user" and type(message.message.content) == "table" then
		for _, block in ipairs(message.message.content) do
			local tool = block.type == "tool_result" and state.tools[block.tool_use_id]
			if tool then
				tool.status = block.is_error and "error" or "done"
			end
		end
	elseif message.type == "result" then
		on_result(message)
		return
	end
	schedule_render()
end

local function on_request(message)
	if message.request.subtype ~= "can_use_tool" then
		process:reject(message.request_id, "Neovim does not support " .. message.request.subtype)
		notify("request not supported: " .. message.request.subtype, vim.log.levels.ERROR)
		return
	end
	table.insert(state.requests, message)
	if #state.requests > 1 then
		title()
		return
	end
	if not valid(prompt_win) and M.config.desktop_notify ~= "" and vim.fn.executable(M.config.desktop_notify) == 1 then
		vim.system({ M.config.desktop_notify, "--app-name=Neovim", "Claude needs your response", "Open the chat to answer." })
	end
	show_request()
end

-- Reconnecting after a crash resumes the same session and keeps the history already shown.
local function start_session(resume_id)
	if process then
		process:stop()
	end
	clear_requests()
	if not resume_id then
		state.entries, state.tools, state.session_id, state.model = {}, {}, nil, nil
		state.cwd = vim.fn.getcwd()
	end
	state.error, state.live, state.ready, state.elapsed = nil, nil, false, 0
	state.busy, state.status = true, "Starting"
	local args = {
		"-p",
		"--input-format",
		"stream-json",
		"--output-format",
		"stream-json",
		"--verbose",
		"--include-partial-messages",
		"--permission-prompt-tool",
		"stdio",
	}
	if resume_id then
		vim.list_extend(args, { "--resume", resume_id })
	end
	local current
	local function mine(handler)
		return function(...)
			if process == current then
				handler(...)
			end
		end
	end
	current = require("custom.claude.process").new(M.config.command, { cwd = state.cwd, args = args }, {
		message = mine(on_message),
		request = mine(on_request),
		exit = mine(fail),
	})
	process = current
	render()
	local err = process:start()
	if err then
		fail(err)
		return
	end
	process:control("initialize", {}, function(response, init_err)
		if process ~= current then
			return
		end
		if init_err then
			fail(init_err)
			return
		end
		state.models, state.mode = response.models, response.current_permission_mode
		state.ready, state.busy, state.status = true, false, "Ready"
		render()
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
	if valid(prompt_win) and prompt_view and vim.api.nvim_win_get_buf(prompt_win) == prompt_buf then
		vim.api.nvim_win_call(prompt_win, function()
			vim.fn.winrestview(prompt_view)
		end)
	end
end

-- When :q closes one Claude window, its sibling becomes the code window.
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
	return buf == history_buf or buf == prompt_buf or buf == request_buf
end

local chat_keymaps = {
	{ "<leader>as", "send", "send prompt" },
	{ "<leader>ax", "interrupt", "interrupt turn" },
}

local function show()
	if valid(prompt_win) and valid(history_win) then
		vim.api.nvim_set_current_win(prompt_win)
		return
	end
	M.hide()
	changing_layout = true
	for _, kind in ipairs({ "history", "prompt" }) do
		local buf = kind == "history" and history_buf or prompt_buf
		if not buf or not vim.api.nvim_buf_is_valid(buf) then
			-- Keep history as a scratch buffer, but use a normal buffer for the
			-- prompt so Copilot can attach to it without making it file-backed.
			local scratch = kind == "history"
			buf = vim.api.nvim_create_buf(true, scratch)
			vim.bo[buf].bufhidden = "hide"
			if not scratch then
				vim.bo[buf].swapfile = false
			end
			vim.bo[buf].filetype = "markdown"
			vim.api.nvim_buf_set_name(buf, "claude://" .. kind)
			-- Chat keys exist only in the chat, so they cannot fire from code by accident.
			for _, entry in ipairs(chat_keymaps) do
				vim.keymap.set("n", entry[1], function()
					M[entry[2]]()
				end, { buffer = buf, desc = "Claude: " .. entry[3] })
			end
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
	show_request()
end

function M.open()
	show()
	if not process then
		start_session()
	elseif not state.ready and not state.busy then
		start_session(state.session_id)
	end
end

function M.new()
	if state.started then
		notify("Finish or interrupt the current turn first")
		return
	end
	show()
	start_session()
end

function M.send()
	if state.busy then
		notify("A turn or session start is already in progress")
		return
	end
	local text = prompt_text()
	if not text:match("%S") then
		M.open()
		return
	end
	if not state.ready then
		notify("Reconnecting; send again when the chat is ready", vim.log.levels.WARN)
		M.open()
		return
	end
	show()
	local sent = process:send({
		type = "user",
		message = { role = "user", content = text },
		parent_tool_use_id = vim.NIL,
		session_id = state.session_id or "",
	})
	if not sent then
		fail("Could not send the prompt to Claude")
		return
	end
	add({ kind = "user", text = text })
	vim.api.nvim_buf_set_lines(prompt_buf, 0, -1, false, { "" })
	state.busy, state.status, state.error = true, "Running", nil
	state.started = vim.uv.hrtime()
	timer = vim.uv.new_timer()
	timer:start(0, 1000, vim.schedule_wrap(title))
	render()
end

function M.interrupt()
	if not state.started then
		notify("No running turn to interrupt")
		return
	end
	state.interrupting = true
	process:control("interrupt", {}, function(_, err)
		if err then
			notify(err, vim.log.levels.ERROR)
		end
	end)
end

function M.setup(opts)
	M.config = vim.tbl_deep_extend("force", M.config, opts or {})
	vim.api.nvim_create_user_command("ClaudeNew", M.new, { desc = "Claude: new chat" })
	vim.api.nvim_create_user_command("ClaudeSend", M.send, { desc = "Claude: send prompt" })
	vim.api.nvim_create_user_command("ClaudeInterrupt", M.interrupt, { desc = "Claude: interrupt turn" })
	vim.keymap.set("n", "<leader>ana", M.new, { desc = "Claude: new chat" })
	local group = vim.api.nvim_create_augroup("CustomClaude", { clear = true })
	vim.api.nvim_create_autocmd("VimLeavePre", {
		group = group,
		callback = function()
			stop_timer()
			if process then
				process:stop()
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
