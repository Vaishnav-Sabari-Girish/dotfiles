# ~/.zshrc

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

fpath=($HOME/completition_zsh/ $fpath)

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
export NAP_CONFIG="~/.nap/config.yaml" 
export NAP_HOME="~/.nap" 
export NAP_DEFAULT_LANGUAGE="ino" 
export NAP_THEME="catppuccin-mocha"

#Colors

export NAP_PRIMARY_COLOR="#CBA6F7" # Mauve: Pastel purple for primary highlights 
export NAP_RED="#EBA0AC" # Maroon: Deeper red for errors or warnings 
export NAP_GREEN="#A6E3A1" # Green: Minty green for success or accents 
export NAP_FOREGROUND="#CDD6F4" # Text: Light off-white for primary text 
export NAP_BACKGROUND="#1E1E2E" # Base: Dark purple-gray for background 
export NAP_BLACK="#181825" # Mantle: Near-black for dark elements 
export NAP_GRAY="#585B70" # Surface2: Medium-dark gray for neutral elements 
export NAP_WHITE="#F5E0DC" # Rosewater: Soft pinkish-beige for white accents


export PATH="$PATH:$HOME/.cargo/bin"
export PATH="$PATH:$HOME/.nimble/bin/"
autoload -U compinit; compinit

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
alias jid=/home/vaishnav/go/bin/jid
export PATH=~/bin:$PATH
export PATH=$PATH:/home/vaishnav/go/bin
export PATH=/usr/local/bin:$PATH
export PATH="$PATH:$HOME/.local/lib/python3.13/"
hash -r
# export LD_PRELOAD=/lib/x86_64-linux-gnu/libssh.so.4
alias ghfetch='/home/vaishnav/go/bin/ghfetch'
alias get_pio='source ~/.platformio/penv/bin/activate'


# Generated for envman. Do not edit.
[ -s "$HOME/.config/envman/load.sh" ] && source "$HOME/.config/envman/load.sh"
alias teensy=/home/vaishnav/Teensy_Loader/teensy
alias cutecom=/home/vaishnav/cutecom/cutecom

alias tree="eza --icons --hyperlink --tree"
export PATH="$HOME/.basher/bin:$PATH"   ##basher5ea843

export PATH="$PATH:/home/vaishnav/.modular/bin"
export PATH="$PATH:/home/vaishnav/.deno/bin/deno"

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



echo "# Check addae regularly" | /home/linuxbrew/.linuxbrew/bin/glow -

eval "$(starship init zsh)"
source ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh
source /home/vaishnav/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
export PATH=/home/vaishnav/.basher/bin:/usr/local/bin:/home/vaishnav/bin:/home/vaishnav/.basher/bin:/usr/local/bin:/home/vaishnav/bin:/home/vaishnav/.basher/bin:/usr/local/bin:/home/vaishnav/bin:/home/vaishnav/.cargo/bin:/home/vaishnav/.local/bin:/home/vaishnav/.local/lib/hyde::/usr/local/bin:/usr/bin:/var/lib/snapd/snap/bin:/usr/local/bin:/usr/local/go/bin:/home/vaishnav/.cargo/bin:/usr/local/go/bin:/home/vaishnav/.cargo/bin:/home/vaishnav/go/bin:/home/vaishnav/.modular/bin:/usr/local/bin:/usr/local/go/bin:/home/vaishnav/.cargo/bin:/usr/local/go/bin:/home/vaishnav/.cargo/bin:/home/vaishnav/go/bin:/home/vaishnav/.modular/bin:/usr/local/bin:/usr/local/go/bin:/home/vaishnav/.cargo/bin:/usr/local/go/bin:/home/vaishnav/.cargo/bin:/home/vaishnav/go/bin:/home/vaishnav/.modular/bin:/opt/nvim-linux-x86_64/bin

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
    branch=$(git branch | gum choose | sed 's/^* //')
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

