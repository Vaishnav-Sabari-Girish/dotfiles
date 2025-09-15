local wezterm = require("wezterm")
local mux = wezterm.mux
local config = wezterm.config_builder()

config.initial_cols = 80
config.initial_rows = 30
config.font_size = 18
config.color_scheme = "Catppuccin Frappe"
config.enable_tab_bar = false
config.font = wezterm.font("JetBrains Mono")
config.default_cursor_style = "BlinkingBar"
config.use_ime = true
config.enable_kitty_graphics = true

wezterm.on("gui-startup", function(cmd)
	local tab, pane, window = mux.spawn_window(cmd or {})
	window:gui_window():maximize()
end)

return config
