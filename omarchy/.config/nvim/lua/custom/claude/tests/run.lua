local source = debug.getinfo(1, "S").source:sub(2)
local tests = vim.fs.dirname(vim.fn.fnamemodify(source, ":p"))
local config = vim.fs.normalize(tests .. "/../../../../..")
vim.opt.rtp:append(config)
for _, plugin in ipairs({ "plenary.nvim", "telescope.nvim", "harpoon" }) do
	vim.opt.rtp:append(vim.fn.stdpath("data") .. "/lazy/" .. plugin)
end
-- Real Harpoon persistence and a Claude session store, isolated from the user's data.
vim.env.XDG_DATA_HOME = vim.fn.tempname()
vim.fn.mkdir(vim.fn.stdpath("data"), "p")
local store = vim.fn.tempname()
vim.env.CLAUDE_CONFIG_DIR = store
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

local function write_session(project, id, entries)
	local dir = store .. "/projects/" .. project:gsub("[^%w]", "-")
	vim.fn.mkdir(dir, "p")
	local lines = {}
	for _, entry in ipairs(entries) do
		table.insert(lines, vim.json.encode(entry))
	end
	vim.fn.writefile(lines, dir .. "/" .. id .. ".jsonl")
	return dir .. "/" .. id .. ".jsonl"
end
local function typed(uuid, parent, content, extra)
	local entry = { type = "user", uuid = uuid, parentUuid = parent, cwd = vim.fn.getcwd(), promptSource = "sdk" }
	entry.message = { role = "user", content = content }
	return vim.tbl_extend("force", entry, extra or {})
end
local function answer(uuid, parent, content)
	local usage = { input_tokens = 1, cache_read_input_tokens = 50000, cache_creation_input_tokens = 0 }
	local message = { role = "assistant", model = "claude-opus-5-5", content = content, usage = usage }
	return { type = "assistant", uuid = uuid, parentUuid = parent, effort = "high", message = message }
end
local function write_fixtures()
	local cwd = vim.fn.getcwd()
	write_session(cwd, "resumed-session", {
		{ type = "queue-operation", operation = "enqueue" },
		typed("u1", nil, "From the CLI: blåbær"),
		answer("a1", "u1", { { type = "text", text = "Old answer" } }),
		answer("a2", "a1", { { type = "tool_use", id = "toolu_old", name = "Bash", input = { command = "git status" } } }),
		{
			type = "user",
			uuid = "r1",
			parentUuid = "a2",
			message = { role = "user", content = { { type = "tool_result", tool_use_id = "toolu_old", content = "clean" } } },
		},
		{ type = "system", subtype = "away_summary", uuid = "s1", parentUuid = "r1", content = "AWAY RECAP" },
		{ type = "system", subtype = "informational", uuid = "s2", parentUuid = "s1", content = "An old notice" },
		{
			type = "user",
			uuid = "c1",
			parentUuid = "s2",
			message = { role = "user", content = "<command-name>/model</command-name>" },
		},
		typed("u2", "c1", "ABANDONED BRANCH"),
		answer("a3", "u2", { { type = "text", text = "ABANDONED ANSWER" } }),
		typed("u3", "c1", "Rewound prompt"),
		answer("a4", "u3", { { type = "text", text = "Latest answer" } }),
		typed("n1", "a4", "<task-notification>HIDDEN", { origin = { kind = "task-notification" } }),
		{ type = "ai-title", aiTitle = "Fixture conversation" },
	})
	write_session(cwd, "gone-session", { typed("g1", nil, "Old project", { cwd = "/nonexistent/claude-test" }) })
	write_session(cwd, "busy-session", { typed("b1", nil, "Open in the CLI") })
	write_session(cwd, "empty-session", { { type = "queue-operation", operation = "enqueue" } })
	vim.fn.mkdir(store .. "/sessions", "p")
	vim.fn.writefile({ vim.json.encode({ pid = vim.fn.getpid(), sessionId = "busy-session" }) }, store .. "/sessions/1.json")
	local other_project = vim.fn.tempname()
	vim.fn.mkdir(other_project, "p")
	local other = write_session(other_project, "other-session", {
		typed("o1", nil, "Other prompt\nsecond line", { cwd = other_project }),
		answer("o2", "o1", { { type = "text", text = "Other answer" } }),
	})
	-- Newest first in the picker.
	vim.uv.fs_utime(other, os.time() + 60, os.time() + 60)
