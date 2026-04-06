-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
-- Toggle floating terminal with vim-floaterm
vim.keymap.set("n", "<leader>ft", ":FloatermToggle<CR>", { desc = "Toggle floating terminal" })

-- InYourFace toggle
vim.keymap.set("n", "<leader>fa", ":InYourFace<CR>", { desc = "Toggle Mr.Incredible's face" })
