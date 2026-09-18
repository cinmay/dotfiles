local source = debug.getinfo(1, "S").source:sub(2)
local tests = vim.fs.dirname(vim.fn.fnamemodify(source, ":p"))
local config = vim.fs.normalize(tests .. "/../../../../..")
vim.opt.rtp:append(config)
for _, plugin in ipairs({ "plenary.nvim", "telescope.nvim" }) do
	vim.opt.rtp:append(vim.fn.stdpath("data") .. "/lazy/" .. plugin)
end
vim.o.columns, vim.o.lines = 140, 50
local notifications = {}
vim.notify = function(message)
	table.insert(notifications, message)
end
local codex = require("custom.codex")
codex.setup({ command = tests .. "/fake_server.py", done_sound = "" })

local function wait(predicate, label)
	assert(vim.wait(6000, predicate, 10), "Timed out: " .. label .. "\n" .. table.concat(notifications, "\n"))
end
local function buffer(name)
	return vim.fn.bufnr("codex://" .. name)
end
local function text(name)
	local buf = buffer(name)
	return buf >= 0 and table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n") or ""
end
local function window(name)
	return vim.fn.bufwinid(buffer(name))
end
local function title()
	local value = vim.api.nvim_win_get_config(window("history")).title
	return type(value) == "table" and value[1][1] or value
end
local function has_title(value)
	return title():find(value, 1, true) ~= nil
end
local function prompt(value)
	vim.api.nvim_buf_set_lines(buffer("prompt"), 0, -1, false, { value })
end
local function press(key)
	for _, mapping in ipairs(vim.api.nvim_buf_get_keymap(0, "n")) do
		if mapping.lhs == key then
			mapping.callback()
			return
		end
	end
	error("No buffer mapping: " .. key)
end
local function send(value)
	prompt(value)
	codex.send()
end
local function ready()
	wait(function()
		return has_title("Ready")
	end, "session ready")
end
local function completed()
	wait(function()
		return has_title("completed")
	end, "turn completed")
	vim.wait(70)
end
local function approval()
	wait(function()
		return has_title("Response required")
	end, "approval popup")
end