end

local function run()
	write_fixtures()
	local code_buf = vim.api.nvim_get_current_buf()
	vim.api.nvim_buf_set_name(code_buf, vim.fn.tempname() .. ".lua")
	vim.api.nvim_buf_set_lines(code_buf, 0, -1, false, { "-- unsaved code", "local value = 1", "return value" })
	vim.api.nvim_win_set_cursor(0, { 2, 4 })
	vim.wo.winbar, vim.wo.wrap = "Original code winbar", false
	assert(vim.fn.maparg("<leader>ana", "n") ~= "", "Missing global new-chat key")
	assert(vim.fn.maparg("<leader>as", "n") == "", "Send must only exist inside the chat")

	claude.new()
	wait_title("Ready")
	assert(has_title("default model · default effort · Auto"))
	assert(not vim.bo[buffer("history")].modifiable)
	assert(#vim.api.nvim_list_tabpages() == 1 and #vim.api.nvim_list_wins() == 2)
	assert(vim.api.nvim_win_get_position(window("history"))[1] < vim.api.nvim_win_get_position(window("prompt"))[1])
	assert(vim.api.nvim_win_get_height(window("prompt")) == 18)
	assert(vim.bo[buffer("history")].buftype == "nofile")
	assert(vim.bo[buffer("prompt")].buftype == "" and not vim.bo[buffer("prompt")].swapfile)
	for _, name in ipairs({ "history", "prompt" }) do
		vim.api.nvim_buf_call(buffer(name), function()
			for _, key in ipairs({ "<leader>as", "<leader>am", "<leader>ax" }) do
				assert(vim.fn.maparg(key, "n") ~= "", "Missing chat key " .. key)
			end
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
	assert(has_title("Opus 5.5 · default effort · Auto · Done"))
	assert(has_title("ctx 3%") and has_title("5h 12%"), "Missing context or usage-limit display")
	assert(vim.tbl_contains(notifications, "Claude: request not supported: hook_callback"))

	send("notice")
	done()
	assert(has_history("> Opus 5.5's safeguards stopped the response above"))
	assert(has_title("Opus 4.8"), "Winbar must follow the model Claude reports")

	-- One settings menu: model, effort, and permission mode, each applied by Claude.
	local picks = {}
	vim.ui.select = function(items, _, callback)
		local want = table.remove(picks, 1)
		for i, item in ipairs(items) do
			if want(item) then
				return callback(item, i)
			end
		end
		error("No matching choice")
	end
	local function choose(setting, value)
		picks = {
			function(item)
				return item.label:find("^" .. setting) ~= nil
			end,
			value,
		}
		claude.models()
	end
	choose("Model", function(model)
		return model.value == "opus"
	end)
	wait_title("Opus 5.5 · default effort")
	choose("Effort", function(level)
		return level == "low"
	end)
	wait_title("Opus 5.5 · low · Auto")
	choose("Permission mode", function(mode)
		return mode == "plan"
	end)
	wait_title("low · Plan ·")
	choose("Permission mode", function(mode)
		return mode == "auto"
	end)
	wait_title("low · Auto ·")

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

	-- Resume from Claude Code's session store; failures leave the conversation alone.
	claude.resume("missing-session")
	assert(vim.tbl_contains(notifications, "Claude: Session not found: missing-session"))
	claude.resume("gone-session")
	assert(notifications[#notifications]:find("directory no longer exists", 1, true))
	claude.resume("busy-session")
	assert(notifications[#notifications]:find("open in another Claude process", 1, true))
	assert(has_history("final authoritative text"), "Failed resume replaced the history")
	prompt("Draft for the first chat")
	claude.resume("resumed-session")
	wait_title("Ready")
	for _, shown in ipairs({ "From the CLI: blåbær", "Old answer", "• Bash git status · done", "> An old notice" }) do
		assert(has_history(shown), "Missing from resumed history: " .. shown)
	end
	assert(has_history("## You\n\nRewound prompt") and has_history("Latest answer"))
	for _, hidden in ipairs({ "AWAY RECAP", "/model", "ABANDONED", "HIDDEN", "final authoritative text" }) do
		assert(not has_history(hidden), "Should be hidden in resumed history: " .. hidden)
	end
	assert(has_title("Opus 5.5 · high · Auto · Ready") and has_title("ctx 50k"))
	assert(has_history("Session: resumed-session"))
	assert(text("prompt") == "", "Resumed chat took another chat's draft")
	prompt("Draft for the resumed chat")
	claude.resume("other-session")
	wait_title("Ready")
	assert(has_history("Other answer") and text("prompt") == "")
	claude.resume("resumed-session")
	wait_title("Ready")
	assert(text("prompt") == "Draft for the resumed chat")
	prompt("")
	send("stream")
	done()
	assert(has_history("Latest answer") and has_history("final authoritative text"), "Resumed chat did not continue")

	-- Telescope session picker: this project by default, every project with a bang.
	require("telescope").setup({ defaults = { initial_mode = "normal" } })
	local actions = require("telescope.actions")
	local action_state = require("telescope.actions.state")
	local function picker()
		local ok, value = pcall(action_state.get_current_picker, vim.api.nvim_get_current_buf())
		return ok and value or nil
	end
	claude.sessions(false)
	wait(function()
		return picker() and picker().prompt_title:find("current directory", 1, true)
	end, "session picker")
	wait(function()
		return picker().manager and picker().manager:num_results() == 3
	end, "sessions for this project, without the unused one")
	actions.close(vim.api.nvim_get_current_buf())
	claude.sessions(true)
	wait(function()
		return picker() and picker().prompt_title:find("all projects", 1, true)
	end, "all-projects picker")
	wait(function()
		return picker().manager and picker().manager:num_results() == 4
	end, "sessions for all projects")
	actions.select_default(vim.api.nvim_get_current_buf())
	wait(function()
		return has_history("Other answer")
	end, "picked session")

	-- Harpoon bookmarks conversations next to files.
	local harpoon_spec = require("custom.plugins.harpoon")
	local harpoon = require("harpoon")
	harpoon:setup(harpoon_spec.opts())
	local toggle_bookmark = harpoon_spec.keys()[1][2]
	local bookmarks = harpoon:list()
	bookmarks:clear()
	claude.hide()
	toggle_bookmark()
	claude.open()
	toggle_bookmark()
	vim.api.nvim_set_current_win(window("history"))
	toggle_bookmark()
	assert(bookmarks:length() == 2, "History and prompt created duplicate bookmarks")
	assert(bookmarks.items[2].value == "claude://other-session" and bookmarks.items[2].context.title == "Other prompt")
	bookmarks:add({ value = "claude://resumed-session", context = { title = "Fixture conversation" } })
	assert(bookmarks:display()[3] == "Claude: Fixture conversation [claude://resumed-session]")
	bookmarks:select(3)
	wait(function()
		return has_history("Latest answer")
	end, "bookmarked conversation")
	bookmarks:select(1)
	assert(#vim.api.nvim_list_wins() == 1 and vim.api.nvim_get_current_buf() == code_buf)
	bookmarks:select(3)
	assert(#vim.api.nvim_list_wins() == 2 and has_history("Latest answer"), "Reopening the open chat failed")
	local displayed = bookmarks:display()
	bookmarks:resolve_displayed({ displayed[1], displayed[2], (displayed[3]:gsub("^Claude:.- %[", "Claude: Renamed [")) }, 3)
	assert(bookmarks.items[3].value == "claude://resumed-session" and bookmarks.items[3].context.title == "Renamed")

	prompt("Draft kept with the resumed chat")
	claude.new()
	wait_title("Ready")
	assert(not has_history("final authoritative text"), "New chat kept the old history")
	assert(text("prompt") == "", "New chat took the previous chat's draft")
	vim.cmd.buffer(code_buf)
	assert(#vim.api.nvim_list_wins() == 1 and vim.api.nvim_get_current_buf() == code_buf)
	print(
		"PASS: layout/:q, streaming, tools, notices, settings menu, questions, plans, permissions, hidden requests,"
			.. " interrupt, errors, reconnect, resume, drafts, Telescope, Harpoon"
	)
end

local ok, err = xpcall(run, debug.traceback)
if not ok then
	io.stderr:write(err .. "\n")
	vim.cmd("cquit 1")
else
	vim.cmd("qa!")
end
