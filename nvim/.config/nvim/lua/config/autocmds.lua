-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

vim.api.nvim_create_autocmd("VimLeave", {
  callback = function()
    vim.opt.guicursor = "a:ver25-blinkon1"
    vim.cmd("set t_SI= t_EI= t_SR=")
    io.write("\27[5 q")
  end,
})

vim.api.nvim_create_autocmd("FileType", {
  pattern = "amber",
  callback = function(args)
    local clients = vim.lsp.get_clients({ bufnr = args.buf, name = "amber_lsp" })
    if #clients > 0 then
      return
    end

    vim.lsp.start({
      name = "amber_lsp",
      cmd = { vim.fn.stdpath("data") .. "/mason/bin/amber-lsp" },
      root_dir = vim.fs.root(args.buf, { ".git" }) or vim.fn.getcwd(),
    })
  end,
})