local function run()
	codex.open()
	ready()
	assert(has_title("model-a · high"))
	assert(not vim.bo[buffer("history")].modifiable)
	send("stream")
	completed()
	assert(text("prompt") == "")
	assert(text("history"):find("Høllo — final authoritative text", 1, true))
	assert(not text("history"):find("DO NOT SHOW", 1, true))
	local _, count = text("history"):gsub("final authoritative text", "")
	assert(count == 1, "Completed item duplicated streaming output")

	vim.ui.select = function(items, _, callback)
		callback(items[#items], #items)
	end
	codex.models()
	wait(function()
		return has_title("model-b · high")
	end, "model and effort picker")
	send("fast")
	completed()
	send("approval")
	approval()
	assert(table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n"):find("npm install", 1, true))
	press("<Esc>")
	assert(has_title("Response required"), "Hiding implicitly answered approval")
	codex.approval()
	press("a")
	completed()
	assert(text("history"):find("Response received: approval", 1, true))
	send("file")
	approval()
	assert(table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n"):find("-old\n+new", 1, true))
	press("d")
	completed()
	send("permissions")
	approval()
	press("a")
	completed()
	vim.ui.select = function(items, _, callback)
		callback(items[1], 1)
	end
	send("question")
	approval()
	press("a")
	completed()

	send("wait")
	wait(function()
		return has_title("Running")
	end, "running turn")
	codex.hide()
	assert(window("history") == -1)
	codex.open()
	assert(has_title("Running"), "Hiding cancelled the turn")
	codex.interrupt()
	wait(function()
		return has_title("interrupted")
	end, "interrupt")

	prompt("Keep this draft")
	codex.new()
	assert(text("prompt") == "Keep this draft", "Cancelled switch lost draft")
	prompt("")
	codex.resume("external")
	ready()
	assert(text("history"):find("From the desktop app", 1, true))
	assert(text("history"):find("External history: blåbær", 1, true))
	assert(not text("history"):find("final authoritative text", 1, true))
	prompt("Draft survives refresh")
	vim.cmd.CodexRefresh()
	ready()
	assert(text("prompt") == "Draft survives refresh")
	prompt("")
	codex.resume("legacy")
	ready()
	assert(text("history"):find("Legacy CLI history", 1, true))
	codex.resume("missing")
	wait(function()
		return has_title("Error")
	end, "missing session error")
	assert(text("history"):find("Legacy CLI history", 1, true), "Failed resume replaced history")
	codex.resume("external")
	ready()
	send("fail-start")
	wait(function()
		return has_title("Error")
	end, "send failure")
	assert(text("prompt") == "fail-start", "Failed send discarded prompt")
	codex.open()
	ready()
	prompt("crash")
	codex.send()
	wait(function()
		return has_title("Error")
	end, "server crash")
	assert(text("prompt") == "crash", "Crash discarded draft")
	codex.open()
	ready()
	assert(text("prompt") == "crash", "Reconnect replayed or discarded draft")
	prompt("")

	-- Exercise real Telescope adapters, including multi-selection of a directory and file.
	require("telescope").setup({ defaults = { layout_config = { width = 0.8, height = 0.7 } } })
	local actions = require("telescope.actions")
	local action_state = require("telescope.actions.state")
	local function picker()
		local ok, value = pcall(action_state.get_current_picker, vim.api.nvim_get_current_buf())
		return ok and value or nil
	end
	codex.sessions(true)
	wait(function()
		return picker() and picker().prompt_title:find("Codex sessions", 1, true)
	end, "session picker")
	wait(function()
		return picker().manager and picker().manager:num_results() == 2
	end, "session pagination")
	actions.select_default(vim.api.nvim_get_current_buf())
	ready()

	local project = vim.fn.tempname()
	vim.fn.mkdir(project .. "/src", "p")
	vim.fn.mkdir(project .. "/.git", "p")
	vim.fn.writefile({ "ignored.txt" }, project .. "/.gitignore")
	vim.fn.writefile({ "hello" }, project .. "/src/file with spaces.lua")
	vim.fn.writefile({ "ignored" }, project .. "/ignored.txt")
	vim.cmd.cd(project)
	codex.resume("files-session") -- Restart inherits the new project working directory.
	ready()
	codex.files()
	wait(function()
		return picker() and picker().prompt_title:find("Codex files", 1, true)
	end, "file picker")
	wait(function()
		return picker().manager and picker().manager:num_results() >= 3
	end, "file results")
	local selected = {}
	for entry in picker().manager:iter() do
		assert(entry.value ~= "ignored.txt", "Picker included ignored file")
		if entry.value == "src/" or entry.value == "src/file with spaces.lua" then
			table.insert(selected, entry)
		end
	end
	assert(#selected == 2, "Missing file/directory entries")
	picker().get_multi_selection = function()
		return selected
	end
	actions.select_default(vim.api.nvim_get_current_buf())
	assert(text("prompt"):find(project .. "/src/file with spaces.lua", 1, true))
	assert(text("prompt"):find('"' .. project .. '/src/"', 1, true))

	-- Requests are queued; resolved dialogs cannot submit a stale answer.
	local replies = {}
	local queue = require("custom.codex.requests").new(function(id, result)
		table.insert(replies, { id = id, result = result })
		return true
	end, function() end, function() end)
	for i = 1, 2 do
		queue:add({ id = i, method = "item/commandExecution/requestApproval", params = { command = "echo test" } })
	end
	local stale
	for _, mapping in ipairs(vim.api.nvim_buf_get_keymap(0, "n")) do
		if mapping.lhs == "a" then
			stale = mapping.callback
		end
	end
	queue:resolve(1)
	stale()
	assert(#replies == 0, "Resolved request accepted a stale action")
	vim.wait(70)
	press("d")
	assert(#replies == 1 and replies[1].id == 2 and replies[1].result.decision == "decline")
	queue:clear()
	print("PASS: streams, history, models, approvals, questions, interruption, failures, drafts, Telescope")
end

local ok, err = xpcall(run, debug.traceback)
if not ok then
	io.stderr:write(err .. "\n")
	vim.cmd("cquit 1")
else
	vim.cmd("qa!")
end
