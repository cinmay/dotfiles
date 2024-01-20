return {
  {
    "zbirenbaum/copilot.lua",
    opts = {
      suggestion = {
        enabled = true,
        auto_trigger = true,
        keymap = {
          accept = "<C-CR>",
          next = "<C-y>",
          prev = "<C-u>",
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
