local M = {}

function M.new(reply, find_item, changed)
	local requests = { queue = {} }
	local win

	local function close()
		if win and vim.api.nvim_win_is_valid(win) then
			vim.api.nvim_win_close(win, true)
		end
		win = nil
	end

	function requests:resolve(id)
		for i, request in ipairs(self.queue) do
			if request.id == id then
				request.resolved = true
				table.remove(self.queue, i)
				if i == 1 then
					local was_visible = win and vim.api.nvim_win_is_valid(win)
					close()
					if was_visible then
						vim.schedule(function()
							self:show()
						end)
					end
				end
				changed()
				return
			end
		end
	end

	function requests:clear()
		for _, request in ipairs(self.queue) do
			request.resolved = true
		end
		self.queue = {}
		close()
		changed()
	end

	function requests:show()
		if win and vim.api.nvim_win_is_valid(win) then
			vim.api.nvim_set_current_win(win)
			return
		end
		local request = self.queue[1]
		if not request then
			return
		end
		local p = request.params
		local lines =
			{ p.reason or "Codex needs your response.", "", "Directory: " .. (p.cwd or "(session directory)") }
		local actions = {}
		local function finish(result)
			if not request.resolved and reply(request.id, result) then
				self:resolve(request.id)
			end
		end
		local function action(key, label, callback)
			table.insert(actions, { key = key, label = label, callback = callback })
		end
		local method = request.method
		if method == "item/commandExecution/requestApproval" or method == "item/fileChange/requestApproval" then
			if p.networkApprovalContext then
				table.insert(lines, "Network access: " .. vim.json.encode(p.networkApprovalContext))
			elseif method == "item/commandExecution/requestApproval" then
				local item = find_item(p.turnId, p.itemId) or {}
				table.insert(lines, "Command: " .. (p.command or item.command or "(not supplied)"))
			else
				if p.grantRoot then
					table.insert(lines, "Requested write root: " .. p.grantRoot)
				end
				local item = find_item(p.turnId, p.itemId) or {}
				for _, change in ipairs(item.changes or {}) do
					table.insert(lines, "\nFile: " .. change.path)
					table.insert(lines, change.diff or "(diff not supplied)")
				end
			end
			if p.additionalPermissions then
				table.insert(lines, "Permissions: " .. vim.inspect(p.additionalPermissions))
			end
			local allowed = p.availableDecisions or { "accept", "acceptForSession", "decline", "cancel" }
			for _, choice in ipairs({
				{ "a", "Allow once", "accept" },
				{ "s", "Allow for session", "acceptForSession" },
				{ "d", "Decline", "decline" },
				{ "c", "Cancel turn", "cancel" },
			}) do
				if vim.tbl_contains(allowed, choice[3]) then
					action(choice[1], choice[2], function()
						finish({ decision = choice[3] })
					end)
				end
			end
		elseif method == "item/permissions/requestApproval" then
			table.insert(lines, "Requested permissions:\n" .. vim.inspect(p.permissions))
			local permissions = vim.empty_dict()
			permissions.network = p.permissions.network
			permissions.fileSystem = p.permissions.fileSystem
			action("a", "Allow for this turn", function()
				finish({ permissions = permissions, scope = "turn" })
			end)
			action("s", "Allow for session", function()
				finish({ permissions = permissions, scope = "session" })
			end)
			action("d", "Decline", function()
				finish({ permissions = vim.empty_dict(), scope = "turn" })
			end)
		elseif method == "item/tool/requestUserInput" then
			for _, question in ipairs(p.questions) do
				table.insert(lines, "\n" .. question.question)
				for _, option in ipairs(question.options or {}) do
					table.insert(lines, "- " .. option.label .. ": " .. (option.description or ""))
				end
			end
			action("a", "Answer questions", function()
				local answers = vim.empty_dict()
				local function ask(index)
					if request.resolved then
						return
					end
					local question = p.questions[index]
					if not question then
						finish({ answers = answers })
						return
					end
					local function answer(value)
						if value == nil or request.resolved then
							return
						end
						answers[question.id] = { answers = { value } }
						ask(index + 1)
					end
					local function free_text()
						if question.isSecret then
							local ok, value = pcall(vim.fn.inputsecret, question.question .. ": ")
							if ok then
								answer(value)
							end
						else
							vim.ui.input({ prompt = question.question .. ": " }, answer)
						end
					end
					if question.options and #question.options > 0 then
						local choices = vim.deepcopy(question.options)
						if question.isOther then
							table.insert(choices, { label = "Write an answer…", free_text = true })
						end
						vim.ui.select(choices, {
							prompt = question.question,
							format_item = function(value)
								return value.label .. (value.description and " — " .. value.description or "")
							end,
						}, function(choice)
							if not choice or request.resolved then
								return
							end
							if choice.free_text then
								free_text()
							else
								answer(choice.label)
							end
						end)
					else
						free_text()
					end
				end
				ask(1)
			end)
		end
		table.insert(lines, "")
		for _, entry in ipairs(actions) do
			table.insert(lines, "[" .. entry.key .. "] " .. entry.label)
		end
		table.insert(lines, "[Esc] Hide — reopen with <leader>ap")
		local buf = vim.api.nvim_create_buf(false, true)
		vim.bo[buf].bufhidden = "wipe"
		vim.bo[buf].filetype = "markdown"
		vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(table.concat(lines, "\n"), "\n", { plain = true }))
		vim.bo[buf].modifiable = false
		local width = math.max(20, math.min(100, vim.o.columns - 6))
		local height = math.max(3, math.min(vim.api.nvim_buf_line_count(buf), vim.o.lines - 8))
		win = vim.api.nvim_open_win(buf, true, {
			relative = "editor",
			style = "minimal",
			border = "rounded",
			zindex = 70,
			width = width,
			height = height,
			row = math.max(0, math.floor((vim.o.lines - height) / 2) - 1),
			col = math.max(0, math.floor((vim.o.columns - width) / 2)),
			title = " Codex · Response required (" .. #self.queue .. ") ",
			title_pos = "center",
		})
		vim.wo[win].wrap = true
		vim.cmd.stopinsert()
		for _, entry in ipairs(actions) do
			vim.keymap.set("n", entry.key, entry.callback, { buffer = buf, nowait = true })
		end
		vim.keymap.set("n", "<Esc>", close, { buffer = buf, nowait = true })
	end

	function requests:add(request)
		local supported = {
			["item/commandExecution/requestApproval"] = true,
			["item/fileChange/requestApproval"] = true,
			["item/permissions/requestApproval"] = true,
			["item/tool/requestUserInput"] = true,
		}
		if not supported[request.method] then
			reply(request.id, nil, { code = -32601, message = "Neovim does not support " .. request.method })
			vim.notify("Codex request not supported: " .. request.method, vim.log.levels.ERROR)
			return
		end
		table.insert(self.queue, request)
		changed()
		vim.notify("Codex needs your response · <leader>ap", vim.log.levels.INFO)
	end

	return requests
end

return M
