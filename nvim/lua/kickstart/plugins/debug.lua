return {
  {
    "mfussenegger/nvim-dap",
    dependencies = {
      "leoluz/nvim-dap-go",
      "rcarriga/nvim-dap-ui",
      "theHamsta/nvim-dap-virtual-text",
      "nvim-neotest/nvim-nio",
      "williamboman/mason.nvim",
    },
    config = function()
      local dap = require "dap"
      local ui = require "dapui"

      require("dapui").setup()
      require("dap-go").setup()

      -- disconnect = "",
      vim.keymap.set("n", "<leader>dD", dap.disconnect, { desc = 'Disconnect' })

      -- pause = "",
      vim.keymap.set("n", "<leader>dP", dap.pause, { desc = 'Pause' })


      -- play = "",
      -- vim.keymap.set("n", "<leader>dp", dap.play, { desc = 'Play' })

      -- run_last = "",
      vim.keymap.set("n", "<leader>dl", dap.run_last, { desc = 'Run last' })

      -- step_back = "",

      -- step_into = "",
      vim.keymap.set("n", "<leader>di", dap.step_into, { desc = 'Step into' })
      vim.keymap.set("n", ",i", dap.step_into, { desc = 'Step into' })

      -- step_out = "",

      -- step_over = "",
      vim.keymap.set("n", "<leader>do", dap.step_over, { desc = 'Step over' })
      vim.keymap.set("n", ",o", dap.step_over, { desc = 'Step over' })

      -- terminate = ""
      vim.keymap.set("n", "<leader>dt", dap.terminate, { desc = 'Terminate' })
      vim.keymap.set("n", ",t", dap.terminate, { desc = 'Terminate' })

      vim.keymap.set("n", "<leader>db", dap.toggle_breakpoint, { desc = 'Toggle breakpoint' })
      vim.keymap.set("n", ",b", dap.toggle_breakpoint, { desc = 'Toggle breakpoint' })

      vim.keymap.set("n", "<leader>dg", dap.run_to_cursor, { desc = 'Run to cursor' })
      vim.keymap.set("n", "<leader>dc", dap.continue, { desc = 'Continue' })
      vim.keymap.set("n", ",c", dap.continue, { desc = 'Continue' })
      vim.keymap.set("n", "<leader>dr", dap.restart, { desc = 'Restart' })
      vim.keymap.set("n", ",r", dap.restart, { desc = 'Restart' })


      -- Tottle UI
      vim.keymap.set("n", "<leader>dx", function()
        require("dapui").toggle()
      end, { desc = 'Toggle UI' })

      -- Eval var under cursor
      vim.keymap.set("n", "<leader>du", function()
        require("dapui").eval(nil, { enter = true })
      end, { desc = 'Eval var under cursor' })

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
    end,
  },
}
