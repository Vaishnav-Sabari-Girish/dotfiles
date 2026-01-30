return {
  {
    "nvim-orgmode/orgmode",
    event = "VeryLazy",
    ft = { "org" },
    config = function()
      require("orgmode").setup({
        org_agenda_files = "~/org/**/*",
        org_default_notes_file = "~/org/refile.org",

        -- ADD THIS SECTION TO REMAP KEYS
        mappings = {
          org = {
            org_toggle_checkbox = "<leader>tt", -- Was <C-space>
          },
        },
      })
    end,
  },
}
