# ~/.zshrc

# Set-up FZF key bindings (CTRL R for fuzzy history finder)
source <(fzf --zsh)

# Set-up icons for files/directories in terminal using lsd
# Set options
setopt autocd             # Change to a directory by typing its name
setopt correct            # Correct command spelling
setopt share_history      # Share command history between sessions

# History file configuration
HISTFILE=~/.zsh_history
HISTSIZE=10000           # Number of commands in memory
SAVEHIST=10000          # Number of commands saved to file

# History options
setopt EXTENDED_HISTORY          # Record timestamp of command
setopt INC_APPEND_HISTORY        # Write to history file immediately
setopt HIST_EXPIRE_DUPS_FIRST    # Delete duplicates first when trimming
setopt HIST_IGNORE_DUPS          # Don't record duplicate commands
setopt HIST_IGNORE_SPACE         # Ignore commands starting with space
setopt HIST_VERIFY               # Show command before running with history expansion

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

alias tree="wisu -g --icons --hyperlinks"
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


bash $HOME/dotfiles/zsh/anime_quote.sh

echo "# Check addae regularly" | $HOME/go/bin/glow -

eval "$(starship init zsh)"
source ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh
source /home/vaishnav/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
export PATH=/home/vaishnav/.basher/bin:/usr/local/bin:/home/vaishnav/bin:/home/vaishnav/.basher/bin:/usr/local/bin:/home/vaishnav/bin:/home/vaishnav/.basher/bin:/usr/local/bin:/home/vaishnav/bin:/home/vaishnav/.cargo/bin:/home/vaishnav/.local/bin:/home/vaishnav/.local/lib/hyde::/usr/local/bin:/usr/bin:/var/lib/snapd/snap/bin:/usr/local/bin:/usr/local/go/bin:/home/vaishnav/.cargo/bin:/usr/local/go/bin:/home/vaishnav/.cargo/bin:/home/vaishnav/go/bin:/home/vaishnav/.modular/bin:/usr/local/bin:/usr/local/go/bin:/home/vaishnav/.cargo/bin:/usr/local/go/bin:/home/vaishnav/.cargo/bin:/home/vaishnav/go/bin:/home/vaishnav/.modular/bin:/usr/local/bin:/usr/local/go/bin:/home/vaishnav/.cargo/bin:/usr/local/go/bin:/home/vaishnav/.cargo/bin:/home/vaishnav/go/bin:/home/vaishnav/.modular/bin:/opt/nvim-linux-x86_64/bin

eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

autoload -U compinit; compinit
source /home/vaishnav/fzf-tab/fzf-tab.plugin.zsh


# Function to add, commit, and push to all Git remotes with meteor for conventional commits
acp() {
    # Check if meteor is installed
    if ! command -v meteor >/dev/null 2>&1; then
        echo 'Error: meteor is not installed. Install with: go install github.com/stefanlogue/meteor@latest'
        return 1
    fi

    # Stage all changes
    git add .

    # Use meteor for conventional commit (interactive)
    meteor
    
    # Check if commit was successful
    if [ $? -ne 0 ]; then
        echo 'Error: Commit failed or was cancelled'
        return 1
    fi

    # Check if gum is installed for branch selection
    if ! command -v gum >/dev/null 2>&1; then
        echo 'Error: gum is not installed. Please install it from https://github.com/charmbracelet/gum'
        return 1
    fi

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

    # Checkout the specified branch (only if not already on it)
    current_branch=$(git branch --show-current)
    if [ "$current_branch" != "$branch" ]; then
        git checkout "$branch"
    fi

    # Get all remote names into an array
    remotes=($(git remote))

    # Push to all remotes
    for remote in "${remotes[@]}"; do
        echo "Pushing to remote: $remote"
        git push "$remote" "$branch"
    done

    echo 'Changes added, committed with conventional format, and pushed to all remotes'
}

