-- Step 1: Check if the plugin is actually installed
-- Run this in Neovim command mode:
-- :Lazy

-- Step 2: Try this updated configuration with better error handling
return {
  "AlexvZyl/nordic.nvim",
  lazy = false,
  priority = 1000,
  config = function()
    require("nordic").load()
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
