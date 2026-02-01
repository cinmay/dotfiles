local M = {}

M.config = {
	command = "codex",
	flags = { "--sandbox", "workspace-write" },
	json = true,
	delimiter = "--- Codex Run ---",
	session_header = "--- Codex Session ---",
	next_prompt_marker = "--- Next Prompt ---",
	time_prefix = "Time: ",
	debug = true,
	debug_max_lines = 200,
}

local function is_thread_buffer(buf, cwd)
	local buf_path = vim.api.nvim_buf_get_name(buf)
	if buf_path == "" then
		return false
	end

	local normalized_cwd = cwd:gsub("/+$", "")
	local threads_dir = normalized_cwd .. "/.ai/threads/"
	return buf_path:find(threads_dir, 1, true) ~= nil
end

local function strip_header_block(lines, header)
	for i, line in ipairs(lines) do
		if line == header then
			table.remove(lines, i)
			if lines[i] and lines[i]:match("^ID:") then
				table.remove(lines, i)
			end
			if lines[i] == "" then
				table.remove(lines, i)
			end
			break
		end
	end
	return lines
end

local function extract_session_id(lines, header)
	for i, line in ipairs(lines) do
		if line == header then
			local id_line = lines[i + 1] or ""
			local id = id_line:match("^ID:%s*(.+)$")
			if id and id:match("%S") then
				return id
			end
			return nil
		end
	end
	return nil
end

local function ensure_session_header(buf, header, session_id)
	if not session_id or session_id == "" then
		return
	end

	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	lines = strip_header_block(lines, header)

	local new_lines = { header, "ID: " .. session_id, "" }
	for _, line in ipairs(lines) do
		table.insert(new_lines, line)
	end

	vim.api.nvim_buf_set_lines(buf, 0, -1, false, new_lines)
end

local function last_prompt(lines, marker)
	local last_index = nil
	for i, line in ipairs(lines) do
		if line == marker then
			last_index = i
		end
	end

	if not last_index then
		return nil
	end

	local start = last_index + 1
	if lines[start] and lines[start]:match("^Time:%s") then
		start = start + 1
	end
	while lines[start] == "" do
		start = start + 1
	end

	local prompt_lines = {}
	for i = start, #lines do
		table.insert(prompt_lines, lines[i])
	end

	return table.concat(prompt_lines, "\n") .. "\n"
end

local function full_prompt(lines, header)
	local stripped = strip_header_block(vim.deepcopy(lines), header)
	return table.concat(stripped, "\n") .. "\n"
end

local function parse_stream_event(line)
	local ok, event = pcall(vim.json.decode, line)
	if not ok or type(event) ~= "table" then
		return nil
	end
	return event
end

local function parse_session_id(stdout)
	local session_id = nil
	local decoded_any = false

	for _, line in ipairs(vim.split(stdout or "", "\n", { plain = true, trimempty = true })) do
		local event = parse_stream_event(line)
		if event then
			decoded_any = true
			if event.type == "session_meta" and event.payload and event.payload.id then
				session_id = event.payload.id
			end
			if event.type == "thread.started" and event.thread_id then
				session_id = event.thread_id
			end
		end
	end

	if not decoded_any then
		return nil
	end

	return session_id
end

local function append_block(buf, stdout, stderr)
	local timestamp = os.date("%Y-%m-%d %H:%M:%S")
	local lines = {}

	table.insert(lines, "")
	table.insert(lines, M.config.time_prefix .. timestamp)
	table.insert(lines, M.config.delimiter)
	table.insert(lines, "")
	table.insert(lines, "```Markdown")
	if stdout and stdout ~= "" then
		local out_lines = vim.split(stdout, "\n", { plain = true, trimempty = true })
		for _, line in ipairs(out_lines) do
			table.insert(lines, line)
		end
	end
	table.insert(lines, "```")

	if stderr and stderr:match("%S") then
		table.insert(lines, "")
		table.insert(lines, "```text")
		local err_lines = vim.split(stderr, "\n", { plain = true, trimempty = true })
		for _, line in ipairs(err_lines) do
			table.insert(lines, line)
		end
		table.insert(lines, "```")
	end

	table.insert(lines, "")
	table.insert(lines, "Time: " .. timestamp)
	table.insert(lines, M.config.next_prompt_marker)
	table.insert(lines, "")

	vim.api.nvim_buf_set_lines(buf, -1, -1, false, lines)
end

local function open_live_window()
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
	vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
	vim.api.nvim_buf_set_option(buf, "swapfile", false)
	vim.api.nvim_buf_set_option(buf, "filetype", "markdown")

	local width = math.floor(vim.o.columns * 0.7)
	local height = math.floor(vim.o.lines * 0.6)
	local row = math.floor((vim.o.lines - height) / 2)
	local col = math.floor((vim.o.columns - width) / 2)

	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		width = width,
		height = height,
		row = row,
		col = col,
		style = "minimal",
		border = "rounded",
		title = "Codex — Running (00:00)",
		title_pos = "center",
	})

	return buf, win
