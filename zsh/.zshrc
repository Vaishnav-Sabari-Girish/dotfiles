# ~/.zshrc

# fastfetch. Will be disabled if above colorscript was chosen to install
fastfetch -c $HOME/.config/fastfetch/config-compact.jsonc

# Set-up FZF key bindings (CTRL R for fuzzy history finder)
source <(fzf --zsh)

# Set-up icons for files/directories in terminal using lsd
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


# Environment variables
export PATH=$PATH:/usr/local/bin

# Source additional scripts or configurations
# Source secrets file if it exists
if [[ -f ~/.zsh_secrets ]]; then
    source ~/.zsh_secrets
fi

export PATH=$PATH:/usr/local/go/bin

export POP_SMTP_HOST=smtp.gmail.com
export POP_SMTP_PORT=587

printf "\n"

export EDITOR=nvim

# Added by Radicle.
export PATH="$PATH:/home/vaishnav/.radicle/bin"
export PATH="$PATH:/home/vaishnav/.cargo/bin"
export PATH="$PATH:/usr/local/go/bin"

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


export PATH="$PATH:$HOME/.cargo/bin"
autoload -U compinit; compinit

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


# Generated for envman. Do not edit.
[ -s "$HOME/.config/envman/load.sh" ] && source "$HOME/.config/envman/load.sh"
alias teensy=/home/vaishnav/Teensy_Loader/teensy
alias cutecom=/home/vaishnav/cutecom/cutecom

alias tree="ls --tree"
export PATH="$HOME/.basher/bin:$PATH"   ##basher5ea843

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


threshold=80
usage=$(df -h / | grep '/' | awk '{print $5}' | sed 's/%//')

if [ $usage -ge $threshold ]; then
    echo "Warning: Disk usage is at $usage%!"
else
    echo "Disk usage is under control."
fi

eval "$(starship init zsh)"
source ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh
source /home/vaishnav/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
export PATH=/home/vaishnav/.basher/bin:/usr/local/bin:/home/vaishnav/bin:/home/vaishnav/.basher/bin:/usr/local/bin:/home/vaishnav/bin:/home/vaishnav/.basher/bin:/usr/local/bin:/home/vaishnav/bin:/home/vaishnav/.cargo/bin:/home/vaishnav/.local/bin:/home/vaishnav/.local/lib/hyde::/usr/local/bin:/usr/bin:/var/lib/snapd/snap/bin:/usr/local/bin:/usr/local/go/bin:/home/vaishnav/.radicle/bin:/home/vaishnav/.cargo/bin:/usr/local/go/bin:/home/vaishnav/.cargo/bin:/home/vaishnav/go/bin:/home/vaishnav/.modular/bin:/usr/local/bin:/usr/local/go/bin:/home/vaishnav/.radicle/bin:/home/vaishnav/.cargo/bin:/usr/local/go/bin:/home/vaishnav/.cargo/bin:/home/vaishnav/go/bin:/home/vaishnav/.modular/bin:/usr/local/bin:/usr/local/go/bin:/home/vaishnav/.radicle/bin:/home/vaishnav/.cargo/bin:/usr/local/go/bin:/home/vaishnav/.cargo/bin:/home/vaishnav/go/bin:/home/vaishnav/.modular/bin:/opt/nvim-linux-x86_64/bin

eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

autoload -U compinit; compinit
source /home/vaishnav/fzf-tab/fzf-tab.plugin.zsh


# Function to add, commit, and push to all Git remotes with gum for input
acp() {
    # Check if gum is installed
    if ! command -v gum >/dev/null 2>&1; then
        echo 'Error: gum is not installed. Please install it from https://github.com/charmbracelet/gum'
        return 1
    fi

    # Stage all changes
    git add .

    # Prompt for commit message using gum
    commit_msg=$(gum input --placeholder 'commit message')
    if [ -z "$commit_msg" ]; then
        echo 'Error: Commit message cannot be empty'
        return 1
    fi

    # Commit changes
    git commit -m "$commit_msg"

    # Prompt for branch name using gum
    branch=$(git branch -a | gum choose | sed 's/^* //')
    if [ -z "$branch" ]; then
        echo 'Error: Branch name cannot be empty'
        return 1
    fi

    # Verify branch exists
    if ! git rev-parse --verify "$branch" >/dev/null 2>&1; then
        echo "Error: Branch $branch does not exist"
        return 1
    fi

    # Checkout the specified branch
    git checkout "$branch"

    # Get all remote names
    remotes=$(git remote)

    
    # Get all remote names into an array
    remotes=($(git remote))

    # Push to all remotes
    for remote in "${remotes[@]}"; do
        echo "Debug: Pushing to remote - $remote"
        git push "$remote" "$branch"
    done

    echo 'Changes added, committed, and pushed to all remotes'
}

export ZEIT_DB=/home/vaishnav/zeit_db/zeit.db

export RUSTONIG_SYSTEM_LIBONIG=1

# Pomodor Timer

declare -A pomo_options
pomo_options["work"]="25"
pomo_options["break"]="10"

pomodoro () {
  if [ -n "$1" -a -n "${pomo_options["$1"]}" ]; then
  val=$1
  echo $val | lolcat
  timer ${pomo_options["$val"]}m
  notify-send "'$val' session done"
  spd-say "'$val' session done"
  fi
}

alias wo="pomodoro 'work'"
alias br="pomodoro 'break'"
[ -s ~/.luaver/luaver ] && . ~/.luaver/luaver

alias temp_share_local="ssh -R 80:localhost:8888 nokey@localhost.run"

tere() {
    local result=$(command tere "$@")
    [ -n "$result" ] && cd -- "$result"
}