# Function to add, commit, and push to all Git remotes with meteor for conventional commits
acpf() {
    # Check if meteor is installed
    if ! command -v meteor >/dev/null 2>&1; then
        echo 'Error: meteor is not installed. Install with: go install github.com/stefanlogue/meteor@latest'
        return 1
    fi

    # Stage all changes
    git add .

    # Use meteor for conventional commit (interactive)
    meteor
    
    # Check if commit was successful
    if [ $? -ne 0 ]; then
        echo 'Error: Commit failed or was cancelled'
        return 1
    fi

    # Check if gum is installed for branch selection
    if ! command -v gum >/dev/null 2>&1; then
        echo 'Error: gum is not installed. Please install it from https://github.com/charmbracelet/gum'
        return 1
    fi

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

    # Checkout the specified branch (only if not already on it)
    current_branch=$(git branch --show-current)
    if [ "$current_branch" != "$branch" ]; then
        git checkout "$branch"
    fi

    # Get all remote names into an array
    remotes=($(git remote))

    # Push to all remotes
    for remote in "${remotes[@]}"; do
        echo "Pushing to remote: $remote"
        git push --force "$remote" "$branch"
    done

    echo 'Changes added, committed with conventional format, and pushed to all remotes'
}

export ZEIT_DB=/home/vaishnav/zeit_db/zeit.db

export RUSTONIG_SYSTEM_LIBONIG=1

[ -s ~/.luaver/luaver ] && . ~/.luaver/luaver

alias temp_share_local="ssh -R 80:localhost:8888 nokey@localhost.run"
alias project="cd $HOME/Desktop/My_Projects/"

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

export PATH="$HOME/zig-x86_64-linux-0.15.0-dev.936+fc2c1883b:$PATH"

export LIBCLANG_PATH="/home/vaishnav/.rustup/toolchains/esp/xtensa-esp32-elf-clang/esp-20.1.1_20250829/esp-clang/lib"
export PATH="/home/vaishnav/.rustup/toolchains/esp/xtensa-esp-elf/esp-15.2.0_20250920/xtensa-esp-elf/bin:$PATH"


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


