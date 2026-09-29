return {
	"ThePrimeagen/harpoon",
	branch = "harpoon2",
	opts = function()
		local defaults = require("harpoon.config").get_default_config().default
		return {
			menu = { width = vim.api.nvim_win_get_width(0) - 4 },
			settings = { save_on_toggle = false },
			default = {
				select = function(item, list, options)
					if not item then
						return
					end
					local codex, claude = require("custom.codex"), require("custom.claude")
					local codex_id = item.value:match("^codex://(.+)$")
					local claude_id = item.value:match("^claude://(.+)$")
					if codex_id then
						codex.select_bookmark(codex_id)
					elseif claude_id then
						claude.select_bookmark(claude_id)
					else
						codex.hide()
						claude.hide()
						defaults.select(item, list, options)
					end
				end,
				display = function(item)
					local agent = item.value:match("^codex://") and "Codex" or item.value:match("^claude://") and "Claude"
					if agent then
						local title = (item.context.title or "Conversation"):gsub("%c", " ")
						return agent .. ": " .. title .. " [" .. item.value .. "]"
					end
					return defaults.display(item)
				end,
				create_list_item = function(config, name)
					-- Preserve conversation identity when editing a title in Harpoon's menu.
					local title, value
					if name then
						title, value = name:match("^Codex: (.-) %[(codex://[^%]]+)%]$")
						if not value then
							title, value = name:match("^Claude: (.-) %[(claude://[^%]]+)%]$")
						end
					end
					if value then
						return { value = value, context = { title = title } }
					end
					return defaults.create_list_item(config, name)
				end,
			},
		}
	end,
	keys = function()
		local keys = {
			{
				"<c-h>",
				function()
					local codex, claude = require("custom.codex"), require("custom.claude")
					local list = require("harpoon"):list()
					local chat = codex.is_buffer() and codex or claude.is_buffer() and claude
					if chat then
						local item = chat.bookmark()
						if item then
							list:add(item)
						end
					else
						list:add()
					end
				end,
				desc = "Harpoon File / Codex or Claude Conversation",
			},
			{
				"<c-m>",
				function()
					local harpoon = require("harpoon")
					harpoon.ui:toggle_quick_menu(harpoon:list())
				end,
				desc = "Harpoon Quick Menu",
			},
			{
				"<c-a>",
				function()
					require("harpoon"):list():select(1)
				end,
				desc = "Harpoon to File 1",
			},
			{
				"<c-r>",
				function()
					require("harpoon"):list():select(2)
				end,
				desc = "Harpoon to File 2",
			},
			{
				"<c-s>",
				function()
					require("harpoon"):list():select(3)
				end,
				desc = "Harpoon to File 3",
			},
			{
				"<c-t>",
				function()
					require("harpoon"):list():select(4)
				end,
				desc = "Harpoon to File 4",
			},
			{
				"<c-g>",
				function()
					require("harpoon"):list():select(5)
				end,
				desc = "Harpoon to File 5",
			},
		}

		-- for i = 1, 5 do
		-- 	table.insert(keys, {
		-- 		"<leader>" .. i,
		-- 		function()
		-- 			require("harpoon"):list():select(i)
		-- 		end,
		-- 		desc = "Harpoon to File " .. i,
		-- 	})
		-- end

		return keys
	end,
}
