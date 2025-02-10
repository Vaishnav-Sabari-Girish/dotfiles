$env.config.buffer_editor = "neovide"
$env.STARSHIP_CONFIG = "/home/vaishnav/.config/starship_nu.toml"
$env.ACI_GITHUB_TOKEN = "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"
use ~/.cache/starship/init.nu
$env.config.show_banner = false
alias tm = /home/vaishnav/taskcli/tm
alias cat = bat
$env.PATH = ($env.PATH | append "/usr/local/go/bin")
$env.PATH = ($env.PATH | append ($env.HOME + "/.cargo/bin"))
$env.PATH = ($env.PATH | split row (char esep) | prepend '/home/linuxbrew/.linuxbrew/bin')
alias nap = /home/vaishnav/nap-0.1.1/nap
alias type_test = /home/vaishnav/typer/typer
alias confetty = /home/vaishnav/go/bin/confetty
alias draw = /home/vaishnav/go/bin/draw
alias glyph = /home/vaishnav/go/bin/glyphs
alias fuck = thefuck $"(history | last 1 | get command | get 0)"
$env.PATH = ($env.PATH | append "/home/vaishnav/.radicle/bin")

echo "NUSHELL"
