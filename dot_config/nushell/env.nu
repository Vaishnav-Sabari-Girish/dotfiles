
use std "path add"
path add "/home/linuxbrew/.linuxbrew/bin"
mkdir ~/.cache/starship
$env.STARSHIP_CONFIG = "~/.config/starship_nu.toml"
starship init nu | save -f ~/.cache/starship/init.nu

