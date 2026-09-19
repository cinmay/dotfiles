local M = {}

-- App-server uses JSON lines, not Neovim's msgpack RPC transport.
function M.new(command, handlers)
	local client = { pending = {}, waiters = {}, next_id = 0, ready = false }
	local stderr = {}

	local function write(message)
		if not client.job then
			return false
		end
		local ok, bytes = pcall(vim.fn.chansend, client.job, vim.json.encode(message) .. "\n")
		return ok and bytes > 0
	end

	function client:request(method, params, callback)
		self.next_id = self.next_id + 1
		local id = self.next_id
		self.pending[id] = callback
		if not write({ id = id, method = method, params = params or vim.empty_dict() }) then
			self.pending[id] = nil
			callback(nil, "Could not send " .. method .. " to Codex")
			return
		end
		vim.defer_fn(function()
			if self.pending[id] then
				self.pending[id] = nil
				callback(nil, method .. " timed out; reopen the session before retrying")
			end
		end, 60000)
	end

	function client:reply(id, result, err)
		return write({ id = id, result = result, error = err })
	end

	local function dispatch(line)
		if line == "" then
			return
		end
		local ok, message = pcall(vim.json.decode, line, { luanil = { object = true, array = true } })
		if not ok or type(message) ~= "table" then
			vim.notify("Invalid JSON from Codex app-server", vim.log.levels.ERROR)
			return
		end
		if message.method then
			if message.id ~= nil then
				handlers.request(message)
			else
				handlers.notification(message.method, message.params or {})
			end
		elseif message.id ~= nil then
			local callback = client.pending[message.id]
			client.pending[message.id] = nil
			if callback then
				callback(message.result, message.error and message.error.message)
			end
		end
	end

	local function initialized(err)
		local waiters = client.waiters
		client.waiters = {}
		for _, callback in ipairs(waiters) do
			callback(err)
		end
	end

	function client:start(callback)
		if self.ready then
			callback()
			return
		end
		table.insert(self.waiters, callback)
		if self.job then
			return
		end
		stderr = {}
		local partial = ""
		local job = vim.fn.jobstart({ command, "app-server" }, {
			on_stdout = function(_, data)
				for i, chunk in ipairs(data) do
					if i == 1 then
						partial = partial .. chunk
					else
						dispatch(partial)
						partial = chunk
					end
				end
			end,
			on_stderr = function(_, data)
				for _, line in ipairs(data) do
					if line ~= "" then
						table.insert(stderr, line)
						if #stderr > 12 then
							table.remove(stderr, 1)
						end
					end
				end
			end,
			on_exit = function(_, code)
				self.job, self.ready = nil, false
				local err = "Codex app-server exited (" .. code .. ")"
				if #stderr > 0 then
					err = err .. "\n" .. table.concat(stderr, "\n")
				end
				local pending = self.pending
				self.pending = {}
				for _, done in pairs(pending) do
					done(nil, err)
				end
				initialized(err)
				if self.restarting then
					local restart = self.restarting
					self.restarting = nil
					self:start(restart)
				else
					handlers.exit(err)
				end
			end,
		})
		if job <= 0 then
			initialized("Could not start " .. command .. " app-server")
			return
		end
		self.job = job
		self:request("initialize", {
			clientInfo = { name = "neovim_codex", title = "Neovim", version = "1.0.0" },
			capabilities = { experimentalApi = true },
		}, function(_, err)
			if err then
				initialized(err)
				self:stop()
				return
			end
			self.ready = write({ method = "initialized" })
			if self.ready then
				initialized()
			else
				initialized("Could not initialize Codex")
			end
		end)
	end

	function client:stop()
		if self.job then
			vim.fn.jobstop(self.job)
		end
	end

	function client:restart(callback)
		if not self.job then
			self:start(callback)
			return
		end
		self.restarting = callback
		self:stop()
	end

	return client
end

return M
