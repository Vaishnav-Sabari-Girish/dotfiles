return {
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
