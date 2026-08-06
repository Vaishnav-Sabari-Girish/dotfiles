return {
  "neo451/feed.nvim",
  cmd = "Feed",
  dependencies = {
    { "nvim-treesitter/nvim-treesitter", opts = { ensure_installed = { "xml", "html" } } },
    "ibhagwan/fzf-lua",
  },
  ---@module 'feed'
  ---@type feed.config
  opts = {
    feeds = {
      -- your feeds, or leave empty if you're only using load_opml
    },
    { "folke/snacks.nvim", lazy = false },
  },
  keys = {
    { "<leader>rf", "<cmd>Feed<cr>", desc = "Feed: index" },
    { "<leader>ru", "<cmd>Feed update<cr>", desc = "Feed: update all" },
    { "<leader>rs", "<cmd>Feed search<cr>", desc = "Feed: search" },
    { "<leader>rg", "<cmd>Feed grep<cr>", desc = "Feed: grep" },
    { "<leader>rl", "<cmd>Feed list<cr>", desc = "Feed: list feeds" },
    { "<leader>rw", "<cmd>Feed web<cr>", desc = "Feed: web ui" },
  },
}
