return {
	{
		-- NOTE: Yes, you can install new plugins here!
		"mfussenegger/nvim-dap",
		-- NOTE: And you can specify dependencies as well
		dependencies = {
			-- Creates a beautiful debugger UI
			"rcarriga/nvim-dap-ui",

			-- Required dependency for nvim-dap-ui
			"nvim-neotest/nvim-nio",

			-- Installs the debug adapters for you
			"mason-org/mason.nvim",
			"jay-babu/mason-nvim-dap.nvim",

			-- Add your own debuggers here
			"leoluz/nvim-dap-go",

			"theHamsta/nvim-dap-virtual-text",
			"williamboman/mason.nvim",
		},
		config = function()
			local dap = require("dap")
			local dapui = require("dapui")

			require("dapui").setup()
			require("dap-go").setup()
			require("mason-nvim-dap").setup({
				-- Makes a best effort to setup the various debuggers with
				-- reasonable debug configurations
				automatic_installation = true,

				-- You can provide additional configuration to the handlers,
				-- see mason-nvim-dap README for more information
				handlers = {},

				-- You'll need to check that you have the required things installed
				-- online, please don't ask me how to install them :)
				ensure_installed = {
					-- Update this to ensure that you have the debuggers for the langs you want
					"delve",
				},
			})

			-- disconnect = "",
			vim.keymap.set("n", "<leader>dD", dap.disconnect, { desc = "Disconnect" })

			-- pause = "",
			vim.keymap.set("n", "<leader>dP", dap.pause, { desc = "Pause" })

			-- play = "",
			-- vim.keymap.set("n", "<leader>dp", dap.play, { desc = 'Play' })

			-- run_last = "",
			vim.keymap.set("n", "<leader>dl", dap.run_last, { desc = "Run last" })

			-- step_back = "",

			-- step_into = "",
			vim.keymap.set("n", "<leader>di", dap.step_into, { desc = "Step into" })
			vim.keymap.set("n", ",i", dap.step_into, { desc = "Step into" })

			-- step_out = "",

			-- step_over = "",
			vim.keymap.set("n", "<leader>do", dap.step_over, { desc = "Step over" })
			vim.keymap.set("n", ",o", dap.step_over, { desc = "Step over" })

			-- terminate = ""
			vim.keymap.set("n", "<leader>dt", dap.terminate, { desc = "Terminate" })
			vim.keymap.set("n", ",t", dap.terminate, { desc = "Terminate" })

			vim.keymap.set("n", "<leader>db", dap.toggle_breakpoint, { desc = "Toggle breakpoint" })
			vim.keymap.set("n", ",b", dap.toggle_breakpoint, { desc = "Toggle breakpoint" })

			vim.keymap.set("n", "<leader>dg", dap.run_to_cursor, { desc = "Run to cursor" })
			vim.keymap.set("n", "<leader>dc", dap.continue, { desc = "Continue" })
			vim.keymap.set("n", ",c", dap.continue, { desc = "Continue" })
			vim.keymap.set("n", "<leader>dr", dap.restart, { desc = "Restart" })
			vim.keymap.set("n", ",r", dap.restart, { desc = "Restart" })

			-- Tottle UI
			vim.keymap.set("n", "<leader>dx", function()
				require("dapui").toggle()
			end, { desc = "Toggle UI" })

			-- Eval var under cursor
			vim.keymap.set("n", "<leader>du", function()
				require("dapui").eval(nil, { enter = true })
			end, { desc = "Eval var under cursor" })

			dap.listeners.before.attach.dapui_config = function()
				ui.open()
			end
			dap.listeners.before.launch.dapui_config = function()
				ui.open()
			end
			dap.listeners.before.event_terminated.dapui_config = function()
				ui.close()
			end
			dap.listeners.before.event_exited.dapui_config = function()
				ui.close()
			end

			-- Dap UI setup
			-- For more information, see |:help nvim-dap-ui|
			-- dapui.setup({
			-- 	-- Set icons to characters that are more likely to work in every terminal.
			-- 	--    Feel free to remove or use ones that you like more! :)
			-- 	--    Don't feel like these are good choices.
			-- 	icons = { expanded = "▾", collapsed = "▸", current_frame = "*" },
			-- 	controls = {
			-- 		icons = {
			-- 			pause = "⏸",
			-- 			play = "▶",
			-- 			step_into = "⏎",
			-- 			step_over = "⏭",
			-- 			step_out = "⏮",
			-- 			step_back = "b",
			-- 			run_last = "▶▶",
			-- 			terminate = "⏹",
			-- 			disconnect = "⏏",
			-- 		},
			-- 	},
			-- })

			-- Change breakpoint icons
			-- vim.api.nvim_set_hl(0, 'DapBreak', { fg = '#e51400' })
			-- vim.api.nvim_set_hl(0, 'DapStop', { fg = '#ffcc00' })
			-- local breakpoint_icons = vim.g.have_nerd_font
			--     and { Breakpoint = '', BreakpointCondition = '', BreakpointRejected = '', LogPoint = '', Stopped = '' }
			--   or { Breakpoint = '●', BreakpointCondition = '⊜', BreakpointRejected = '⊘', LogPoint = '◆', Stopped = '⭔' }
			-- for type, icon in pairs(breakpoint_icons) do
			--   local tp = 'Dap' .. type
			--   local hl = (type == 'Stopped') and 'DapStop' or 'DapBreak'
			--   vim.fn.sign_define(tp, { text = icon, texthl = hl, numhl = hl })
			-- end

			dap.listeners.after.event_initialized["dapui_config"] = dapui.open
			dap.listeners.before.event_terminated["dapui_config"] = dapui.close
			dap.listeners.before.event_exited["dapui_config"] = dapui.close

			-- Install golang specific config
			require("dap-go").setup({
				delve = {
					-- On Windows delve must be run attached or it crashes.
					-- See https://github.com/leoluz/nvim-dap-go/blob/main/README.md#configuring
					detached = vim.fn.has("win32") == 0,
				},
			})
		end,
	},
}
