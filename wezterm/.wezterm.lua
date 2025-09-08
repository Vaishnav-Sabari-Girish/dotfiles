local wezterm = require("wezterm")
local mux = wezterm.mux
local config = wezterm.config_builder()

config.initial_cols = 120
config.initial_rows = 28
config.font_size = 18
config.color_scheme = "nordfox"
config.enable_tab_bar = false
config.font = wezterm.font("JetBrains Mono")
config.default_cursor_style = "BlinkingBar"

wezterm.on("gui-startup", function(cmd)
	local tab, pane, window = mux.spawn_window(cmd or {})
	window:gui_window():maximize()
end)

return config
