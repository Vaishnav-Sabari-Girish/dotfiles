vim.g.loaded_python3_provider = nil
vim.g.python3_host_prog = vim.fn.expand("~/.config/nvim/env/nvim-python/bin/python")
-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")

vim.opt.termguicolors = true
vim.cmd("colorscheme nord")

vim.api.nvim_create_autocmd("FileType", {
  pattern = { "c", "cpp" },
  callback = function()
    vim.bo.shiftwidth = 4
    vim.bo.tabstop = 4
    vim.bo.softtabstop = 4
    vim.bo.expandtab = true
  end,
})

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

if vim.g.neovide then
  vim.opt.guifont = "Fira Code:h20"
  vim.opt.termguicolors = true
  vim.cmd("colorscheme nord")
  -- Also set it here with autocmd for Neovide
end

vim.opt.relativenumber = false -- Disable relative line numbers
vim.opt.number = true -- Keep absolute line numbers enabled

vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
  pattern = { "*.v" },
  callback = function()
    vim.bo.filetype = "verilog"
  end,
})
