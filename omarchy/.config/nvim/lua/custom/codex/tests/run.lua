local source = debug.getinfo(1, "S").source:sub(2)
local tests = vim.fs.dirname(vim.fn.fnamemodify(source, ":p"))
local config = vim.fs.normalize(tests .. "/../../../../..")
vim.opt.rtp:append(config)
local plugin_data = vim.fn.stdpath("data")
for _, plugin in ipairs({ "plenary.nvim", "telescope.nvim", "harpoon" }) do
	vim.opt.rtp:append(plugin_data .. "/lazy/" .. plugin)
end
-- Exercise real Harpoon persistence without touching the user's bookmarks.
vim.env.XDG_DATA_HOME = vim.fn.tempname()
vim.fn.mkdir(vim.fn.stdpath("data"), "p")
vim.o.columns, vim.o.lines = 140, 50
local notifications = {}
vim.notify = function(message)
	table.insert(notifications, message)
end
local codex = require("custom.codex")
codex.setup({ command = tests .. "/fake_server.py", done_sound = "" })
assert(vim.api.nvim_get_commands({ builtin = false }).Codex == nil, "The toggle command should not exist")

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
	return vim.wo[window("history")].winbar
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
	end, "pending approval")
	assert(vim.api.nvim_get_current_buf() == buffer("prompt"), "Approval stole focus")
	codex.approval()
end

