-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")

vim.opt.termguicolors = true
vim.cmd("colorscheme nord")

-- Ensure cmdheight is set after all plugins load
vim.api.nvim_create_autocmd("VimEnter", {
  callback = function()
    vim.o.cmdheight = 1
  end,
})

if vim.g.neovide then
  vim.opt.guifont = "Fira Code:h20"
  vim.opt.termguicolors = true
  vim.cmd("colorscheme nord")
  -- Also set it here with autocmd for Neovide
  vim.api.nvim_create_autocmd("VimEnter", {
    callback = function()
      vim.o.cmdheight = 1
    end,
  })
end

vim.opt.relativenumber = false -- Disable relative line numbers
vim.opt.number = true -- Keep absolute line numbers enabled
vim.g.python3_host_prog = "/usr/bin/python"

vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
  pattern = { "*.v" },
  callback = function()
    vim.bo.filetype = "verilog"
  end,
})
