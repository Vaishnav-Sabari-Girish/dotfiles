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
  $HOME/.zvm/bin
  $HOME/.rustup/toolchains/esp/xtensa-esp-elf/esp-15.2.0_20250920/xtensa-esp-elf/bin
  $HOME/alire/bin
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
export LIBCLANG_PATH="/home/vaishnav/.rustup/toolchains/esp/xtensa-esp32-elf-clang/esp-20.1.1_20250829/esp-clang/lib"
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

# Source the Boat CLI auto-tracker
if [[ -f "$HOME/dotfiles/zsh/.local/bin/boat_tracker.zsh" ]]; then
    source "$HOME/dotfiles/zsh/.local/bin/boat_tracker.zsh"
fi

# Daily Kanji Practice
_run_daily_kanji_once() {
    # Run your custom app
    $HOME/.cargo/bin/daily_kanji
    
    # Remove this function from the precmd array so it doesn't launch after every single command
    precmd_functions=("${(@)precmd_functions:#_run_daily_kanji_once}")
}

# Attach to the precmd hook (runs right before the prompt is drawn)
precmd_functions+=(_run_daily_kanji_once)

source $HOME/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
# GOVMAN - Go Version Manager
export PATH="/home/vaishnav/.govman/bin:$PATH"
# Ensure GOBIN and GOPATH/bin are available
if [ -n "$GOBIN" ]; then export PATH="$GOBIN:$PATH"; fi
if command -v go >/dev/null 2>&1; then export PATH="$(go env GOPATH)/bin:$PATH"; fi
export PATH="$HOME/go/bin:$PATH"
export GOTOOLCHAIN=local

# Wrapper function for automatic PATH execution
govman() {
    local govman_bin="/home/vaishnav/.govman/bin/govman"
    if [[ ("$1" == "use" && "$#" -ge 2 && "$2" != "--help" && "$2" != "-h") || "$1" == "refresh" ]]; then
        local output
        output="$("$govman_bin" "$@" 2>&1)"
        local exit_code=$?
        if [[ $exit_code -eq 0 ]]; then
            local export_cmd=$(printf '%s\n' "$output" | grep -E '^export PATH=' | head -n 1)
            if [[ -n "$export_cmd" && "$export_cmd" =~ ^export\ PATH=\"[^\"]*\"$ ]]; then
                eval "$export_cmd"
                echo "✓ Go version switched successfully"
                return 0
            fi
        else
            echo "$output" >&2
            return $exit_code
        fi
    fi
    "$govman_bin" "$@"
}

# Auto-switch Go versions based on .govman-goversion file
govman_auto_switch() {
    # Check if auto-switch is enabled in config
    local config_file="$HOME/.govman/config.yaml"
    local auto_switch_enabled="true"
    if [[ -f "$config_file" ]]; then
        auto_switch_enabled=$(awk '/^auto_switch:/,/^[^ ]/ {if (/^[[:space:]]*enabled:/) {print $2; exit}}' "$config_file" 2>/dev/null | tr -d '[:space:]')
        [[ -z "$auto_switch_enabled" ]] && auto_switch_enabled="true"
    fi
    if [[ "$auto_switch_enabled" != "true" ]]; then
        return 0
    fi

    # Check file exists and is non-empty (-s), handle permission errors
    if [[ -s .govman-goversion ]]; then
        local required_version
        required_version=$(cat .govman-goversion 2>/dev/null | tr -d '\n\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        if [[ $? -ne 0 ]] || [[ -z "$required_version" ]]; then
            return 0
        fi

        # Validate version format (e.g., 1.25, 1.25.1, 1.25rc1)
        if [[ ! "$required_version" =~ ^[0-9]+\.[0-9]+(\.?[0-9]*)(-?(rc|beta|alpha)[0-9]*)?$ ]]; then
            echo "Warning: Invalid version format in .govman-goversion: $required_version" >&2
            return 0
        fi

        # Skip go version call if we already matched this version
        if [[ "$required_version" == "$__govman_last_version" ]]; then
            return 0
        fi

        if ! command -v go >/dev/null 2>&1; then
            echo "Go not found. Switching to Go $required_version..."
            govman use "$required_version" >/dev/null 2>&1 || {
                echo "Warning: Failed to switch to Go $required_version. Install it with 'govman install $required_version'" >&2
            }
            return
        fi

        local current_version=$(go version 2>/dev/null | awk '{print $3}' | sed -E 's/^go//; s/([0-9]+\.[0-9]+(\.[0-9]+)?).*/\1/')
        if [[ ! "$current_version" =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?$ ]]; then current_version=""; fi
        # If required_version is major.minor only, truncate current_version for comparison
        local compare_version="$current_version"
        if [[ ! "$required_version" == *.*.* ]]; then compare_version="${current_version%%.*}.${current_version#*.}"; compare_version="${compare_version%%.*}"; fi
        if [[ -n "$current_version" && "$compare_version" != "$required_version" ]]; then
            echo "Auto-switching to Go $required_version (required by .govman-goversion)"
            govman use "$required_version" >/dev/null 2>&1 || {
                echo "Warning: Failed to switch to Go $required_version. Install it with 'govman install $required_version'" >&2
            }
            __govman_last_version="$required_version"
        elif [[ -n "$current_version" ]]; then
            __govman_last_version="$required_version"
        fi
    fi
}

# Zsh-specific: Hook into chpwd for directory changes
__govman_last_version=""
autoload -U add-zsh-hook
if [[ ! "${chpwd_functions[(r)govman_auto_switch]}" ]]; then
    add-zsh-hook chpwd govman_auto_switch
fi

# Run auto-switch on shell startup
govman_auto_switch
# END GOVMAN

# bun completions
[ -s "/home/vaishnav/.bun/_bun" ] && source "/home/vaishnav/.bun/_bun"
