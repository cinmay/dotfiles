local source = debug.getinfo(1, "S").source:sub(2)
local tests = vim.fs.dirname(vim.fn.fnamemodify(source, ":p"))
local config = vim.fs.normalize(tests .. "/../../../../..")
vim.opt.rtp:append(config)
vim.o.columns, vim.o.lines = 140, 50
local notifications = {}
vim.notify = function(message)
	table.insert(notifications, message)
end
local claude = require("custom.claude")
claude.setup({ command = tests .. "/fake_claude.py", done_sound = "", desktop_notify = "" })

local function wait(predicate, label)
	assert(vim.wait(6000, predicate, 10), "Timed out: " .. label .. "\n" .. table.concat(notifications, "\n"))
end
local function buffer(name)
	return vim.fn.bufnr("claude://" .. name)
end
local function lines_of(buf)
	return table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
end
local function text(name)
	local buf = buffer(name)
	return buf >= 0 and lines_of(buf) or ""
end
local function window(name)
	return vim.fn.bufwinid(buffer(name))
end
local function title()
	return vim.wo[window("history")].winbar
end
local function has_title(value)
	return title():find(value, 1, true) ~= nil
end
local function has_history(value)
	return text("history"):find(value, 1, true) ~= nil
end
local function prompt(value)
	vim.api.nvim_buf_set_lines(buffer("prompt"), 0, -1, false, { value })
end
local function mapping(key)
	for _, map in ipairs(vim.api.nvim_buf_get_keymap(0, "n")) do
		if map.lhs == key then
			return map.callback
		end
	end
	error("No buffer mapping: " .. key)
end
local function press(key)
	mapping(key)()
end
local function send(value)
	prompt(value)
	claude.send()
end
local function wait_title(value)
	wait(function()
		return has_title(value)
	end, value)
end
local function done()
	wait_title("Done")
	vim.wait(70)
end
-- A request replaces the prompt in the prompt window and takes focus there.
local function request()
	wait_title("Response required")
	local win = vim.api.nvim_get_current_win()
	assert(vim.api.nvim_win_get_buf(win) ~= buffer("prompt"), "Prompt still shown")
	assert(vim.api.nvim_win_get_height(win) == 18, "Request is not in the prompt window")
	return lines_of(0)
end

