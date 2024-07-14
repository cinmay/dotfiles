return {
	"nvim-neo-tree/neo-tree.nvim",
	branch = "v3.x",
	dependencies = {
		"nvim-lua/plenary.nvim",
		"nvim-tree/nvim-web-devicons",
		"MunifTanjim/nui.nvim",
	},
	config = function()
		require("neo-tree").setup({
			close_if_last_window = true,
			sources = {
				"filesystem",
				"git_status",
				"buffers",
				"document_symbols", -- EXPERIMENTAL
			},
			buffers = {
				follow_current_file = {
					enabled = true }
			},
			filesystem = {
				bind_to_cwd = true,
				follow_current_file = {
					leave_dirs_open = true,
					enabled = true,
				},
				filtered_items = {
					visible = true,
					show_hidden_count = true,
					hide_dotfiles = false,
				},
				use_libuv_file_watcher = true,
			},
		})

		vim.api.nvim_set_keymap("n", "<leader>tf", ":Neotree filesystem toggle<CR>",
			{ desc = "Toggle Neotree", silent = true })
	end,
}
