-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here
-- lua/config/options.lua
local opt = vim.opt

-- Override LazyVim's cmdheight default
opt.cmdheight = 1

-- Force it to persist
vim.api.nvim_create_autocmd("VimEnter", {
  callback = function()
    vim.o.cmdheight = 1
  end,
})