end

local function update_window_title(win, elapsed, model)
	if not vim.api.nvim_win_is_valid(win) then
		return
	end
	local title = string.format("Codex — Running (%s)", elapsed)
	if model and model ~= "" then
		title = title .. " — " .. model
	end
	local config = vim.api.nvim_win_get_config(win)
	config.title = title
	vim.api.nvim_win_set_config(win, config)
end

local function append_live(buf, lines)
	if not vim.api.nvim_buf_is_valid(buf) then
		return
	end
	if type(lines) == "string" then
		lines = { lines }
	end
	vim.api.nvim_buf_set_lines(buf, -1, -1, false, lines)
end

local function run_codex_job(cmd, input, handlers)
	local stdout_accum = {}
	local stderr_accum = {}
	local stdout_buf = ""
	local stderr_buf = ""

	local function handle_line(handler, line)
		if handler then
			handler(line)
		end
	end

	local function flush_buffer(buf, accum, handler)
		if buf ~= "" then
			table.insert(accum, buf)
			handle_line(handler, buf)
		end
		return ""
	end

	local job_id = vim.fn.jobstart(cmd, {
		stdin = "pipe",
		on_stdout = function(_, data)
			if not data then
				return
			end
			for i, chunk in ipairs(data) do
				if i == #data then
					if chunk == "" then
						stdout_buf = flush_buffer(stdout_buf, stdout_accum, handlers.on_stdout)
					else
						stdout_buf = stdout_buf .. chunk
					end
				else
					local line = stdout_buf .. chunk
					stdout_buf = ""
					table.insert(stdout_accum, line)
					handle_line(handlers.on_stdout, line)
				end
			end
		end,
		on_stderr = function(_, data)
			if not data then
				return
			end
			for i, chunk in ipairs(data) do
				if i == #data then
					if chunk == "" then
						stderr_buf = flush_buffer(stderr_buf, stderr_accum, handlers.on_stderr)
					else
						stderr_buf = stderr_buf .. chunk
					end
				else
					local line = stderr_buf .. chunk
					stderr_buf = ""
					table.insert(stderr_accum, line)
					handle_line(handlers.on_stderr, line)
				end
			end
		end,
		on_exit = function(_, code)
			stdout_buf = flush_buffer(stdout_buf, stdout_accum, handlers.on_stdout)
			stderr_buf = flush_buffer(stderr_buf, stderr_accum, handlers.on_stderr)
			if handlers.on_exit then
				handlers.on_exit({
					code = code,
					stdout = table.concat(stdout_accum, "\n"),
					stderr = table.concat(stderr_accum, "\n"),
				})
			end
		end,
	})

	if job_id <= 0 then
		return nil
	end

	vim.fn.chansend(job_id, input)
	vim.fn.chanclose(job_id, "stdin")
	return job_id
end

