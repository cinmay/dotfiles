local M = {}

-- `claude -p` in stream-json mode speaks JSON lines: conversation messages plus
-- control requests in both directions. One process serves one session.
function M.new(command, opts, handlers)
	local process = { pending = {}, next_id = 0 }
	local stderr = {}

	local function write(message)
		if not process.job then
			return false
		end
		local ok, bytes = pcall(vim.fn.chansend, process.job, vim.json.encode(message) .. "\n")
		return ok and bytes > 0
	end

	function process:send(message)
		return write(message)
	end

	function process:control(subtype, fields, callback)
		self.next_id = self.next_id + 1
		local id = "nvim-" .. self.next_id
		self.pending[id] = callback
		local request = vim.tbl_extend("force", { subtype = subtype }, fields or {})
		if not write({ type = "control_request", request_id = id, request = request }) then
			self.pending[id] = nil
			callback(nil, "Could not send " .. subtype .. " to Claude")
			return
		end
		vim.defer_fn(function()
			if self.pending[id] then
				self.pending[id] = nil
				callback(nil, subtype .. " timed out; start a new chat before retrying")
			end
		end, 60000)
	end

	function process:respond(request_id, response)
		return write({
			type = "control_response",
			response = { subtype = "success", request_id = request_id, response = response },
		})
	end

	function process:reject(request_id, message)
		return write({
			type = "control_response",
			response = { subtype = "error", request_id = request_id, error = message },
		})
	end

	local function dispatch(line)
		if line == "" then
			return
		end
		local ok, message = pcall(vim.json.decode, line, { luanil = { object = true, array = true } })
		if not ok or type(message) ~= "table" then
			vim.notify("Invalid JSON from Claude", vim.log.levels.ERROR)
			return
		end
		if message.type == "control_response" then
			local response = message.response or {}
			local callback = process.pending[response.request_id]
			process.pending[response.request_id] = nil
			if callback then
				if response.subtype == "success" then
					callback(response.response or {})
				else
					callback(nil, response.error or "Claude rejected the request")
				end
			end
		elseif message.type == "control_request" then
			handlers.request(message)
		else
			handlers.message(message)
		end
	end

	function process:start()
		local partial = ""
		local job = vim.fn.jobstart(vim.list_extend({ command }, opts.args), {
			cwd = opts.cwd,
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
				self.job = nil
				local err = "Claude exited (" .. code .. ")"
				if #stderr > 0 then
					err = err .. "\n" .. table.concat(stderr, "\n")
				end
				local pending = self.pending
				self.pending = {}
				for _, done in pairs(pending) do
					done(nil, err)
				end
				if not self.stopping then
					handlers.exit(err)
				end
			end,
		})
		if job <= 0 then
			return "Could not start " .. command
		end
		self.job = job
	end

	function process:stop()
		self.stopping = true
		if self.job then
			vim.fn.jobstop(self.job)
		end
	end

	return process
end

return M
