return {
  "nvim-neorg/neorg",
  lazy = false, -- Disable lazy loading as some `lazy.nvim` distributions set `lazy = true` by default
  version = "*", -- Pin Neorg to the latest stable release
  config = true,
  require("neorg").setup({
    load = {
      ["core.keybinds"] = {
        config = {
          hook = function(keybinds)
            -- Presenter keybinds
            keybinds.map("presenter", "n", "<CR>", "neorg.presenter.next-page")
            keybinds.map("presenter", "n", "<BS>", "neorg.presenter.previous-page")
            -- Or use arrow keys
            keybinds.map("presenter", "n", "<Right>", "neorg.presenter.next-page")
            keybinds.map("presenter", "n", "<Left>", "neorg.presenter.previous-page")
          end,
        },
      },
      ["core.qol.todo_items"] = {},
      ["core.todo-introspector"] = {},
      ["core.defaults"] = {},
      ["core.concealer"] = {},
      ["core.export"] = {},
      ["core.looking-glass"] = {},
      ["core.export.markdown"] = {
        config = {
          extensions = "all",
        },
      },
      ["core.dirman"] = {
        config = {
          workspaces = {
            notes = "/home/vaishnav/Desktop/notes",
          },
        },
      },
    },
  }),
}
