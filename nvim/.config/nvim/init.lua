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

local function toggle_maximize()
  vim.cmd("stopinsert")
  -- If we are in a dedicated full-screen tab, close it to restore previous splits
  if vim.fn.tabpagenr("$") > 1 and vim.b.is_shell_tab then
    vim.cmd("tabclose")
  else
    -- Otherwise, move the current terminal into a new tab to make it full screen
    vim.cmd("tab split")
    vim.b.is_shell_tab = true
  end
end

-- Create the custom :Shell command utilizing built-in shell command completion
vim.api.nvim_create_user_command("Shell", function(opts)
  local cmd = opts.args
  if cmd == "" then
    print("No shell command provided.")
    return
  end

  -- 1. Open a horizontal split at the bottom with a height of 12 lines
  vim.cmd("botright 12split")

  -- 2. Open a terminal running the provided command
  vim.cmd("terminal " .. cmd)

  local buf = vim.api.nvim_get_current_buf()

  -- Hide the terminal buffer from the buffer list
  vim.bo[buf].buflisted = false

  -- 3. Define buffer-local keymaps for Normal and Terminal modes
  local modes = { "n", "t" }
  local opts_map = { buffer = buf, silent = true }

  -- Toggle full screen smoothly using tabs with 'f'
  vim.keymap.set(modes, "f", toggle_maximize, opts_map)

  -- Move to Right
  vim.keymap.set(modes, "r", function()
    vim.cmd("stopinsert")
    if vim.fn.tabpagenr("$") > 1 and vim.b.is_shell_tab then
      vim.cmd("tabclose")
    end
    vim.cmd("wincmd L")
  end, opts_map)

  -- Move to Left
  vim.keymap.set(modes, "l", function()
    vim.cmd("stopinsert")
    if vim.fn.tabpagenr("$") > 1 and vim.b.is_shell_tab then
      vim.cmd("tabclose")
    end
    vim.cmd("wincmd H")
  end, opts_map)

  -- Move Up
  vim.keymap.set(modes, "u", function()
    vim.cmd("stopinsert")
    if vim.fn.tabpagenr("$") > 1 and vim.b.is_shell_tab then
      vim.cmd("tabclose")
    end
    vim.cmd("wincmd K")
  end, opts_map)

  -- Move Down
  vim.keymap.set(modes, "d", function()
    vim.cmd("stopinsert")
    if vim.fn.tabpagenr("$") > 1 and vim.b.is_shell_tab then
      vim.cmd("tabclose")
    end
    vim.cmd("wincmd J")
  end, opts_map)

  -- Automatically enter terminal input mode
  vim.cmd("startinsert")
end, {
  nargs = "*",
  complete = "shellcmd",
})

-- Global keymap to open terminal via <leader>T
vim.keymap.set("n", "<leader>T", ":Shell ", { desc = "Open Shell command terminal" })

vim.keymap.set("n", "<leader>F", function()
  require("cflow_to_mermaid").generate_flowchart()
end, { desc = "Generate call-graph flowchart (dot)" })

vim.keymap.set("n", "<leader>fL", function()
  require("cflow_to_mermaid").generate_flowchart({ include_libc = true })
end, { desc = "Generate call-graph flowchart (with libc calls)" })
