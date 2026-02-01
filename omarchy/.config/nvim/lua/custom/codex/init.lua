local M = {}

local function default_helper()
	local home = vim.env.HOME
	if home and home ~= "" then
		return home .. "/.local/bin/codex-thread.sh"
	end
	return "codex-thread.sh"
end

M.config = {
	helper = default_helper(),
	flags = { "--sandbox", "workspace-write" },
	json = true,
	output_last_message = true,
	delimiter = "--- Codex Run ---",
	session_header = "--- Codex Session ---",
	next_prompt_marker = "--- Next Prompt ---",
	time_prefix = "Time: ",
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

local function parse_session_id(stdout)
	local session_id = nil
	local decoded_any = false

	for _, line in ipairs(vim.split(stdout or "", "\n", { plain = true, trimempty = true })) do
		local ok, event = pcall(vim.json.decode, line)
		if ok and type(event) == "table" then
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

local function run_codex(cmd, input, callback)
	vim.system(cmd, { text = true, stdin = input }, function(result)
		vim.schedule(function()
			callback(result)
		end)
	end)
end

function M.run()
	if not vim.system then
		vim.notify("vim.system is not available in this Neovim version", vim.log.levels.ERROR)
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

	local helper = M.config.helper
	if vim.fn.filereadable(helper) ~= 1 then
		vim.notify("Codex helper not found: " .. helper, vim.log.levels.ERROR)
		return
	end

	local input_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	local session_id = extract_session_id(input_lines, M.config.session_header)
	local prompt = last_prompt(input_lines, M.config.next_prompt_marker)
	local fallback_prompt = full_prompt(input_lines, M.config.session_header)
	if not prompt then
		session_id = nil
	end

	local function build_cmd(use_resume, output_path)
		local cmd = { helper, "exec" }
		if M.config.json then
			table.insert(cmd, "--json")
		end
		if M.config.output_last_message and output_path then
			table.insert(cmd, "--output-last-message")
			table.insert(cmd, output_path)
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

	local function read_output_message(path)
		if not path or vim.fn.filereadable(path) ~= 1 then
			return ""
		end
		local ok, lines = pcall(vim.fn.readfile, path)
		if ok and lines then
			return table.concat(lines, "\n")
		end
		return ""
	end

	local function handle_result(result, extra_stderr, output_path)
		local stdout = result.stdout or ""
		local stderr = result.stderr or ""
		if extra_stderr and extra_stderr:match("%S") then
			if stderr == "" then
				stderr = extra_stderr
			else
				stderr = extra_stderr .. "\n" .. stderr
			end
		end

		local message = ""
		if M.config.output_last_message then
			message = read_output_message(output_path)
			if output_path then
				vim.fn.delete(output_path)
			end
		else
			message = stdout
		end

		local new_session_id = nil
		if M.config.json then
			new_session_id = parse_session_id(stdout)
		end

		append_block(buf, message or "", stderr or "")
		if new_session_id and new_session_id ~= "" then
			ensure_session_header(buf, M.config.session_header, new_session_id)
		end
		vim.notify("Codex finished", vim.log.levels.INFO)
	end

	if session_id and session_id ~= "" then
		local resume_output = vim.fn.tempname()
		run_codex(build_cmd(true, resume_output), prompt or "\n", function(resume_result)
			if resume_result.code == 0 then
				handle_result(resume_result, nil, resume_output)
			else
				if vim.fn.filereadable(resume_output) == 1 then
					vim.fn.delete(resume_output)
				end
				local resume_err = resume_result.stderr or ""
				local resume_note = "Resume failed (exit code " .. tostring(resume_result.code) .. ")"
				if resume_err ~= "" then
					resume_note = resume_note .. "\n" .. resume_err
				end
				local full_output = vim.fn.tempname()
				run_codex(build_cmd(false, full_output), fallback_prompt, function(full_result)
					handle_result(full_result, resume_note, full_output)
				end)
			end
		end)
	else
		local full_output = vim.fn.tempname()
		run_codex(build_cmd(false, full_output), fallback_prompt, function(result)
			handle_result(result, nil, full_output)
		end)
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
