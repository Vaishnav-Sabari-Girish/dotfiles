return {
  "savente93/zola.nvim",
  dependencies = { "nvim-lua/plenary.nvim" },
  config = function()
    require("zola").setup()
  end,
}