mkproj() {
    local script_path="$HOME/dotfiles/zsh/mkproj.sh"
    
    if [[ -x "$script_path" ]]; then
        "$script_path" "$@"
    else
        echo "Error: mkproj.sh not found or not executable at $script_path"
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

mp4_to_gif() {
    local script_path="$HOME/dotfiles/zsh/mp4_to_gif.sh"
    
    if [[ -x "$script_path" ]]; then
        "$script_path" "$@"
    else
        echo "Error: mp4_to_gif.sh not found or not executable at $script_path"
        return 1
    fi
}

bindkey "^[[H" beginning-of-line    # Home
bindkey "^[[F" end-of-line          # End  
bindkey "^[[3~" delete-char         # Delete

#compdef just

autoload -U is-at-least

_just() {
    typeset -A opt_args
    typeset -a _arguments_options
    local ret=1

    if is-at-least 5.2; then
        _arguments_options=(-s -S -C)
    else
        _arguments_options=(-s -C)
    fi

    local context curcontext="$curcontext" state line
    local common=(
'(--no-aliases)--alias-style=[Set list command alias display style]: :(left right separate)' \
'--ceiling=[Do not ascend above <CEILING> directory when searching for a justfile.]: :_files' \
'--chooser=[Override binary invoked by \`--choose\`]: :_default' \
'--color=[Print colorful output]: :(always auto never)' \
'--command-color=[Echo recipe lines in <COMMAND-COLOR>]: :(black blue cyan green purple red yellow)' \
'--cygpath=[Use binary at <CYGPATH> to convert between unix and Windows paths.]: :_files' \
'(-E --dotenv-path)--dotenv-filename=[Search for environment file named <DOTENV-FILENAME> instead of \`.env\`]: :_default' \
'-E+[Load <DOTENV-PATH> as environment file instead of searching for one]: :_files' \
'--dotenv-path=[Load <DOTENV-PATH> as environment file instead of searching for one]: :_files' \
'--dump-format=[Dump justfile as <FORMAT>]:FORMAT:(json just)' \
'-f+[Use <JUSTFILE> as justfile]: :_files' \
'--justfile=[Use <JUSTFILE> as justfile]: :_files' \
'--list-heading=[Print <TEXT> before list]:TEXT:_default' \
'--list-prefix=[Print <TEXT> before each list item]:TEXT:_default' \
'*--set=[Override <VARIABLE> with <VALUE>]: :(_just_variables)' \
'--shell=[Invoke <SHELL> to run recipes]: :_default' \
'*--shell-arg=[Invoke shell with <SHELL-ARG> as an argument]: :_default' \
'--tempdir=[Save temporary files to <TEMPDIR>.]: :_files' \
'--timestamp-format=[Timestamp format string]: :_default' \
'-d+[Use <WORKING-DIRECTORY> as working directory. --justfile must also be set]: :_files' \
'--working-directory=[Use <WORKING-DIRECTORY> as working directory. --justfile must also be set]: :_files' \
'*-c+[Run an arbitrary command with the working directory, \`.env\`, overrides, and exports set]: :_default' \
'*--command=[Run an arbitrary command with the working directory, \`.env\`, overrides, and exports set]: :_default' \
'--completions=[Print shell completion script for <SHELL>]:SHELL:(bash elvish fish nushell powershell zsh)' \
'()-l+[List available recipes in <MODULE> or root if omitted]' \
'()--list=[List available recipes in <MODULE> or root if omitted]' \
'--request=[Execute <REQUEST>. For internal testing purposes only. May be changed or removed at any time.]: :_default' \
'-s+[Show recipe at <PATH>]: :(_just_commands)' \
'--show=[Show recipe at <PATH>]: :(_just_commands)' \
'--check[Run \`--fmt\` in '\''check'\'' mode. Exits with 0 if justfile is formatted correctly. Exits with 1 and prints a diff if formatting is required.]' \
'--clear-shell-args[Clear shell arguments]' \
'(-q --quiet)-n[Print what just would do without doing it]' \
'(-q --quiet)--dry-run[Print what just would do without doing it]' \
'--explain[Print recipe doc comment before running it]' \
'(-f --justfile -d --working-directory)-g[Use global justfile]' \
'(-f --justfile -d --working-directory)--global-justfile[Use global justfile]' \
'--highlight[Highlight echoed recipe lines in bold]' \
'--list-submodules[List recipes in submodules]' \
'--no-aliases[Don'\''t show aliases in list]' \
'--no-deps[Don'\''t run recipe dependencies]' \
'--no-dotenv[Don'\''t load \`.env\` file]' \
'--no-highlight[Don'\''t highlight echoed recipe lines in bold]' \
'--one[Forbid multiple recipes from being invoked on the command line]' \
'(-n --dry-run)-q[Suppress all output]' \
'(-n --dry-run)--quiet[Suppress all output]' \
'--allow-missing[Ignore missing recipe and module errors]' \
'--shell-command[Invoke <COMMAND> with the shell used to run recipe lines and backticks]' \
'--timestamp[Print recipe command timestamps]' \
'-u[Return list and summary entries in source order]' \
'--unsorted[Return list and summary entries in source order]' \
'--unstable[Enable unstable features]' \
'*-v[Use verbose output]' \
'*--verbose[Use verbose output]' \
'--yes[Automatically confirm all recipes.]' \
'--changelog[Print changelog]' \
'--choose[Select one or more recipes to run using a binary chooser. If \`--chooser\` is not passed the chooser defaults to the value of \$JUST_CHOOSER, falling back to \`fzf\`]' \
'--dump[Print justfile]' \
'-e[Edit justfile with editor given by \$VISUAL or \$EDITOR, falling back to \`vim\`]' \
'--edit[Edit justfile with editor given by \$VISUAL or \$EDITOR, falling back to \`vim\`]' \
'--evaluate[Evaluate and print all variables. If a variable name is given as an argument, only print that variable'\''s value.]' \
'--fmt[Format and overwrite justfile]' \
'--groups[List recipe groups]' \
'--init[Initialize new justfile in project root]' \
'--man[Print man page]' \
'--summary[List names of available recipes]' \
'--variables[List names of variables]' \
'-h[Print help]' \
'--help[Print help]' \
'-V[Print version]' \
'--version[Print version]' \
)

    _arguments "${_arguments_options[@]}" $common \
        '1: :_just_commands' \
        '*: :->args' \
        && ret=0

    case $state in
        args)
            curcontext="${curcontext%:*}-${words[2]}:"

            local lastarg=${words[${#words}]}
            local recipe

            local cmds; cmds=(
                ${(s: :)$(_call_program commands just --summary)}
            )

            # Find first recipe name
            for ((i = 2; i < $#words; i++ )) do
                if [[ ${cmds[(I)${words[i]}]} -gt 0 ]]; then
                    recipe=${words[i]}
                    break
                fi
            done

            if [[ $lastarg = */* ]]; then
                # Arguments contain slash would be recognised as a file
                _arguments -s -S $common '*:: :_files'
            elif [[ $lastarg = *=* ]]; then
                # Arguments contain equal would be recognised as a variable
                _message "value"
            elif [[ $recipe ]]; then
                # Show usage message
                _message "`just --show $recipe`"
                # Or complete with other commands
                #_arguments -s -S $common '*:: :_just_commands'
            else
                _arguments -s -S $common '*:: :_just_commands'
            fi
        ;;
    esac

    return ret

}

(( $+functions[_just_commands] )) ||
_just_commands() {
    [[ $PREFIX = -* ]] && return 1
    integer ret=1
    local variables; variables=(
        ${(s: :)$(_call_program commands just --variables)}
    )
    local commands; commands=(
        ${${${(M)"${(f)$(_call_program commands just --list)}":#    *}/ ##/}/ ##/:Args: }
    )

    if compset -P '*='; then
        case "${${words[-1]%=*}#*=}" in
            *) _message 'value' && ret=0 ;;
        esac
    else
        _describe -t variables 'variables' variables -qS "=" && ret=0
        _describe -t commands 'just commands' commands "$@"
    fi

}

if [ "$funcstack[1]" = "_just" ]; then
    (( $+functions[_just_variables] )) ||
_just_variables() {
    [[ $PREFIX = -* ]] && return 1
    integer ret=1
    local variables; variables=(
        ${(s: :)$(_call_program commands just --variables)}
    )

    if compset -P '*='; then
        case "${${words[-1]%=*}#*=}" in
            *) _message 'value' && ret=0 ;;
        esac
    else
        _describe -t variables 'variables' variables && ret=0
    fi

    return ret
}

_just "$@"
else
    compdef _just just
fi

. $HOME/go/pkg/mod/github.com/asdf-vm/asdf@v0.18.0/asdf.sh

function img() {
    
    if [[ -n "$WEZTERM_EXECUTABLE" ]]; then
        wezterm imgcat "$@"
    elif [[ "$TERM_PROGRAM" == "ghostty" ]] || [[ "$TERM_PROGRAM" == "kitty" ]]; then
        kitten icat "$@"
    else
        loupe "$@"
    fi
}


# ZVM
export ZVM_INSTALL="$HOME/.zvm/self"
export PATH="$PATH:$HOME/.zvm/bin"
export PATH="$PATH:$ZVM_INSTALL/"

#compdef arv

autoload -U is-at-least

_arv() {
    typeset -A opt_args
    typeset -a _arguments_options
    local ret=1

    if is-at-least 5.2; then
        _arguments_options=(-s -S -C)
    else
        _arguments_options=(-s -C)
    fi

    local context curcontext="$curcontext" state line
    _arguments "${_arguments_options[@]}" : \
'-h[Print help]' \
'--help[Print help]' \
'-V[Print version]' \
'--version[Print version]' \
":: :_arv_commands" \
"*::: :->arrive" \
&& ret=0
    case $state in
    (arrive)
        words=($line[1] "${words[@]}")
        (( CURRENT += 1 ))
        curcontext="${curcontext%:*:*}:arv-command-$line[1]:"
        case $line[1] in
            (token)
_arguments "${_arguments_options[@]}" : \
'-h[Print help (see more with '\''--help'\'')]' \
'--help[Print help (see more with '\''--help'\'')]' \
":: :_arv__token_commands" \
"*::: :->token" \
&& ret=0

    case $state in
    (token)
        words=($line[1] "${words[@]}")
        (( CURRENT += 1 ))
        curcontext="${curcontext%:*:*}:arv-token-command-$line[1]:"
        case $line[1] in
            (set)
_arguments "${_arguments_options[@]}" : \
'-h[Print help]' \
'--help[Print help]' \
':token -- Session token to be stored:_default' \
&& ret=0
;;
(show)
_arguments "${_arguments_options[@]}" : \
'-h[Print help]' \
'--help[Print help]' \
&& ret=0
;;
(help)
_arguments "${_arguments_options[@]}" : \
":: :_arv__token__help_commands" \
"*::: :->help" \
&& ret=0

    case $state in
    (help)
        words=($line[1] "${words[@]}")
        (( CURRENT += 1 ))
        curcontext="${curcontext%:*:*}:arv-token-help-command-$line[1]:"
        case $line[1] in
            (set)
_arguments "${_arguments_options[@]}" : \
&& ret=0
;;
(show)
_arguments "${_arguments_options[@]}" : \
&& ret=0
;;
(help)
_arguments "${_arguments_options[@]}" : \
&& ret=0
;;
        esac
    ;;
esac
;;
        esac
    ;;
esac
;;
(input)
_arguments "${_arguments_options[@]}" : \
'-y+[Year to fetch input for]:YEAR:_default' \
'--year=[Year to fetch input for]:YEAR:_default' \
'-d+[Day to fetch input for]:DAY:_default' \
'--day=[Day to fetch input for]:DAY:_default' \
'-f[Force fetch over the web and cache overwrite]' \
'--force[Force fetch over the web and cache overwrite]' \
'-h[Print help (see more with '\''--help'\'')]' \
'--help[Print help (see more with '\''--help'\'')]' \
&& ret=0
;;
(submit)
_arguments "${_arguments_options[@]}" : \
'-h[Print help (see more with '\''--help'\'')]' \
'--help[Print help (see more with '\''--help'\'')]' \
'::solution -- Solution string to be submitted:_default' \
&& ret=0
;;
(select)
_arguments "${_arguments_options[@]}" : \
'-y+[Year to select]:YEAR:_default' \
'--year=[Year to select]:YEAR:_default' \
'-d+[Day to select]:DAY:_default' \
'--day=[Day to select]:DAY:_default' \
'-h[Print help (see more with '\''--help'\'')]' \
'--help[Print help (see more with '\''--help'\'')]' \
&& ret=0
;;
(status)
_arguments "${_arguments_options[@]}" : \
'-h[Print help]' \
'--help[Print help]' \
&& ret=0
;;
(completion)
_arguments "${_arguments_options[@]}" : \
'-h[Print help]' \
'--help[Print help]' \
':shell -- Shell to print completion for:(bash elvish fish powershell zsh)' \
&& ret=0
;;
(help)
_arguments "${_arguments_options[@]}" : \
":: :_arv__help_commands" \
"*::: :->help" \
&& ret=0

    case $state in
    (help)
        words=($line[1] "${words[@]}")
        (( CURRENT += 1 ))
        curcontext="${curcontext%:*:*}:arv-help-command-$line[1]:"
        case $line[1] in
            (token)
_arguments "${_arguments_options[@]}" : \
":: :_arv__help__token_commands" \
"*::: :->token" \
&& ret=0

    case $state in
    (token)
        words=($line[1] "${words[@]}")
        (( CURRENT += 1 ))
        curcontext="${curcontext%:*:*}:arv-help-token-command-$line[1]:"
        case $line[1] in
            (set)
_arguments "${_arguments_options[@]}" : \
&& ret=0
;;
(show)
_arguments "${_arguments_options[@]}" : \
&& ret=0
;;
        esac
    ;;
esac
;;
(input)
_arguments "${_arguments_options[@]}" : \
&& ret=0
;;
(submit)
_arguments "${_arguments_options[@]}" : \
&& ret=0
;;
(select)
_arguments "${_arguments_options[@]}" : \
&& ret=0
;;
(status)
_arguments "${_arguments_options[@]}" : \
&& ret=0
;;
(completion)
_arguments "${_arguments_options[@]}" : \
&& ret=0
;;
(help)
_arguments "${_arguments_options[@]}" : \
&& ret=0
;;
        esac
    ;;
esac
;;
        esac
    ;;
esac
}

(( $+functions[_arv_commands] )) ||
_arv_commands() {
    local commands; commands=(
'token:Manage AOC session token' \
'input:Print selected input file' \
'submit:Submit solution for pending task' \
'select:Select advent day' \
'status:Show current selection, solution status etc' \
'completion:Print shell completion script' \
'help:Print this message or the help of the given subcommand(s)' \
    )
    _describe -t commands 'arv commands' commands "$@"
}
(( $+functions[_arv__completion_commands] )) ||
_arv__completion_commands() {
    local commands; commands=()
    _describe -t commands 'arv completion commands' commands "$@"
}
(( $+functions[_arv__help_commands] )) ||
_arv__help_commands() {
    local commands; commands=(
'token:Manage AOC session token' \
'input:Print selected input file' \
'submit:Submit solution for pending task' \
'select:Select advent day' \
'status:Show current selection, solution status etc' \
'completion:Print shell completion script' \
'help:Print this message or the help of the given subcommand(s)' \
    )
    _describe -t commands 'arv help commands' commands "$@"
}
(( $+functions[_arv__help__completion_commands] )) ||
_arv__help__completion_commands() {
    local commands; commands=()
    _describe -t commands 'arv help completion commands' commands "$@"
}
(( $+functions[_arv__help__help_commands] )) ||
_arv__help__help_commands() {
    local commands; commands=()
    _describe -t commands 'arv help help commands' commands "$@"
}
(( $+functions[_arv__help__input_commands] )) ||
_arv__help__input_commands() {
    local commands; commands=()
    _describe -t commands 'arv help input commands' commands "$@"
}
(( $+functions[_arv__help__select_commands] )) ||
_arv__help__select_commands() {
    local commands; commands=()
    _describe -t commands 'arv help select commands' commands "$@"
}
(( $+functions[_arv__help__status_commands] )) ||
_arv__help__status_commands() {
    local commands; commands=()
    _describe -t commands 'arv help status commands' commands "$@"
}
(( $+functions[_arv__help__submit_commands] )) ||
_arv__help__submit_commands() {
    local commands; commands=()
    _describe -t commands 'arv help submit commands' commands "$@"
}
(( $+functions[_arv__help__token_commands] )) ||
_arv__help__token_commands() {
    local commands; commands=(
'set:Set session token to be used' \
'show:Print currently stored token' \
    )
    _describe -t commands 'arv help token commands' commands "$@"
}
(( $+functions[_arv__help__token__set_commands] )) ||
_arv__help__token__set_commands() {
    local commands; commands=()
    _describe -t commands 'arv help token set commands' commands "$@"
}
(( $+functions[_arv__help__token__show_commands] )) ||
_arv__help__token__show_commands() {
    local commands; commands=()
    _describe -t commands 'arv help token show commands' commands "$@"
}
(( $+functions[_arv__input_commands] )) ||
_arv__input_commands() {
    local commands; commands=()
    _describe -t commands 'arv input commands' commands "$@"
}
(( $+functions[_arv__select_commands] )) ||
_arv__select_commands() {
    local commands; commands=()
    _describe -t commands 'arv select commands' commands "$@"
}
(( $+functions[_arv__status_commands] )) ||
_arv__status_commands() {
    local commands; commands=()
    _describe -t commands 'arv status commands' commands "$@"
}
(( $+functions[_arv__submit_commands] )) ||
_arv__submit_commands() {
    local commands; commands=()
    _describe -t commands 'arv submit commands' commands "$@"
}
(( $+functions[_arv__token_commands] )) ||
_arv__token_commands() {
    local commands; commands=(
'set:Set session token to be used' \
'show:Print currently stored token' \
'help:Print this message or the help of the given subcommand(s)' \
    )
    _describe -t commands 'arv token commands' commands "$@"
}
(( $+functions[_arv__token__help_commands] )) ||
_arv__token__help_commands() {
    local commands; commands=(
'set:Set session token to be used' \
'show:Print currently stored token' \
'help:Print this message or the help of the given subcommand(s)' \
    )
    _describe -t commands 'arv token help commands' commands "$@"
}
(( $+functions[_arv__token__help__help_commands] )) ||
_arv__token__help__help_commands() {
    local commands; commands=()
    _describe -t commands 'arv token help help commands' commands "$@"
}
(( $+functions[_arv__token__help__set_commands] )) ||
_arv__token__help__set_commands() {
    local commands; commands=()
    _describe -t commands 'arv token help set commands' commands "$@"
}
(( $+functions[_arv__token__help__show_commands] )) ||
_arv__token__help__show_commands() {
    local commands; commands=()
    _describe -t commands 'arv token help show commands' commands "$@"
}
(( $+functions[_arv__token__set_commands] )) ||
_arv__token__set_commands() {
    local commands; commands=()
    _describe -t commands 'arv token set commands' commands "$@"
}
(( $+functions[_arv__token__show_commands] )) ||
_arv__token__show_commands() {
    local commands; commands=()
    _describe -t commands 'arv token show commands' commands "$@"
}

if [ "$funcstack[1]" = "_arv" ]; then
    _arv "$@"
else
    compdef _arv arv
fi

aoci() {
    local script_path="$HOME/dotfiles/zsh/aoci.sh"
    
    if [[ -x "$script_path" ]]; then
        "$script_path" "$@"
    else
        echo "Error: aoci.sh not found or not executable at $script_path"
        return 1
    fi
}

notes() {
    local script_path="$HOME/dotfiles/zsh/notes.sh"
    
    if [[ -x "$script_path" ]]; then
        "$script_path" "$@"
    else
        echo "Error: notes.sh not found or not executable at $script_path"
        return 1
    fi
}

source $HOME/dotfiles/zsh/forgeprj.sh
