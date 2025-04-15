return {
  {
    "vhda/verilog_systemverilog.vim",
    ft = { "verilog", "systemverilog" },
  },
  {
    "neovim/nvim-lspconfig",
    config = function()
      require("lspconfig").verible.setup({
        cmd = { "verible-verilog-ls" },
        filetypes = { "verilog", "systemverilog" },
        root_dir = function(fname)
          return vim.fn.getcwd()
        end,
      })
    end,
  },
}
