return {
  {
    "bjarneo/aether.nvim",
    branch = "v3",
    name = "aether",
    priority = 1000,
    opts = {
      colors = {
        bg         = "#010112",
        dark_bg    = "#01010e",
        darker_bg  = "#010109",
        lighter_bg = "#1a1a2a",

        fg         = "#FAE4EF",
        dark_fg    = "#bcabb3",
        light_fg   = "#fbe8f1",
        bright_fg  = "#fbebf3",
        muted      = "#606167",

        red        = "#996b6d",
        yellow     = "#927f58",
        orange     = "#a88183",
        green      = "#57846f",
        cyan       = "#70a7b2",
        blue       = "#7e89b0",
        purple     = "#a688a9",
        brown      = "#654d4f",

        bright_red    = "#c28d8f",
        bright_yellow = "#a78d56",
        bright_green  = "#57977a",
        bright_cyan   = "#6cbac9",
        bright_blue   = "#8897cc",
        bright_purple = "#bc92c0",

        accent               = "#7e89b0",
        cursor               = "#FAE4EF",
        foreground           = "#FAE4EF",
        background           = "#010112",
        selection             = "#1a1a2a",
        selection_foreground = "#FAE4EF",
        selection_background = "#1a1a2a",
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
