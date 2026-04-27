local M = {}

local defaults = {
	endpoint = "http://127.0.0.1:8880/v1/audio/speech",
	model = "kokoro",
	voice = "af_heart",
	response_format = "mp3",
	tmp_dir = "/tmp/nvim-tts",
	max_chars = 12000,
	speak_script = vim.fn.stdpath("config") .. "/scripts/nvim-tts-speak",
	control_script = vim.fn.stdpath("config") .. "/scripts/nvim-tts-control",
	mappings = {
		operator = "gs",
		line = "gss",
		visual = "gs",
		pause_toggle = "<leader>rp",
	},
	force_mappings = false,
}

M.config = vim.deepcopy(defaults)

local function notify(message, level)
	local callback = function()
		vim.notify(message, level or vim.log.levels.INFO, { title = "Local TTS" })
	end

	if vim.in_fast_event() then
		vim.schedule(callback)
	else
		callback()
	end
end

local function trim(text)
	return (text or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function script_is_ready(path, label)
	if not path or path == "" then
		notify(label .. " path is empty", vim.log.levels.ERROR)
		return false
	end

	if vim.fn.filereadable(path) ~= 1 then
		notify(label .. " is missing: " .. path, vim.log.levels.ERROR)
		return false
	end

	if vim.fn.executable(path) ~= 1 then
		notify(label .. " is not executable: " .. path, vim.log.levels.ERROR)
		return false
	end

	return true
end

local function env()
	return {
		NVIM_TTS_ENDPOINT = M.config.endpoint,
		NVIM_TTS_MODEL = M.config.model,
		NVIM_TTS_VOICE = M.config.voice,
		NVIM_TTS_RESPONSE_FORMAT = M.config.response_format,
		NVIM_TTS_TMP_DIR = M.config.tmp_dir,
		NVIM_TTS_MAX_CHARS = tostring(M.config.max_chars),
	}
end

local function run_async(command, opts, on_exit)
	opts = opts or {}

	if vim.system then
		vim.system(command, {
			env = opts.env,
			stdin = opts.stdin,
			text = true,
		}, function(result)
			local code = result.code
			if code == nil and result.signal and result.signal ~= 0 then
				code = 128 + result.signal
			end
			on_exit(code or 0, result.stdout or "", result.stderr or "")
		end)
		return true
	end

	local stdout = {}
	local stderr = {}
	local job = vim.fn.jobstart(command, {
		env = opts.env,
		stdout_buffered = true,
		stderr_buffered = true,
		on_stdout = function(_, data)
			if data then
				vim.list_extend(stdout, data)
			end
		end,
		on_stderr = function(_, data)
			if data then
				vim.list_extend(stderr, data)
			end
		end,
		on_exit = function(_, code)
			on_exit(code, table.concat(stdout, "\n"), table.concat(stderr, "\n"))
		end,
	})

	if job <= 0 then
		return false
	end

	if opts.stdin then
		vim.fn.chansend(job, opts.stdin)
	end
	vim.fn.chanclose(job, "stdin")

	return true
end

local function command_result_message(stdout, stderr, fallback)
	local message = trim(stderr)
	if message ~= "" then
		return message
	end

	message = trim(stdout)
	if message ~= "" then
		return message
	end

	return fallback
end

local function ordered_positions(start_pos, end_pos)
	if start_pos[2] > end_pos[2] or (start_pos[2] == end_pos[2] and start_pos[3] > end_pos[3]) then
		return end_pos, start_pos
	end

	return start_pos, end_pos
end

local function normalized_type(selection_type)
	if selection_type == "line" or selection_type == "V" then
		return "line"
	end

	if selection_type == "block" or selection_type == "\022" then
		return "block"
	end

	return "char"
end

local function charwise_text(bufnr, start_pos, end_pos)
	start_pos, end_pos = ordered_positions(start_pos, end_pos)

	local start_row = start_pos[2] - 1
	local end_row = end_pos[2] - 1
	local line_count = vim.api.nvim_buf_line_count(bufnr)

	if start_row < 0 or end_row < 0 or start_row >= line_count then
		return ""
	end

	end_row = math.min(end_row, line_count - 1)

	local start_line = vim.api.nvim_buf_get_lines(bufnr, start_row, start_row + 1, false)[1] or ""
	local end_line = vim.api.nvim_buf_get_lines(bufnr, end_row, end_row + 1, false)[1] or ""
	local start_col = math.min(math.max(start_pos[3] - 1, 0), #start_line)
	local end_col = math.min(math.max(end_pos[3], 0), #end_line)

	if start_row == end_row and end_col < start_col then
		end_col = start_col
	end

	local lines = vim.api.nvim_buf_get_text(bufnr, start_row, start_col, end_row, end_col, {})
	return table.concat(lines, "\n")
end

local function linewise_text(bufnr, start_pos, end_pos)
	start_pos, end_pos = ordered_positions(start_pos, end_pos)

	local start_row = start_pos[2] - 1
	local end_row = end_pos[2]
	local line_count = vim.api.nvim_buf_line_count(bufnr)

	if start_row < 0 or start_row >= line_count then
		return ""
	end

	end_row = math.min(math.max(end_row, start_row + 1), line_count)

	local lines = vim.api.nvim_buf_get_lines(bufnr, start_row, end_row, false)
	return table.concat(lines, "\n")
end

local function blockwise_text(bufnr, start_pos, end_pos)
	start_pos, end_pos = ordered_positions(start_pos, end_pos)

	local start_row = start_pos[2] - 1
	local end_row = end_pos[2]
	local line_count = vim.api.nvim_buf_line_count(bufnr)

	if start_row < 0 or start_row >= line_count then
		return ""
	end

	end_row = math.min(math.max(end_row, start_row + 1), line_count)

	-- Sane blockwise fallback: use byte columns from the marks. This keeps the
	-- selected rectangle useful without yanking, though tabs/wide chars may not
	-- align exactly like screen columns.
	local start_col = math.max(math.min(start_pos[3], end_pos[3]), 1)
	local end_col = math.max(start_pos[3], end_pos[3])
	local source = vim.api.nvim_buf_get_lines(bufnr, start_row, end_row, false)
	local lines = {}

	for _, line in ipairs(source) do
		if #line >= start_col then
			table.insert(lines, line:sub(start_col, math.min(end_col, #line)))
		else
			table.insert(lines, "")
		end
	end

	return table.concat(lines, "\n")
end

local function text_from_positions(bufnr, start_pos, end_pos, selection_type)
	if start_pos[2] == 0 or end_pos[2] == 0 then
		return ""
	end

	selection_type = normalized_type(selection_type)

	if selection_type == "line" then
		return linewise_text(bufnr, start_pos, end_pos)
	end

	if selection_type == "block" then
		return blockwise_text(bufnr, start_pos, end_pos)
	end

	return charwise_text(bufnr, start_pos, end_pos)
end

local function region_text(bufnr, start_mark, end_mark, selection_type)
	return text_from_positions(bufnr, vim.fn.getpos(start_mark), vim.fn.getpos(end_mark), selection_type)
end

local function speak_range(line1, line2)
	local lines = vim.api.nvim_buf_get_lines(0, line1 - 1, line2, false)
	M.speak_text(table.concat(lines, "\n"))
end

local function set_mapping(mode, lhs, rhs, opts)
	if not lhs or lhs == "" then
		notify("TTS mapping for mode " .. mode .. " is empty; skipping", vim.log.levels.WARN)
		return
	end

	local existing = vim.fn.maparg(lhs, mode, false, true)
	if type(existing) == "table" and next(existing) ~= nil and not M.config.force_mappings then
		notify("TTS mapping " .. lhs .. " already exists in " .. mode .. " mode; skipping", vim.log.levels.WARN)
		return
	end

	vim.keymap.set(mode, lhs, rhs, opts)
end

function M.speak_text(text)
	text = text or ""

	if trim(text) == "" then
		notify("No text to speak", vim.log.levels.WARN)
		return
	end

	local max_chars = tonumber(M.config.max_chars) or defaults.max_chars
	local char_count = vim.fn.strchars(text)
	if char_count > max_chars then
		notify(
			string.format("Text is too long for TTS: %d characters, max is %d", char_count, max_chars),
			vim.log.levels.ERROR
		)
		return
	end

	if not script_is_ready(M.config.speak_script, "TTS speak helper") then
		return
	end

	notify("Generating speech", vim.log.levels.INFO)

	local ok = run_async({ M.config.speak_script }, {
		env = env(),
		stdin = text,
	}, function(code, stdout, stderr)
		if code == 0 then
			notify(command_result_message(stdout, "", "TTS playback started"), vim.log.levels.INFO)
		else
			notify(command_result_message(stdout, stderr, "TTS failed with exit code " .. code), vim.log.levels.ERROR)
		end
	end)

	if not ok then
		notify("Failed to start TTS speak helper", vim.log.levels.ERROR)
	end
end

function M.speak_lines(count)
	count = tonumber(count) or vim.v.count1 or 1
	count = math.max(count, 1)

	local start_line = vim.api.nvim_win_get_cursor(0)[1]
	local end_line = math.min(start_line + count - 1, vim.api.nvim_buf_line_count(0))
	speak_range(start_line, end_line)
end

function M.speak_visual()
	local mode = vim.fn.mode()
	local text

	if mode == "v" or mode == "V" or mode == "\022" then
		text = text_from_positions(0, vim.fn.getpos("v"), vim.fn.getcurpos(), mode)
		vim.cmd("normal! \027")
	else
		text = region_text(0, "'<", "'>", vim.fn.visualmode())
	end

	M.speak_text(text)
end

function M.start_operator()
	_G.local_tts_operatorfunc = function(selection_type)
		require("local_tts").operatorfunc(selection_type)
	end

	vim.go.operatorfunc = "v:lua.local_tts_operatorfunc"
	return "g@"
end

function M.operatorfunc(selection_type)
	local text = region_text(0, "'[", "']", selection_type)
	M.speak_text(text)
end

local function run_control(action)
	if not script_is_ready(M.config.control_script, "TTS control helper") then
		return
	end

	local ok = run_async({ M.config.control_script, action }, {
		env = env(),
	}, function(code, stdout, stderr)
		if code == 0 then
			notify(command_result_message(stdout, "", "TTS " .. action .. " sent"), vim.log.levels.INFO)
		else
			notify(command_result_message(stdout, stderr, "TTS " .. action .. " failed"), vim.log.levels.ERROR)
		end
	end)

	if not ok then
		notify("Failed to start TTS control helper", vim.log.levels.ERROR)
	end
end

function M.toggle_pause()
	run_control("toggle")
end

function M.stop()
	run_control("stop")
end

function M.status()
	run_control("status")
end

function M.register_commands()
	vim.api.nvim_create_user_command("TtsSpeakLine", function(args)
		if args.range > 0 then
			speak_range(args.line1, args.line2)
		else
			M.speak_lines(1)
		end
	end, { range = true, desc = "Speak the current line or command range" })

	vim.api.nvim_create_user_command("TtsSpeakSelection", function(args)
		if args.range > 0 then
			speak_range(args.line1, args.line2)
		else
			M.speak_visual()
		end
	end, { range = true, desc = "Speak the current visual selection or command range" })

	vim.api.nvim_create_user_command("TtsSpeakBuffer", function()
		speak_range(1, vim.api.nvim_buf_line_count(0))
	end, { desc = "Speak the current buffer" })

	vim.api.nvim_create_user_command("TtsPauseToggle", function()
		M.toggle_pause()
	end, { desc = "Pause or resume TTS playback" })

	vim.api.nvim_create_user_command("TtsStop", function()
		M.stop()
	end, { desc = "Stop TTS playback" })

	vim.api.nvim_create_user_command("TtsStatus", function()
		M.status()
	end, { desc = "Show TTS playback status" })
end

function M.register_mappings()
	if M.config.mappings == false then
		return
	end

	local mappings = M.config.mappings or {}

	set_mapping("n", mappings.operator, function()
		return require("local_tts").start_operator()
	end, { desc = "Speak text covered by a motion", expr = true, silent = true })

	set_mapping("n", mappings.line, function()
		require("local_tts").speak_lines(vim.v.count1)
	end, { desc = "Speak current line", silent = true })

	set_mapping("x", mappings.visual, function()
		require("local_tts").speak_visual()
	end, { desc = "Speak visual selection", silent = true })

	set_mapping("n", mappings.pause_toggle, function()
		require("local_tts").toggle_pause()
	end, { desc = "Pause or resume TTS playback", silent = true })
end

function M.setup(opts)
	M.config = vim.tbl_deep_extend("force", vim.deepcopy(defaults), opts or {})

	if opts and opts.mappings == false then
		M.config.mappings = false
	elseif M.config.mappings ~= false then
		M.config.mappings = vim.tbl_deep_extend("force", vim.deepcopy(defaults.mappings), M.config.mappings or {})
	end

	M.register_commands()
	M.register_mappings()
end

return M
