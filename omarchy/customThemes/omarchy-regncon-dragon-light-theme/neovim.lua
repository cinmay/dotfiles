return {
  {
    "bjarneo/aether.nvim",
    branch = "v3",
    name = "aether",
    priority = 1000,
    opts = {
      colors = {
        bg         = "#fefaf5",
        dark_bg    = "#bfbcb8",
        darker_bg  = "#7f7d7b",
        lighter_bg = "#fefbf6",

        fg         = "#141117",
        dark_fg    = "#0f0d11",
        light_fg   = "#37353a",
        bright_fg  = "#4f4d51",
        muted      = "#8f8b85",

        red        = "#95655e",
        yellow     = "#886546",
        orange     = "#a57c76",
        green      = "#57774a",
        cyan       = "#327a7a",
        blue       = "#7f6a85",
        purple     = "#9e597c",
        brown      = "#634a47",

        bright_red    = "#be877e",
        bright_yellow = "#b0885f",
        bright_green  = "#769d60",
        bright_cyan   = "#50a09f",
        bright_blue   = "#a58caf",
        bright_purple = "#c978a5",

        accent               = "#7f6a85",
        cursor               = "#141117",
        foreground           = "#141117",
        background           = "#fefaf5",
        selection             = "#fefbf6",
        selection_foreground = "#141117",
        selection_background = "#fefbf6",
      },
    },
  },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "aether",
    },
  },
}
