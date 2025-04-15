return {
  -- Plugin: UltiSnips (the snippet engine)
  {
    "SirVer/ultisnips",
    config = function()
      -- Trigger configuration
      vim.g.UltiSnipsExpandTrigger = "<tab>" -- Expand snippet with <tab>
      vim.g.UltiSnipsJumpForwardTrigger = "<c-b>" -- Jump forward with <c-b>
      vim.g.UltiSnipsJumpBackwardTrigger = "<c-z>" -- Jump backward with <c-z>
      vim.g.UltiSnipsEditSplit = "vertical" -- Split window vertically for :UltiSnipsEdit
    end,
  },

  -- Optional Plugin: vim-snippets (snippet collection)
  {
    "honza/vim-snippets",
    -- Optionally, make it depend on UltiSnips if you want to ensure UltiSnips loads first
    dependencies = { "SirVer/ultisnips" },
  },
}
