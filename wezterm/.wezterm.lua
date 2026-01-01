local wezterm = require("wezterm")
local mux = wezterm.mux
local config = wezterm.config_builder()

config.term = "wezterm"
config.initial_cols = 80
config.initial_rows = 30
config.font_size = 16
config.color_scheme = "nordfox"
config.enable_tab_bar = false
config.font = wezterm.font("JetBrainsMono Nerd Font")
config.default_cursor_style = "BlinkingBar"
config.use_ime = true
config.enable_kitty_graphics = true

wezterm.on("gui-startup", function(cmd)
	local tab, pane, window = mux.spawn_window(cmd or {})
	window:gui_window():maximize()
end)

return config
