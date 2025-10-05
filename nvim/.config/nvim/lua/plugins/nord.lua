-- Step 1: Check if the plugin is actually installed
-- Run this in Neovim command mode:
-- :Lazy

-- Step 2: Try this updated configuration with better error handling
return {
  "shaunsingh/nord.nvim",
  priority = 1000,
  lazy = false,
  config = function()
    -- Enable termguicolors for better color support
    vim.opt.termguicolors = true

    -- Optional: Configure nord settings before loading
    vim.g.nord_contrast = true
    vim.g.nord_borders = false
    vim.g.nord_disable_background = false
    vim.g.nord_italic = false
    vim.g.nord_uniform_diff_background = true
    vim.g.nord_bold = false

    -- Load the colorscheme
    require("nord").set()

    -- Alternative method if above doesn't work:
    vim.cmd([[colorscheme nord]])
  end,
}

-- Step 3: If still not working, try this simpler version:
-- return {
--   "shaunsingh/nord.nvim",
--   priority = 1000,
--   config = function()
--     vim.cmd("colorscheme nord")
--   end,
-- }