local function run()
	local code_buf = vim.api.nvim_get_current_buf()
	vim.api.nvim_buf_set_name(code_buf, vim.fn.tempname() .. ".lua")
	vim.api.nvim_buf_set_lines(code_buf, 0, -1, false, { "-- unsaved code", "local value = 1", "return value" })
	vim.api.nvim_win_set_cursor(0, { 2, 4 })
	vim.wo.winbar, vim.wo.wrap = "Original code winbar", false
	local harpoon_spec = require("custom.plugins.harpoon")
	local harpoon = require("harpoon")
	harpoon:setup(harpoon_spec.opts())
	local harpoon_keys = harpoon_spec.keys()
	for _, key in ipairs(harpoon_keys) do
		vim.keymap.set("n", key[1], key[2])
	end
	harpoon_keys[1][2]()
	codex.open()
	ready()
	assert(has_title("model-a · high"))
	assert(not vim.bo[buffer("history")].modifiable)
	assert(vim.bo[buffer("history")].buflisted and vim.bo[buffer("prompt")].buflisted)
	assert(#vim.api.nvim_list_tabpages() == 1 and #vim.api.nvim_list_wins() == 2)
	assert(vim.api.nvim_win_get_config(window("history")).relative == "")
	assert(vim.api.nvim_win_get_config(window("prompt")).relative == "")
	assert(vim.api.nvim_win_get_position(window("history"))[1] < vim.api.nvim_win_get_position(window("prompt"))[1])
	assert(vim.api.nvim_win_get_width(window("history")) == vim.api.nvim_win_get_width(window("prompt")))
	assert(vim.api.nvim_win_get_height(window("prompt")) == 18)
	assert(vim.bo[buffer("history")].buftype == "nofile")
	assert(vim.bo[buffer("prompt")].buftype == "")
	assert(not vim.bo[buffer("prompt")].swapfile)
	for _, name in ipairs({ "history", "prompt" }) do
		for _, mode in ipairs({ "n", "i" }) do
			for _, mapping in ipairs(vim.api.nvim_buf_get_keymap(buffer(name), mode)) do
				assert(
					mapping.lhs ~= "<C-S>"
						and mapping.lhs ~= "<C-s>"
						and mapping.lhs ~= "<Esc>"
						and mapping.lhs ~= "<Tab>",
					"Unexpected key override"
				)
			end
		end
	end
	prompt("Draft survives :q")
	vim.cmd.quit()
	assert(#vim.api.nvim_list_wins() == 1 and vim.api.nvim_get_current_buf() == code_buf)
	assert(vim.bo[code_buf].modified and vim.wo.winbar == "Original code winbar" and not vim.wo.wrap)
	assert(vim.deep_equal(vim.api.nvim_win_get_cursor(0), { 2, 4 }))
	codex.open()
	assert(text("prompt") == "Draft survives :q")
	vim.api.nvim_set_current_win(window("history"))
	vim.api.nvim_win_set_cursor(0, { 3, 2 })
	vim.cmd.quit()
	assert(#vim.api.nvim_list_wins() == 1 and vim.api.nvim_get_current_buf() == code_buf)
	codex.open()
	assert(vim.deep_equal(vim.api.nvim_win_get_cursor(window("history")), { 3, 2 }))
	codex.hide()
	assert(#vim.api.nvim_list_wins() == 1 and vim.api.nvim_get_current_buf() == code_buf)
	codex.open()
	prompt("")
	send("stream")
	completed()
	assert(text("prompt") == "")
	assert(text("history"):find("Høllo — final authoritative text", 1, true))
	assert(not text("history"):find("DO NOT SHOW", 1, true))
	assert(text("history"):find("Ran echo page", 1, true))
	assert(not text("history"):find("page source that should stay hidden", 1, true))
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
	vim.cmd.quit()
	assert(window("history") == -1)
	assert(vim.api.nvim_get_current_buf() == code_buf)
	codex.open()
	assert(has_title("Running"), "Quitting the view cancelled the turn")
	codex.interrupt()
	wait(function()
		return has_title("interrupted")
	end, "interrupt")

	prompt("Draft for the first conversation")
	codex.resume("external")
	ready()
	assert(text("history"):find("From the desktop app", 1, true))
	assert(text("history"):find("External history: blåbær", 1, true))
	assert(not text("history"):find("final authoritative text", 1, true))
	assert(text("prompt") == "")
	prompt("Draft for the second conversation")
	codex.resume("new-session")
	ready()
	assert(text("prompt") == "Draft for the first conversation")
	codex.resume("external")
	ready()
	assert(text("prompt") == "Draft for the second conversation")
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
	require("telescope").setup({ defaults = { initial_mode = "normal", layout_config = { width = 0.8, height = 0.7 } } })
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

	-- Real Harpoon list, menu, encoding, and existing shortcuts use session IDs.
	local bookmarks = harpoon:list()
	bookmarks:clear()
	codex.hide()
	vim.api.nvim_set_current_buf(code_buf)
	harpoon_keys[1][2]()
	codex.open()
	prompt("Bookmarked draft")
	harpoon_keys[1][2]()
	vim.api.nvim_set_current_win(window("history"))
	harpoon_keys[1][2]()
	assert(bookmarks:length() == 2, "History/prompt created duplicate bookmarks")
	assert(bookmarks.items[2].value == "codex://files-session")
	local file_item = vim.deepcopy(bookmarks.items[1])
	bookmarks:add({ value = "codex://external", context = { title = "Other conversation" } })
	assert(bookmarks:display()[3]:find("Other conversation", 1, true))
	-- Ctrl-S must still select Harpoon slot 3, even inside Codex.
	vim.fn.maparg("<C-s>", "n", false, true).callback()
	ready()
	assert(text("history"):find("Session: external", 1, true))
	bookmarks:select(2)
	ready()
	assert(text("prompt") == "Bookmarked draft")
	bookmarks:select(1)
	assert(#vim.api.nvim_list_wins() == 1 and vim.api.nvim_get_current_buf() == code_buf)
	harpoon.ui:toggle_quick_menu(bookmarks)
	vim.api.nvim_win_set_cursor(0, { 2, 0 })
	harpoon.ui:select_menu_item()
	assert(text("history"):find("Session: files-session", 1, true))
	assert(#vim.api.nvim_list_wins() == 2)
	assert(text("prompt") == "Bookmarked draft")
	local displayed = bookmarks:display()
	bookmarks:resolve_displayed(
		{ displayed[1], displayed[2]:gsub("^Codex:.- %[", "Codex: Renamed ["), displayed[3] },
		3
	)
	assert(bookmarks.items[2].value == "codex://files-session" and bookmarks.items[2].context.title == "Renamed")
	displayed = bookmarks:display()
	bookmarks:resolve_displayed({ displayed[3], displayed[2], displayed[1] }, 3)
	assert(bookmarks.items[1].value == "codex://external" and bookmarks.items[3].value == file_item.value)
	local decoded = require("harpoon.list").decode(bookmarks.config, bookmarks.name, bookmarks:encode())
	assert(decoded.items[1].value == "codex://external" and decoded.items[1].context.title == "Other conversation")
	decoded:select(1)
	ready()
	assert(text("history"):find("Session: external", 1, true))
	harpoon:sync()
	local persisted = vim.fn.stdpath("data") .. "/harpoon/" .. vim.fn.sha256(vim.uv.cwd()) .. ".json"
	assert(table.concat(vim.fn.readfile(persisted), "\n"):find("codex://external", 1, true))

	-- Ordinary :buffer and Telescope file selection both leave a single code window.
	vim.cmd.buffer(code_buf)
	assert(#vim.api.nvim_list_wins() == 1 and vim.api.nvim_get_current_buf() == code_buf)
	codex.open()
	require("telescope.builtin").find_files({ cwd = project .. "/src" })
	wait(function()
		return picker()
			and picker().manager
			and picker().manager:num_results() == 1
			and action_state.get_selected_entry().value == "file with spaces.lua"
	end, "Telescope file navigation")
	actions.select_default(vim.api.nvim_get_current_buf())
	wait(function()
		return vim.api.nvim_buf_get_name(0):find("file with spaces.lua", 1, true) ~= nil
	end, "selected file")
	assert(#vim.api.nvim_list_wins() == 1, "Telescope left a Codex split beside code")
	local selected_code = vim.api.nvim_get_current_buf()
	codex.open()
	codex.hide()
	assert(vim.api.nvim_get_current_buf() == selected_code)
	codex.open()
	vim.cmd.close()
	vim.wait(70)
	assert(#vim.api.nvim_list_wins() == 1 and vim.api.nvim_get_current_buf() == selected_code)

	-- Requests are queued; resolved dialogs cannot submit a stale answer.
	local replies = {}
	local queue = require("custom.codex.requests").new(function(id, result)
		table.insert(replies, { id = id, result = result })
		return true
	end, function() end, function() end)
	for i = 1, 2 do
		queue:add({ id = i, method = "item/commandExecution/requestApproval", params = { command = "echo test" } })
	end
	queue:show()
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
	print(
		"PASS: streams, history, models, approvals, questions, interruption, failures, drafts, native splits/:q, Telescope, Harpoon"
	)
end

local ok, err = xpcall(run, debug.traceback)
if not ok then
	io.stderr:write(err .. "\n")
	vim.cmd("cquit 1")
else
	vim.cmd("qa!")
end
