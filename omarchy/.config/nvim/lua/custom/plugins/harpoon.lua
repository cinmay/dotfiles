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
					local codex = require("custom.codex")
					local id = item.value:match("^codex://(.+)$")
					if id then
						codex.select_bookmark(id)
					else
						codex.hide()
						defaults.select(item, list, options)
					end
				end,
				display = function(item)
					if item.value:match("^codex://") then
						local title = (item.context.title or "Conversation"):gsub("%c", " ")
						return "Codex: " .. title .. " [" .. item.value .. "]"
					end
					return defaults.display(item)
				end,
				create_list_item = function(config, name)
					-- Preserve conversation identity when editing a title in Harpoon's menu.
					local title, value
					if name then
						title, value = name:match("^Codex: (.-) %[(codex://[^%]]+)%]$")
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
					local codex = require("custom.codex")
					local list = require("harpoon"):list()
					if codex.is_buffer() then
						local item = codex.bookmark()
						if item then
							list:add(item)
						end
					else
						list:add()
					end
				end,
				desc = "Harpoon File / Codex Conversation",
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