acpf() {
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
    branch=$(git branch | gum choose | sed 's/^* //')
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
        git push "$remote" "$branch" --force
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
. "/home/vaishnav/.deno/env"

alias preview_md="gh markdown-preview"

form_create() {
    local num_questions code
    # Prompt for number of questions
    num_questions=$(gum input --prompt "Enter number of questions: " --placeholder "e.g., 5")
    
    # Validate number of questions is a positive integer
    if [[ ! "$num_questions" =~ ^[0-9]+$ ]] || [ "$num_questions" -le 0 ]; then
        echo "Error: Please enter a valid positive number"
        return 1
    fi
    
    # Prompt for code
    code=$(gum input --prompt "Enter form code: " --placeholder "e.g., myform123")
    
    # Validate code is not empty
    if [ -z "$code" ]; then
        echo "Error: Code cannot be empty"
        return 1
    fi
    
    # Execute ssh command to create bashform
    ssh -t bashform.me create "$num_questions" "$code"
}

function ans_form() {
    local code
    # Prompt for form code using gum input
    code=$(gum input --prompt "Enter form code: " --placeholder "e.g., myform123")
    
    # Validate code is not empty
    if [ -z "$code" ]; then
        echo "Error: Code cannot be empty"
        return 1
    fi
    
    # Execute ssh command to answer the form
    ssh -t bashform.me form "$code"
}

function view_forms() {
    # Execute ssh command to view all form answers
    ssh -t bashform.me forms
}

alias img="loupe"
export PATH="$HOME/zig-x86_64-linux-0.15.0-dev.936+fc2c1883b:$PATH"

export PATH="/home/vaishnav/.rustup/toolchains/esp/xtensa-esp-elf/esp-14.2.0_20240906/xtensa-esp-elf/bin:$PATH"
export LIBCLANG_PATH="/home/vaishnav/.rustup/toolchains/esp/xtensa-esp32-elf-clang/esp-19.1.2_20250225/esp-clang/lib"


pdf_manager() {
    # Check if gum is installed
    if ! command -v gum &> /dev/null; then
        echo "Error: gum is not installed. Install it with: brew install gum"
        return 1
    fi

    # Main menu
    local action=$(gum choose "Merge PDFs" "Separate PDF" "Remove Pages from PDF")
    
    case $action in
        "Merge PDFs")
            merge_pdfs
            ;;
        "Separate PDF")
            separate_pdf
            ;;
        "Remove Pages from PDF")
            remove_pages
            ;;
        *)
            echo "Operation cancelled"
            return 0
            ;;
    esac
}

