-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
-- Open recent files with fzf-lua
vim.keymap.set("n", "<leader>of", require("fzf-lua").oldfiles, { desc = "Open recent files with fzf-lua" })

-- Toggle floating terminal with vim-floaterm
vim.keymap.set("n", "<leader>ft", ":FloatermToggle<CR>", { desc = "Toggle floating terminal" })
