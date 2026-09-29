local M = {}

-- Views for `can_use_tool` requests, shown in place of the prompt. Each action
-- either answers with `respond(response)` or updates the request and calls
-- `refresh()` to show its next step (the next question).

local function allow(input)
	return { behavior = "allow", updatedInput = input }
end

local function deny(message)
	return { behavior = "deny", message = message }
end

local function split(text)
	return vim.split(text or "", "\n", { plain = true })
end

local function question_view(state)
	local progress = state.progress
	local question = state.questions[progress.index]
	local lines = { "**" .. (question.header or "Question") .. "**", "" }
	vim.list_extend(lines, split(question.question))
	local actions = {}

	local function answer(value, respond, refresh)
		progress.answers[question.question] = value
		progress.index = progress.index + 1
		progress.selected = {}
		if progress.index > #state.questions then
			local updated = vim.deepcopy(state.original)
			updated.answers = progress.answers
			respond(allow(updated))
		else
			refresh()
		end
	end

	for i, option in ipairs(question.options or {}) do
		local marker = question.multiSelect and (progress.selected[i] and "[x] " or "[ ] ") or ""
		local label = marker .. option.label .. (option.description and " — " .. option.description or "")
		table.insert(actions, {
			key = tostring(i),
			label = label,
			run = function(respond, refresh)
				if question.multiSelect then
					progress.selected[i] = not progress.selected[i] or nil
					refresh()
				else
					answer(option.label, respond, refresh)
				end
			end,
		})
	end
	table.insert(actions, {
		key = tostring(#actions + 1),
		label = "Other — type an answer",
		run = function(respond, refresh)
			vim.ui.input({ prompt = question.question .. " " }, function(value)
				if value and value:match("%S") then
					answer(value, respond, refresh)
				end
			end)
		end,
	})
	if question.multiSelect then
		table.insert(actions, {
			key = "<CR>",
			label = "Submit the selected options",
			run = function(respond, refresh)
				local labels = {}
				for i, option in ipairs(question.options) do
					if progress.selected[i] then
						table.insert(labels, option.label)
					end
				end
				if #labels > 0 then
					answer(table.concat(labels, ", "), respond, refresh)
				end
			end,
		})
	end
	return {
		title = "Claude asks (" .. progress.index .. "/" .. #state.questions .. ")",
		lines = lines,
		actions = actions,
	}
end

function M.view(request)
	local tool, input = request.tool_name, request.input or {}
	if tool == "AskUserQuestion" then
		-- Keep answering state on the request so a hidden chat resumes where it left off.
		request.question_state = request.question_state
			or { questions = input.questions, original = input, progress = { index = 1, answers = {}, selected = {} } }
		return question_view(request.question_state)
	end
	if tool == "ExitPlanMode" then
		return {
			title = "Claude's plan is ready",
			lines = split(input.plan),
			actions = {
				{
					key = "1",
					label = "Approve the plan and start",
					run = function(respond)
						respond(allow(input))
					end,
				},
				{
					key = "2",
					label = "Keep planning — then send your feedback as a prompt",
					run = function(respond)
						respond(deny("The user wants to keep planning. Wait for their feedback."))
					end,
				},
			},
		}
	end
	local lines = { "**" .. (request.display_name or tool) .. "**", "" }
	if request.description then
		vim.list_extend(lines, split(request.description))
		table.insert(lines, "")
	end
	if input.command then
		vim.list_extend(lines, { "```sh" })
		vim.list_extend(lines, split(input.command))
		table.insert(lines, "```")
	elseif input.file_path then
		table.insert(lines, "File: " .. input.file_path)
	else
		vim.list_extend(lines, split(vim.inspect(input)))
	end
	if request.blocked_path then
		table.insert(lines, "Outside allowed paths: " .. request.blocked_path)
	end
	return {
		title = "Claude asks permission",
		lines = lines,
		actions = {
			{
				key = "1",
				label = "Allow once",
				run = function(respond)
					respond(allow(input))
				end,
			},
			{
				key = "2",
				label = "Deny",
				run = function(respond)
					respond(deny("The user declined this action."))
				end,
			},
		},
	}
end

return M
