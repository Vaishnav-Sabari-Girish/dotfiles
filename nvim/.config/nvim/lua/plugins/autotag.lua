return {
  {
    "windwp/nvim-ts-autotag",
    config = function()
      -- Using 'config' instead of 'opts' forces Neovim to completely ignore
      -- any default filetypes the plugin tries to load.
      require("nvim-ts-autotag").setup({
        filetypes = {
          "html",
          "javascript",
          "typescript",
          "javascriptreact",
          "typescriptreact",
          "svelte",
          "vue",
          "tsx",
          "jsx",
          "xml",
          "markdown",
        },
      })
    end,
  },
}
