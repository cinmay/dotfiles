-- Copilot completes from the buffer it is in, and an empty chat prompt tells it
-- nothing about the conversation, so its suggestions there are generic. Copilot's
-- language server accepts extra context from the editor ("context providers"),
-- but copilot.lua has no way to pass it along. This wraps copilot.lua's completion
-- requests and adds the end of the chat history when completing in the prompt.
-- It relies on copilot.lua internals (copilot.api, copilot.client.utils), so a
-- copilot.lua update can break it silently: suggestions go generic again.
local M = {}

local provider_id = "claude-chat"
local registered_clients = {}

-- The server ignores a registered provider unless the settings name it as active.
-- copilot.lua sends its own settings when the client starts, so they are extended
-- here instead of set once in the plugin spec, where they would be overwritten.
local function register(client)
	if registered_clients[client.id] then
		return
	end
	registered_clients[client.id] = true
	client:request("context/registerProviders", {
		providers = { { id = provider_id, selector = { { language = "markdown" } } } },
	}, function() end)
	local configuration = require("copilot.client.utils").get_workspace_configurations()
	configuration.settings.github.copilot.advanced = { contextProviders = { provider_id } }
	client:notify("workspace/didChangeConfiguration", configuration)
end

local wrapped = false

-- context() returns the text Copilot should know about, or nil to send nothing.
-- Safe to call more than once; only the first call wraps the requests.
function M.provide(context)
	local ok, api = pcall(require, "copilot.api")
	if wrapped or not ok then
		return
	end
	wrapped = true
	for _, name in ipairs({ "get_completions", "get_completions_cycling" }) do
		local request = api[name]
		api[name] = function(client, params, callback)
			local text = context()
			if text then
				register(client)
				-- A trait, not a code snippet: in testing (server 1.393.0) Copilot used
				-- traits but dropped snippets, even ones with a file: URI.
				local trait = { name = "Conversation so far; the user is writing their next message", value = text }
				params.contextItems = { providers = { { id = provider_id, contextItems = { trait } } } }
			end
			return request(client, params, callback)
		end
	end
end

return M
