return {
  --[[{
    "MeanderingProgrammer/render-markdown.nvim",
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
      "echasnovski/mini.nvim", -- Alternative: "echasnovski/mini.icons" or "nvim-tree/nvim-web-devicons"
    },
    opts = {}, -- Configure options if needed
  },]]
  --
  {
    "OXY2DEV/markview.nvim",
    lazy = false,

    -- For blink.cmp's completion
    -- source
    -- dependencies = {
    --     "saghen/blink.cmp"
    -- },
  },
}