merge_pdfs() {
    echo "📚 Merging PDFs"
    
    # Get list of PDF files in current directory
    local pdf_files=(*.pdf)
    
    if [[ ${#pdf_files[@]} -eq 0 ]] || [[ "${pdf_files[1]}" == "*.pdf" ]]; then
        echo "❌ No PDF files found in current directory"
        return 1
    fi
    
    # Multi-select PDF files to merge
    local selected_files=$(gum choose --no-limit "${pdf_files[@]}")
    
    if [[ -z "$selected_files" ]]; then
        echo "❌ No files selected"
        return 1
    fi
    
    # Get output filename
    local output_file=$(gum input --placeholder "Enter output filename (e.g., merged.pdf)")
    
    if [[ -z "$output_file" ]]; then
        echo "❌ No output filename provided"
        return 1
    fi
    
    # Ensure .pdf extension
    if [[ "$output_file" != *.pdf ]]; then
        output_file="${output_file}.pdf"
    fi
    
    # Confirm before merging
    echo "Selected files:"
    echo "$selected_files" | while read -r file; do
        echo "  - $file"
    done
    echo "Output: $output_file"
    
    if gum confirm "Proceed with merge?"; then
        # Convert newline-separated string to array for pdfunite
        local files_array=()
        while IFS= read -r file; do
            files_array+=("$file")
        done <<< "$selected_files"
        
        pdfunite "${files_array[@]}" "$output_file"
        echo "✅ PDFs merged successfully: $output_file"
    else
        echo "❌ Merge cancelled"
    fi
}

separate_pdf() {
    echo "📄 Separating PDF"
    
    # Get list of PDF files
    local pdf_files=(*.pdf)
    
    if [[ ${#pdf_files[@]} -eq 0 ]] || [[ "${pdf_files[1]}" == "*.pdf" ]]; then
        echo "❌ No PDF files found in current directory"
        return 1
    fi
    
    # Select PDF to separate
    local input_file=$(gum choose "${pdf_files[@]}")
    
    if [[ -z "$input_file" ]]; then
        echo "❌ No file selected"
        return 1
    fi
    
    # Get base name for output files
    local base_name=$(gum input --placeholder "Enter base name for output files (default: page)" --value "page")
    
    if [[ -z "$base_name" ]]; then
        base_name="page"
    fi
    
    if gum confirm "Separate $input_file into individual pages?"; then
        pdfseparate "$input_file" "${base_name}-%d.pdf"
        echo "✅ PDF separated successfully with pattern: ${base_name}-%d.pdf"
    else
        echo "❌ Separation cancelled"
    fi
}

remove_pages() {
    echo "✂️  Removing Pages from PDF"
    
    # Get list of PDF files
    local pdf_files=(*.pdf)
    
    if [[ ${#pdf_files[@]} -eq 0 ]] || [[ "${pdf_files[1]}" == "*.pdf" ]]; then
        echo "❌ No PDF files found in current directory"
        return 1
    fi
    
    # Select PDF file
    local input_file=$(gum choose "${pdf_files[@]}")
    
    if [[ -z "$input_file" ]]; then
        echo "❌ No file selected"
        return 1
    fi
    
    # Get total page count (requires pdfinfo from poppler-utils)
    local total_pages
    if command -v pdfinfo &> /dev/null; then
        total_pages=$(pdfinfo "$input_file" | grep "Pages:" | awk '{print $2}')
        echo "📊 Total pages in $input_file: $total_pages"
    else
        echo "⚠️  pdfinfo not available. Cannot show page count."
        total_pages=$(gum input --placeholder "Enter total number of pages in the PDF")
    fi
    
    # Get pages to remove
    local pages_to_remove=$(gum input --placeholder "Enter page numbers to remove (e.g., 2,5,7-9)")
    
    if [[ -z "$pages_to_remove" ]]; then
        echo "❌ No pages specified"
        return 1
    fi
    
    # Get output filename
    local output_file=$(gum input --placeholder "Enter output filename" --value "${input_file%.*}_modified.pdf")
    
    if [[ -z "$output_file" ]]; then
        echo "❌ No output filename provided"
        return 1
    fi
    
    # Ensure .pdf extension
    if [[ "$output_file" != *.pdf ]]; then
        output_file="${output_file}.pdf"
    fi
    
    echo "Input: $input_file"
    echo "Pages to remove: $pages_to_remove"
    echo "Output: $output_file"
    
    if gum confirm "Proceed with page removal?"; then
        # Create temporary directory
        local temp_dir=$(mktemp -d)
        local base_name="temp_page"
        
        # Separate all pages
        echo "🔄 Separating pages..."
        pdfseparate "$input_file" "$temp_dir/${base_name}-%d.pdf"
        
        # Build array of pages to keep
        local pages_to_keep=()
        local pages_to_remove_array=()
        
        # Parse pages to remove (handle ranges and individual pages)
        # Use zsh-specific array splitting to fix the read -ra issue
        local remove_parts=(${(s:,:)pages_to_remove})
        
        for part in "${remove_parts[@]}"; do
            part=$(echo "$part" | tr -d ' ')  # Remove spaces
            if [[ "$part" == *-* ]]; then
                # Handle range (e.g., 7-9)
                local start=${part%-*}
                local end=${part#*-}
                for ((i=start; i<=end; i++)); do
                    pages_to_remove_array+=($i)
                done
            else
                # Handle individual page
                pages_to_remove_array+=($part)
            fi
        done
        
        # Build list of pages to keep
        for ((i=1; i<=total_pages; i++)); do
            local should_remove=false
            for remove_page in "${pages_to_remove_array[@]}"; do
                if [[ $i -eq $remove_page ]]; then
                    should_remove=true
                    break
                fi
            done
            if [[ $should_remove == false ]]; then
                if [[ -f "$temp_dir/${base_name}-$i.pdf" ]]; then
                    pages_to_keep+=("$temp_dir/${base_name}-$i.pdf")
                fi
            fi
        done
        
        if [[ ${#pages_to_keep[@]} -eq 0 ]]; then
            echo "❌ No pages would remain after removal"
            rm -rf "$temp_dir"
            return 1
        fi
        
        # Merge remaining pages
        echo "🔄 Merging remaining pages..."
        pdfunite "${pages_to_keep[@]}" "$output_file"
        
        # Clean up temporary files
        rm -rf "$temp_dir"
        
        echo "✅ Pages removed successfully: $output_file"
        echo "📊 Kept $(( total_pages - ${#pages_to_remove_array[@]} )) of $total_pages pages"
    else
        echo "❌ Operation cancelled"
    fi
}


wsend() {
    local script_path="$HOME/dotfiles/zsh/send_file.sh"
    
    if [[ -x "$script_path" ]]; then
        "$script_path" "$@"
    else
        echo "Error: Script not found or not executable at $script_path"
        return 1
    fi
}


wreceive() {
    local script_path="$HOME/dotfiles/zsh/receive_file.sh"
    
    if [[ -x "$script_path" ]]; then
        "$script_path" "$@"
    else
        echo "Error: receive_file.sh not found or not executable at $script_path"
        return 1
    fi
}


gist_manager() {
    local script_path="$HOME/dotfiles/zsh/gist_manager.sh"
    
    if [[ -x "$script_path" ]]; then
        "$script_path" "$@"
    else
        echo "Error: gist_manager.sh not found or not executable at $script_path"
        return 1
    fi
}

bindkey "^[[H" beginning-of-line    # Home
bindkey "^[[F" end-of-line          # End  
bindkey "^[[3~" delete-char         # Delete
