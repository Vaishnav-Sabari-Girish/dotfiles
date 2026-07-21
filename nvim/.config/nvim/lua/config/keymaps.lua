-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

-- Toggle floating terminal with vim-floaterm
vim.keymap.set("n", "<leader>ft", ":FloatermToggle<CR>", { desc = "Toggle floating terminal" })

-- InYourFace toggle
vim.keymap.set("n", "<leader>fa", ":InYourFace<CR>", { desc = "Toggle Mr.Incredible's face" })

-- Links
vim.keymap.set("x", "<leader>l", "<Esc>`<i[<Esc>`>la](<C-r>+)<Esc>", { desc = "Apply markdown link to selection" })

-----------------------------------------------------------
-- Dictionary Script Integrations
-----------------------------------------------------------

-- 1. Normal mode: Define the word your cursor is currently hovering over
vim.keymap.set("n", "<leader>d", function()
  local word = vim.fn.expand("<cword>")
  if word == "" then
    return
  end

  -- Spawn the bash script in the background without freezing Neovim
  vim.fn.jobstart({ vim.fn.expand("~/.config/niri/scripts/define.sh"), word }, { detach = true })
end, { silent = true, desc = "Define word under cursor" })

-- 2. Visual mode: Define the exact text you have highlighted
vim.keymap.set("v", "<leader>d", function()
  -- Temporarily save whatever you currently have copied
  local saved_reg = vim.fn.getreg('"')

  -- Silently yank (copy) the highlighted text into Neovim's memory
  vim.cmd("noau normal! y")
  local word = vim.fn.getreg('"')

  -- Restore your previous clipboard history so we don't overwrite it
  vim.fn.setreg('"', saved_reg)

  if word == "" then
    return
  end

  -- Spawn the bash script in the background
  vim.fn.jobstart({ vim.fn.expand("~/.config/niri/scripts/define.sh"), word }, { detach = true })
end, { silent = true, desc = "Define highlighted word" })

vim.keymap.set("n", "<leader>m", function()
  require("fzf-lua").files({
    prompt = "🎵 Music> ",
    cwd = vim.fn.expand("~/Music"),
    previewer = false,
    cmd = "fd --type f --extension mp3 --extension flac --extension wav --extension ogg",
    actions = {
      ["default"] = function(selected, opts)
        if not selected or #selected == 0 then
          return
        end

        -- fzf-lua automatically resolves the absolute path based on opts.cwd
        local entry = require("fzf-lua").path.entry_to_file(selected[1], opts)

        -- Pass the fully resolved path directly to the player
        require("nvim.sfx_player").open(entry.path)
      end,
    },
  })
end, { desc = "Play Music with nvim.sfx_player" })

-- Latex
vim.keymap.set({ "v" }, "<leader>tx", "<Plug>(TxmPreview)")
vim.keymap.set({ "n", "v" }, "<leader>tt", ":TxmToggle")
