return {
  {
    "catppuccin/nvim",
    name = "catppuccin",
    priority = 1000,
    lazy = false,
    config = function()
      require("catppuccin").setup({
        flavour = "mocha", -- Options: latte, frappe, macchiato, mocha
        transparent_background = false, -- true if you want transparency
        term_colors = true,
        integrations = {
          cmp = true,
          gitsigns = true,
          nvimtree = true,
          telescope = true,
          treesitter = true,
          -- Add more integrations as needed
        },
      })

      -- Set colorscheme
      vim.cmd.colorscheme("catppuccin")
    end,
  },
}
