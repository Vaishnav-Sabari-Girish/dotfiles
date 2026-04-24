# ~/.zshrc

# --- PATH CONFIGURATION ---
typeset -U path PATH # Automatically removes duplicates

path=(
  $HOME/bin
  $HOME/.local/bin
  $HOME/go/bin
  $HOME/.cargo/bin
  $HOME/.bun/bin
  $HOME/.modular/bin
  $HOME/.nimble/bin
  $HOME/.basher/bin
  $HOME/.asdf/shims
  $HOME/.zvm/bin
  $HOME/.zvm/self
  $HOME/.deno/bin
  /usr/local/go/bin
  /usr/local/bin
  /var/lib/snapd/snap/bin
  $HOME/.local/lib/hyde
  /opt/nvim-linux-x86_64/bin
  $path # Appends system paths
)
export PATH

# --- BASICS ---
# Set-up FZF key bindings (CTRL R for fuzzy history finder)
source <(fzf --zsh)

# Options
setopt autocd             # Change to a directory by typing its name
setopt correct            # Correct command spelling
setopt share_history      # Share command history between sessions

# History file configuration
HISTFILE=~/.zsh_history
HISTSIZE=10000            # Number of commands in memory
SAVEHIST=10000            # Number of commands saved to file

# History options
setopt EXTENDED_HISTORY          # Record timestamp of command
setopt INC_APPEND_HISTORY        # Write to history file immediately
setopt HIST_EXPIRE_DUPS_FIRST    # Delete duplicates first when trimming
setopt HIST_IGNORE_DUPS          # Don't record duplicate commands
setopt HIST_IGNORE_SPACE         # Ignore commands starting with space
setopt HIST_VERIFY               # Show command before running with history expansion

# --- ALIASES ---
alias stm32erase="/opt/stm32cubeprog/bin/STM32_Programmer_CLI -c port=SWD freq=480 mode=HotPlug -e all"

# Key bindings
bindkey "^[[H" beginning-of-line    # Home
bindkey "^[[F" end-of-line          # End  
bindkey "^[[3~" delete-char         # Delete

# --- ENVIRONMENT VARIABLES ---
export EDITOR=nvim
export LD_LIBRARY_PATH=/lib/x86_64-linux-gnu:$LD_LIBRARY_PATH
export NAP_CONFIG="~/.nap/config.yaml" 
export NAP_HOME="~/.nap" 
export NAP_DEFAULT_LANGUAGE="ino" 
export NAP_THEME="catppuccin-mocha"
export NVM_DIR="$HOME/.nvm"
export RUSTONIG_SYSTEM_LIBONIG=1
export LIBCLANG_PATH="$HOME/.rustup/toolchains/esp/xtensa-esp32-elf-clang/esp-20.1.1_20250829/esp-clang/lib"
export LC_ALL=en_IN.UTF-8
export LANG=en_IN.UTF-8
export BUN_INSTALL="$HOME/.bun"
export ZVM_INSTALL="$HOME/.zvm/self"
export ZEPHYR_BASE="$HOME/zephyrproject/zephyr/"
export STARSHIP_CONFIG="$HOME/.config/starship/starship.toml"

# --- COMPLETIONS & FUNCTIONS ---
# Add custom completions to fpath (Stow path)
fpath=($HOME/.zsh/completions $fpath)

# Source custom functions (Stow path)
if [[ -f ~/.zsh_functions ]]; then
    source ~/.zsh_functions
fi

# --- EXTERNAL TOOLS & SCRIPTS ---
if [[ -f ~/.zsh_secrets ]]; then
    source ~/.zsh_secrets
fi

[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
hash -r

[ -s "$HOME/.config/envman/load.sh" ] && source "$HOME/.config/envman/load.sh"
[ -s ~/.luaver/luaver ] && . ~/.luaver/luaver
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"

# Custom Startup Scripts (Now calling from .local/bin)
if [[ -f $HOME/.local/bin/anime_quote.sh ]]; then
    bash $HOME/.local/bin/anime_quote.sh
fi

eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

# --- INITIALIZATION (MUST BE LAST) ---
# Initialize plugins and completions
autoload -Uz compinit; compinit
eval "$(starship init zsh)"

source ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh
source $HOME/fzf-tab/fzf-tab.zsh
source $HOME/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# Fixing cursor in foot
# Force the cursor to be a Blinking Beam at the prompt
# \e[5 q = Blinking Beam
# \e[6 q = Steady Beam
_fix_cursor() {
   echo -ne '\e[5 q'
}
precmd_functions+=(_fix_cursor)

# Amoxide init
eval "$(am init zsh)"   # Context aware alias

# Daily Kanji Practice
run_daily_kanji_check

# Source the Boat CLI auto-tracker
if [[ -f "$HOME/dotfiles/zsh/.local/bin/boat_tracker.zsh" ]]; then
    source "$HOME/dotfiles/zsh/.local/bin/boat_tracker.zsh"
fi
