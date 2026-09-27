local M = {}

-- Claude Code stores each session as JSON lines in <config>/projects/<project>/<id>.jsonl
-- and registers running processes in <config>/sessions/<pid>.json. Both are internal
-- formats (checked with Claude Code 2.1.283); only the fields used below are relied on.

local function config_dir()
	return vim.env.CLAUDE_CONFIG_DIR or vim.fs.joinpath(vim.env.HOME, ".claude")
end

local function decode(line)
	local ok, entry = pcall(vim.json.decode, line, { luanil = { object = true, array = true } })
	return ok and type(entry) == "table" and entry or nil
end

-- Typed prompts carry `promptSource`; slash-command echoes, their output, and task
-- notifications are stored as user entries too but are not part of the conversation.
function M.prompt_text(entry)
	if entry.type ~= "user" or entry.isMeta or not entry.promptSource then
		return nil
	end
	if entry.origin and entry.origin.kind ~= "human" then
		return nil
	end
	local content = entry.message.content
	if type(content) == "string" then
		return content
	end
	local parts = {}
	for _, block in ipairs(content or {}) do
		if block.type == "text" then
			table.insert(parts, block.text)
		end
	end
	return #parts > 0 and table.concat(parts, "\n") or nil
end

local function summary(path)
	local title, prompt, cwd
	for _, line in ipairs(vim.fn.readfile(path)) do
		-- Decode only the lines that matter; sessions can be megabytes of tool output.
		if line:find('"type":"ai-title"', 1, true) then
			title = (decode(line) or {}).aiTitle or title
		elseif not prompt and line:find('"type":"user"', 1, true) then
			local entry = decode(line)
			if entry then
				cwd = cwd or entry.cwd
				prompt = M.prompt_text(entry)
			end
		end
	end
	if not prompt then
		return nil -- Opened but never used.
	end
	return {
		id = vim.fn.fnamemodify(path, ":t:r"),
		title = title or prompt:match("[^\n]*"),
		cwd = cwd,
		updated = vim.uv.fs_stat(path).mtime.sec,
	}
end

-- Sessions for one project directory, or for all projects when cwd is nil. Newest first.
function M.list(cwd)
	local projects = vim.fs.joinpath(config_dir(), "projects")
	local dirs = cwd and { vim.fs.joinpath(projects, (cwd:gsub("[^%w]", "-"))) }
		or vim.fn.glob(projects .. "/*", false, true)
	local sessions = {}
	for _, dir in ipairs(dirs) do
		for _, path in ipairs(vim.fn.glob(dir .. "/*.jsonl", false, true)) do
			local session = summary(path)
			if session then
				table.insert(sessions, session)
			end
		end
	end
	table.sort(sessions, function(a, b)
		return a.updated > b.updated
	end)
	return sessions
end

-- The conversation as shown in the CLI: the chain of parents from the latest message,
-- so turns abandoned by a rewind stay hidden.
function M.read(id)
	if not id:match("^[%w-]+$") then
		return nil, "Invalid session id: " .. id
	end
	local path = vim.fn.glob(vim.fs.joinpath(config_dir(), "projects") .. "/*/" .. id .. ".jsonl", false, true)[1]
	if not path then
		return nil, "Session not found: " .. id
	end
	local by_uuid, latest, title = {}, nil, nil
	for _, line in ipairs(vim.fn.readfile(path)) do
		local entry = decode(line)
		if entry and entry.type == "ai-title" then
			title = entry.aiTitle
		elseif entry and entry.uuid then
			by_uuid[entry.uuid] = entry
			if entry.type == "user" or entry.type == "assistant" then
				latest = entry
			end
		end
	end
	local chain, seen = {}, {}
	local entry = latest
	while entry and not seen[entry] do
		seen[entry] = true
		table.insert(chain, entry)
		entry = by_uuid[entry.parentUuid]
	end
	local session = { id = id, title = title, entries = {} }
	for i = #chain, 1, -1 do
		entry = chain[i]
		table.insert(session.entries, entry)
		session.cwd = entry.cwd or session.cwd
		-- Synthetic messages (such as API errors) name a model like "<synthetic>".
		if entry.type == "assistant" and not (entry.message.model or "<"):find("^<") then
			session.model, session.effort = entry.message.model, entry.effort or session.effort
		end
	end
	return session
end

-- The pid of another live Claude process that has this session open, if any.
function M.running(id, own_pid)
	for _, path in ipairs(vim.fn.glob(vim.fs.joinpath(config_dir(), "sessions") .. "/*.json", false, true)) do
		local ok, lines = pcall(vim.fn.readfile, path)
		local info = ok and decode(table.concat(lines, "\n"))
		if info and info.sessionId == id and info.pid ~= own_pid and vim.uv.kill(info.pid, 0) == 0 then
			return info.pid
		end
	end
end

return M
