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
    priority = 1000,
    config = function()
      require("markview").setup({
        -- Add your markview configuration here if needed
        experimental = {
          check_rtp = false,
          check_rtp_message = false,
        },
      })
    end,
  },
}