function M.run()
	if not vim.fn.jobstart then
		vim.notify("vim.fn.jobstart is not available in this Neovim version", vim.log.levels.ERROR)
		return
	end

	local buf = vim.api.nvim_get_current_buf()
	local cwd = vim.fn.getcwd()

	if not is_thread_buffer(buf, cwd) then
		vim.notify(
			"Codex run is only allowed in .ai/threads files under the current working directory",
			vim.log.levels.WARN
		)
		return
	end

	local command = M.config.command
	if not command or command == "" then
		vim.notify("Codex command is not configured", vim.log.levels.ERROR)
		return
	end

	local input_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	local session_id = extract_session_id(input_lines, M.config.session_header)
	local prompt = last_prompt(input_lines, M.config.next_prompt_marker)
	local fallback_prompt = full_prompt(input_lines, M.config.session_header)
	if not prompt then
		session_id = nil
	end

	local function build_cmd(use_resume)
		local cmd = { command, "exec" }
		if M.config.json then
			table.insert(cmd, "--json")
		end
		for _, flag in ipairs(M.config.flags or {}) do
			table.insert(cmd, flag)
		end
		if use_resume then
			table.insert(cmd, "resume")
			table.insert(cmd, session_id)
		end
		table.insert(cmd, "-")
		return cmd
	end

	vim.notify("Running Codex...", vim.log.levels.INFO)

	local prev_win = vim.api.nvim_get_current_win()
	local live_buf, live_win = open_live_window()
	local start_time = vim.loop.hrtime()
	local model_label = nil
	local assistant_lines = {}
	local raw_lines = {}
	local debug_lines = 0

	local timer = vim.loop.new_timer()
	timer:start(0, 1000, function()
		local elapsed = math.floor((vim.loop.hrtime() - start_time) / 1e9)
		local minutes = math.floor(elapsed / 60)
		local seconds = elapsed % 60
	vim.schedule(function()
		update_window_title(live_win, string.format("%02d:%02d", minutes, seconds), model_label)
	end)
	end)

	local function stop_timer()
		if timer then
			timer:stop()
			timer:close()
		end
	end

	local function close_live_window()
		if vim.api.nvim_win_is_valid(live_win) then
			vim.api.nvim_win_close(live_win, true)
		end
		if vim.api.nvim_win_is_valid(prev_win) then
			vim.api.nvim_set_current_win(prev_win)
		end
	end

	local function handle_result(result, extra_stderr)
		local stdout = result.stdout or ""
		local stderr = result.stderr or ""
		if extra_stderr and extra_stderr:match("%S") then
			if stderr == "" then
				stderr = extra_stderr
			else
				stderr = extra_stderr .. "\n" .. stderr
			end
		end

		local new_session_id = nil
		if M.config.json then
			new_session_id = parse_session_id(stdout)
		end

		local message = table.concat(assistant_lines, "\n")
		if message == "" then
			message = table.concat(raw_lines, "\n")
		end
		append_block(buf, message or "", stderr or "")
		if new_session_id and new_session_id ~= "" then
			ensure_session_header(buf, M.config.session_header, new_session_id)
		end
		stop_timer()
		vim.notify("Codex finished", vim.log.levels.INFO)
	end

	local function stream_handler(line)
		if not line or line == "" then
			return
		end
		table.insert(raw_lines, line)
		local event = parse_stream_event(line)
		if event and event.type == "session_meta" and event.payload then
			local provider = event.payload.model_provider
			local model = event.payload.model or event.payload.model_name or event.payload.model_id
			if event.payload.model and type(event.payload.model) == "string" then
				model = event.payload.model
			end
			if provider and model then
				model_label = provider .. ":" .. model
			elseif provider then
				model_label = provider
			end
		elseif event and event.type == "turn_context" and event.payload and event.payload.model then
			local model = event.payload.model
			if model and model:match("%S") then
				local provider = event.payload.model_provider
				if provider and provider:match("%S") then
					model_label = provider .. ":" .. model
				else
					model_label = model
				end
			end
		end
		if event
			and event.type == "response_item"
			and event.payload
			and event.payload.type == "message"
			and event.payload.role == "assistant"
		then
			local content = event.payload.content or {}
			for _, item in ipairs(content) do
				if item.type == "output_text" or item.type == "input_text" then
					local text_lines = vim.split(item.text or "", "\n", { plain = true })
					for _, text_line in ipairs(text_lines) do
						table.insert(assistant_lines, text_line)
					end
					append_live(live_buf, text_lines)
				end
			end
		elseif event
			and event.type == "item.completed"
			and event.item
			and event.item.type == "agent_message"
			and event.item.text
		then
			local text_lines = vim.split(event.item.text or "", "\n", { plain = true })
			for _, text_line in ipairs(text_lines) do
				table.insert(assistant_lines, text_line)
			end
			append_live(live_buf, text_lines)
		elseif not event and M.config.debug and debug_lines < M.config.debug_max_lines then
			append_live(live_buf, "[debug] " .. line)
			debug_lines = debug_lines + 1
		elseif event and M.config.debug and debug_lines < M.config.debug_max_lines then
			append_live(live_buf, "[debug] " .. line)
			debug_lines = debug_lines + 1
		end
	end

	local function stderr_handler(_)
	end

	if session_id and session_id ~= "" then
		local job_id = run_codex_job(build_cmd(true), prompt or "\n", {
			on_stdout = stream_handler,
			on_stderr = stderr_handler,
			on_exit = function(resume_result)
				if resume_result.code == 0 then
					handle_result(resume_result, nil)
					close_live_window()
				else
					local resume_err = resume_result.stderr or ""
					local resume_note = "Resume failed (exit code " .. tostring(resume_result.code) .. ")"
					if resume_err ~= "" then
						resume_note = resume_note .. "\n" .. resume_err
					end
					vim.notify("Resume failed, running full prompt", vim.log.levels.WARN)
					run_codex_job(build_cmd(false), fallback_prompt, {
						on_stdout = stream_handler,
						on_stderr = stderr_handler,
						on_exit = function(full_result)
							handle_result(full_result, resume_note)
							if full_result.code == 0 then
								close_live_window()
							end
						end,
					})
				end
			end,
		})
		if not job_id then
			stop_timer()
			close_live_window()
			vim.notify("Failed to start Codex job", vim.log.levels.ERROR)
		end
	else
		local job_id = run_codex_job(build_cmd(false), fallback_prompt, {
			on_stdout = stream_handler,
			on_stderr = stderr_handler,
			on_exit = function(result)
				handle_result(result, nil)
				if result.code == 0 then
					close_live_window()
				end
			end,
		})
		if not job_id then
			stop_timer()
			close_live_window()
			vim.notify("Failed to start Codex job", vim.log.levels.ERROR)
		end
	end
end

function M.setup(opts)
	M.config = vim.tbl_deep_extend("force", M.config, opts or {})
	vim.api.nvim_create_user_command("CodexRun", function()
		M.run()
	end, { desc = "Run Codex on current thread buffer" })
	vim.keymap.set("n", "<leader>ac", function()
		M.run()
	end, { desc = "Codex: run thread" })
end

return M
