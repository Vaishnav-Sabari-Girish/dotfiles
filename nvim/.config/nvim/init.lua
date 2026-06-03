vim.g.loaded_python3_provider = nil
vim.g.python3_host_prog = vim.fn.expand("~/.config/nvim/env/nvim-python/bin/python")
-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")

vim.opt.termguicolors = true
vim.cmd("colorscheme nord")

if vim.g.neovide then
  vim.opt.guifont = "Fira Code:h20"
  vim.opt.termguicolors = true
  vim.cmd("colorscheme nord")
  -- Also set it here with autocmd for Neovide
end

vim.opt.relativenumber = false -- Disable relative line numbers
vim.opt.number = true -- Keep absolute line numbers enabled

vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
  pattern = { "*.v" },
  callback = function()
    vim.bo.filetype = "verilog"
  end,
})
