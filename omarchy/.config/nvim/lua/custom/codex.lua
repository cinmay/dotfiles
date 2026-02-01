local M = {}

local function get_realpath(path)
	local uv = vim.uv or vim.loop
	if uv and uv.fs_realpath then
		return uv.fs_realpath(path)
	end
	return path
end

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
	delimiter = "--- Codex Run ---",
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

local function append_block(buf, stdout, stderr)
	local timestamp = os.date("%Y-%m-%d %H:%M:%S")
	local lines = {}

	table.insert(lines, "")
	table.insert(lines, M.config.delimiter)
	table.insert(lines, "Time: " .. timestamp)
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

	vim.api.nvim_buf_set_lines(buf, -1, -1, false, lines)
end

function M.run()
	if not vim.system then
		vim.notify("vim.system is not available in this Neovim version", vim.log.levels.ERROR)
		return
	end

	local buf = vim.api.nvim_get_current_buf()
	local cwd = vim.fn.getcwd()

	if not is_thread_buffer(buf, cwd) then
		vim.notify("Codex run is only allowed in .ai/threads files under the current working directory", vim.log.levels.WARN)
		return
	end

	local helper = M.config.helper
	if vim.fn.filereadable(helper) ~= 1 then
		vim.notify("Codex helper not found: " .. helper, vim.log.levels.ERROR)
		return
	end

	local input_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	local input = table.concat(input_lines, "\n") .. "\n"
	local cmd = { helper }

	for _, flag in ipairs(M.config.flags or {}) do
		table.insert(cmd, flag)
	end

	vim.notify("Running Codex...", vim.log.levels.INFO)

	vim.system(cmd, { text = true, stdin = input }, function(result)
		vim.schedule(function()
			append_block(buf, result.stdout or "", result.stderr or "")
			vim.notify("Codex finished", vim.log.levels.INFO)
		end)
	end)
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
