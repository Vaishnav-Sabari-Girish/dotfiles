return {
	{
		"RRethy/base16-nvim",
		priority = 1000,
		config = function()
			require('base16-colorscheme').setup({
				base00 = '#3b4252',
				base01 = '#3b4252',
				base02 = '#74787d',
				base03 = '#74787d',
				base04 = '#bec4ca',
				base05 = '#f8fbff',
				base06 = '#f8fbff',
				base07 = '#f8fbff',
				base08 = '#ff9fbc',
				base09 = '#ff9fbc',
				base0A = '#98b6d4',
				base0B = '#96e7a1',
				base0C = '#d8ebff',
				base0D = '#98b6d4',
				base0E = '#c0ddfa',
				base0F = '#c0ddfa',
			})

			vim.api.nvim_set_hl(0, 'Visual', {
				bg = '#74787d',
				fg = '#f8fbff',
				bold = true
			})
			vim.api.nvim_set_hl(0, 'Statusline', {
				bg = '#98b6d4',
				fg = '#3b4252',
			})
			vim.api.nvim_set_hl(0, 'LineNr', { fg = '#74787d' })
			vim.api.nvim_set_hl(0, 'CursorLineNr', { fg = '#d8ebff', bold = true })

			vim.api.nvim_set_hl(0, 'Statement', {
				fg = '#c0ddfa',
				bold = true
			})
			vim.api.nvim_set_hl(0, 'Keyword', { link = 'Statement' })
			vim.api.nvim_set_hl(0, 'Repeat', { link = 'Statement' })
			vim.api.nvim_set_hl(0, 'Conditional', { link = 'Statement' })

			vim.api.nvim_set_hl(0, 'Function', {
				fg = '#98b6d4',
				bold = true
			})
			vim.api.nvim_set_hl(0, 'Macro', {
				fg = '#98b6d4',
				italic = true
			})
			vim.api.nvim_set_hl(0, '@function.macro', { link = 'Macro' })

			vim.api.nvim_set_hl(0, 'Type', {
				fg = '#d8ebff',
				bold = true,
				italic = true
			})
			vim.api.nvim_set_hl(0, 'Structure', { link = 'Type' })

			vim.api.nvim_set_hl(0, 'String', {
				fg = '#96e7a1',
				italic = true
			})

			vim.api.nvim_set_hl(0, 'Operator', { fg = '#bec4ca' })
			vim.api.nvim_set_hl(0, 'Delimiter', { fg = '#bec4ca' })
			vim.api.nvim_set_hl(0, '@punctuation.bracket', { link = 'Delimiter' })
			vim.api.nvim_set_hl(0, '@punctuation.delimiter', { link = 'Delimiter' })

			vim.api.nvim_set_hl(0, 'Comment', {
				fg = '#74787d',
				italic = true
			})

			local current_file_path = vim.fn.stdpath("config") .. "/lua/plugins/dankcolors.lua"
			if not _G._matugen_theme_watcher then
				local uv = vim.uv or vim.loop
				_G._matugen_theme_watcher = uv.new_fs_event()
				_G._matugen_theme_watcher:start(current_file_path, {}, vim.schedule_wrap(function()
					local new_spec = dofile(current_file_path)
					if new_spec and new_spec[1] and new_spec[1].config then
						new_spec[1].config()
						print("Theme reload")
					end
				end))
			end
		end
	}
}