local function run()
	local code_buf = vim.api.nvim_get_current_buf()
	vim.api.nvim_buf_set_name(code_buf, vim.fn.tempname() .. ".lua")
	vim.api.nvim_buf_set_lines(code_buf, 0, -1, false, { "-- unsaved code", "local value = 1", "return value" })
	vim.api.nvim_win_set_cursor(0, { 2, 4 })
	vim.wo.winbar, vim.wo.wrap = "Original code winbar", false
	assert(vim.fn.maparg("<leader>ana", "n") ~= "", "Missing global new-chat key")
	assert(vim.fn.maparg("<leader>as", "n") == "", "Send must only exist inside the chat")

	claude.new()
	wait_title("Ready")
	assert(has_title("default model · Auto"))
	assert(not vim.bo[buffer("history")].modifiable)
	assert(#vim.api.nvim_list_tabpages() == 1 and #vim.api.nvim_list_wins() == 2)
	assert(vim.api.nvim_win_get_position(window("history"))[1] < vim.api.nvim_win_get_position(window("prompt"))[1])
	assert(vim.api.nvim_win_get_height(window("prompt")) == 18)
	assert(vim.bo[buffer("history")].buftype == "nofile")
	assert(vim.bo[buffer("prompt")].buftype == "" and not vim.bo[buffer("prompt")].swapfile)
	for _, name in ipairs({ "history", "prompt" }) do
		vim.api.nvim_buf_call(buffer(name), function()
			assert(vim.fn.maparg("<leader>as", "n") ~= "" and vim.fn.maparg("<leader>ax", "n") ~= "")
		end)
	end
	prompt("Draft survives :q")
	vim.cmd.quit()
	assert(#vim.api.nvim_list_wins() == 1 and vim.api.nvim_get_current_buf() == code_buf)
	assert(vim.bo[code_buf].modified and vim.wo.winbar == "Original code winbar" and not vim.wo.wrap)
	assert(vim.deep_equal(vim.api.nvim_win_get_cursor(0), { 2, 4 }))
	claude.open()
	assert(text("prompt") == "Draft survives :q")

	send("stream")
	done()
	assert(text("prompt") == "")
	assert(has_history("## You\n\nstream"))
	assert(has_history("Høllo — final authoritative text"))
	local _, count = text("history"):gsub("final authoritative text", "")
	assert(count == 1, "Finished block duplicated the streamed text")
	assert(has_history("• Read calc.py · done"), "Tool path should be relative to the project")
	assert(not has_history("DO NOT SHOW"), "Subagent text leaked into the history")
	assert(has_history("Session: fake-session"))
	assert(has_title("Opus 5.5 · Auto · Done"))
	assert(vim.tbl_contains(notifications, "Claude: request not supported: hook_callback"))

	send("notice")
	done()
	assert(has_history("> Opus 5.5's safeguards stopped the response above"))
	assert(has_title("Opus 4.8"), "Winbar must follow the model Claude reports")

	-- Questions: one at a time, single choice then multi-select; stale keys do nothing.
	send("question")
	assert(request():find("Which size?", 1, true))
	local stale = mapping("2")
	press("2")
	assert(lines_of(0):find("Which colours?", 1, true))
	stale()
	press("1")
	press("2")
	assert(lines_of(0):find("[x] Red", 1, true) and lines_of(0):find("[ ] Green", 1, true))
	press("<CR>")
	done()
	assert(vim.api.nvim_win_get_buf(window("prompt")) == buffer("prompt"), "Prompt not restored")
	assert(vim.api.nvim_get_current_win() == window("prompt"))
	assert(has_history("• AskUserQuestion Which size? · done"))

	send("plan")
	assert(request():find("- Step two", 1, true))
	wait(function()
		return has_history("## Plan\n\n- Step one")
	end, "plan in history")
	press("1")
	done()

	send("deny")
	request()
	press("2")
	done()
	assert(has_history("• Bash echo hi · error"))

	send("allow")
	local shown = request()
	assert(shown:find("echo hi", 1, true) and shown:find("Outside allowed paths", 1, true))
	vim.api.nvim_buf_set_lines(buffer("prompt"), 0, -1, false, { "Draft written meanwhile" })
	press("1")
	done()
	assert(text("prompt") == "Draft written meanwhile", "Answering lost the draft")
	prompt("")

	-- A request that arrives while the chat is hidden waits for the chat to open.
	send("hidden")
	vim.cmd.quit()
	wait(function()
		return vim.tbl_contains(notifications, "Claude: needs your response. Open the chat to answer.")
	end, "hidden request notification")
	assert(#vim.api.nvim_list_wins() == 1 and vim.api.nvim_get_current_buf() == code_buf)
	claude.open()
	assert(request():find("echo hi", 1, true))
	vim.cmd.quit()
	assert(vim.api.nvim_get_current_buf() == code_buf, ":q from a request should return to code")
	claude.open()
	request()
	press("1")
	done()

	send("wait")
	wait_title("Running")
	vim.cmd.quit()
	claude.open()
	assert(has_title("Running"), "Quitting the view cancelled the turn")
	claude.new()
	assert(vim.tbl_contains(notifications, "Claude: Finish or interrupt the current turn first"))
	claude.interrupt()
	wait_title("Interrupted")

	send("error")
	wait(function()
		return has_title("Error") and has_history("API Error: overloaded")
	end, "turn error")

	-- A crash keeps the history; reopening resumes the same session.
	send("crash")
	wait(function()
		return has_title("Error") and has_history("Claude exited (7)")
	end, "crash")
	claude.open()
	wait_title("Ready")
	assert(has_history("## You\n\ncrash") and has_history("final authoritative text"))
	send("stream")
	done()

	claude.new()
	wait_title("Ready")
	assert(not has_history("final authoritative text"), "New chat kept the old history")
	vim.cmd.buffer(code_buf)
	assert(#vim.api.nvim_list_wins() == 1 and vim.api.nvim_get_current_buf() == code_buf)
	print("PASS: layout/:q, streaming, tools, notices, questions, plans, permissions, hidden requests, interrupt, errors, reconnect")
end

local ok, err = xpcall(run, debug.traceback)
if not ok then
	io.stderr:write(err .. "\n")
	vim.cmd("cquit 1")
else
	vim.cmd("qa!")
end
