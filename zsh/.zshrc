# ~/.zshrc

# Set options
setopt autocd             # Change to a directory by typing its name
setopt correct            # Correct command spelling
setopt share_history      # Share command history between sessions

# Set history options
HISTSIZE=1000             # Number of commands to remember in the current session
SAVEHIST=1000             # Number of commands to save in the history file
HISTFILE=~/.zsh_history   # File where history is saved

# Alias definitions
alias ll='ls -lah'        # List with human-readable sizes
alias gs='git status'     # Git status shortcut
alias ga='git add'        # Git add shortcut
alias nap='/home/vaishnav/go/bin/nap' # Your custom alias

# Load Starship prompt
eval "$(starship init zsh)"

eval "$(zoxide init zsh)"

# Environment variables
export PATH=$PATH:/usr/local/bin

# Source additional scripts or configurations
# Source secrets file if it exists
if [[ -f ~/.zsh_secrets ]]; then
    source ~/.zsh_secrets
fi

alias anki="ANKI_WAYLAND=1 anki"
export PATH=$PATH:/usr/local/go/bin
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

export POP_SMTP_HOST=smtp.gmail.com
export POP_SMTP_PORT=587

nerdfetch
printf "\n"

export EDITOR=nvim

# Added by Radicle.
export PATH="$PATH:/home/vaishnav/.radicle/bin"
export PATH="$PATH:/home/vaishnav/.cargo/bin"
export PATH="$PATH:/usr/local/go/bin"

alias nap="/home/vaishnav/nap-0.1.1/nap"
alias type_test=/home/vaishnav/typer/typer
alias confetty=/home/vaishnav/go/bin/confetty
alias draw=/home/vaishnav/go/bin/draw
alias glyph=/home/vaishnav/go/bin/glyphs
alias fuck=thefuck $"(history | last 1 | get command | get 0)"
alias cat=bat
alias pdf=evince
alias pic=eog
alias japanese="/home/vaishnav/japanese_class.sh"
alias ls="eza --icons --hyperlink"
alias tm=/home/vaishnav/taskcli/tm
alias chess=/home/vaishnav/go/bin/gambit
alias picocom="picocom --echo"
alias notebook="euporie-notebook"
export EDITOR="neovide"
export LD_LIBRARY_PATH=/lib/x86_64-linux-gnu:$LD_LIBRARY_PATH
# Configuration
export NAP_CONFIG="~/.nap/config.yaml"
export NAP_HOME="~/.nap"
export NAP_DEFAULT_LANGUAGE="ino"
export NAP_THEME="nord"

# Colors
export NAP_PRIMARY_COLOR="#AFBEE1"
export NAP_RED="#A46060"
export NAP_GREEN="#527251"
export NAP_FOREGROUND="7"
export NAP_BACKGROUND="0"
export NAP_BLACK="#373B41"
export NAP_GRAY="240"
export NAP_WHITE="#FFFFFF"

function y() {
	local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
	yazi "$@" --cwd-file="$tmp"
	if cwd="$(command cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
		builtin cd -- "$cwd"
	fi
	rm -f -- "$tmp"
}

declare -A pomo_options
pomo_options["work"]="45"
pomo_options["break"]="10"

pomodoro () {
  if [ -n "$1" -a -n "${pomo_options["$1"]}" ]; then
  val=$1
  echo $val | lolcat
  timer ${pomo_options["$val"]}m
  spd-say "'$val' session done"
  fi
}

alias wo="pomodoro 'work'"
alias br="pomodoro 'break'"

export PATH="$PATH:$HOME/.cargo/bin"
source ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh
source ~/.zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
autoload -U compinit; compinit
source ~/fzf-tab/fzf-tab.plugin.zsh

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
alias jid=/home/vaishnav/go/bin/jid
export PATH=~/bin:$PATH
export PATH=$PATH:/home/vaishnav/go/bin
export PATH=/usr/local/bin:$PATH
hash -r
# export LD_PRELOAD=/lib/x86_64-linux-gnu/libssh.so.4
alias ghfetch='/home/vaishnav/go/bin/ghfetch'
alias get_pio='source ~/.platformio/penv/bin/activate'

source /home/vaishnav/.config/broot/launcher/bash/br

# Generated for envman. Do not edit.
[ -s "$HOME/.config/envman/load.sh" ] && source "$HOME/.config/envman/load.sh"
alias teensy=/home/vaishnav/Teensy_Loader/teensy
alias cutecom=/home/vaishnav/cutecom/cutecom

alias tree="ls --tree"
gct() {
    if [ -z "$1" ]; then
        echo "Usage: grct <branch-name>"
        return 1
    fi
    git push origin "$1" && git push codeberg "$1" && git push tea "$1"
}

profile_update() {
    if [ -z "$1" ]; then
        echo "Usage: profile_update <branch-name>"
        return 1
    fi
    git push origin "$1" && git push codeberg "$1" && git push tea "$1"
}

export PATH="$HOME/.basher/bin:$PATH"   ##basher5ea843
eval "$(basher init - zsh)"             ##basher5ea843

export PATH="$PATH:/home/vaishnav/.modular/bin"

mojo_project() {
  if [ -z "$1" ]; then 
    echo "Usage: mojo_project <project_name>"
    return 1 
  fi 
  magic init "$1" --format mojoproject && rm -rf "$1"/.gitignore && rm -rf "$1"/.gitattributes
}

[ -s ~/.luaver/luaver ] && . ~/.luaver/luaver

qr() {
  if [ -z "$1" ]; then
    echo "Usage: qr <link_to_website>"
    return 1
  fi
  curl qrenco.de/"$1"
}

file_upload() {
  if [ -z "$1" ]; then
    echo "Usage: file_upload <path_to_file>"
    return 1
  fi
  link=$(ffsend upload "$1" | grep -o 'https://[^ ]*')
  echo " "
  curl qrenco.de/$link
}
