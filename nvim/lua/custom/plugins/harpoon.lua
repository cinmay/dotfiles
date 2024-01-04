return{
        "ThePrimeagen/harpoon",
	branch = "harpoon2",
	config = function()
		local harpoon = require("harpoon")
		---@diagnostic disable-next-line: missing-parameter
		harpoon:setup()
		local function map(lhs, rhs, opts)
                vim.keymap.set("n", lhs, rhs, opts or {})
		end
		map("<c-h>", function() harpoon:list():append() end)
		map("<c-m>", function() harpoon.ui:toggle_quick_menu(harpoon:list()) end)
		map("<c-n>", function() harpoon:list():select(1) end)
		map("<c-e>", function() harpoon:list():select(2) end)
		map("<c-i>", function() harpoon:list():select(3) end)
		map("<c-o>", function() harpoon:list():select(4) end)
	end,
}
