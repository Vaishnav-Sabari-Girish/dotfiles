return {
  {
    "mrcjkb/rustaceanvim",
    version = "^7", -- Recommended
    lazy = false, -- This plugin is already lazy
    config = function()
      vim.g.rustaceanvim = {
        server = {
          cmd = { "rustup", "run", "stable", "rust-analyzer" },
        },
      }
    end,
  },
  {
    "saecki/crates.nvim",
    tag = "stable",
    event = { "BufRead Cargo.toml" },
    config = function()
      require("crates").setup({
        -- This enables the virtual text you see in the screenshot
        text = {
          searching = "  loading...",
          version = "  %s",
          upgrade = "  %s",
          error = "  error fetching",
        },
        popup = {
          autofocus = true,
          border = "rounded",
        },
      })
    end,
  },
}
