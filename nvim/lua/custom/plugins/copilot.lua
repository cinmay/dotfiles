return {
	{
		"zbirenbaum/copilot.lua",
		opts = {
			suggestion = {
				enabled = true,
				auto_trigger = true,
				keymap = {
					accept = "<C-e>",
					accept_word = "<A-e>",
					next = "<C-u>",
					prev = "<C-l>",
				},
			},
			panel = {
				enabled = true,
				auto_refresh = true
			},
			filetypes = { ["*"] = true },
		},
	},
}
