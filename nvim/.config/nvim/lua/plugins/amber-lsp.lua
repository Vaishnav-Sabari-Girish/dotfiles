return {
  {
    "neovim/nvim-lspconfig",
    config = function()
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "amber",
        callback = function(args)
          vim.lsp.start({
            name = "amber_lsp",
            cmd = { vim.fn.stdpath("data") .. "/mason/bin/amber-lsp" },
            root_dir = vim.fs.root(args.buf, { ".git" }) or vim.fn.getcwd(),
          })
        end,
      })
    end,
  },
}
