return {
	"ThePrimeagen/harpoon",
	branch = "harpoon2",
	opts = {
		menu = {
			width = vim.api.nvim_win_get_width(0) - 4,
		},
		settings = {
			save_on_toggle = false,
		},
	},
	keys = function()
		local keys = {
			{
				"<c-h>",
				function()
					require("harpoon"):list():add()
				end,
				desc = "Harpoon File",
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
