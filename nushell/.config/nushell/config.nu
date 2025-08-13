
# Environment variables
$env.EDITOR = "nvim"
$env.POP_SMTP_HOST = "smtp.gmail.com"
$env.POP_SMTP_PORT = "587"
$env.LD_LIBRARY_PATH = "/lib/x86_64-linux-gnu"
$env.NAP_CONFIG = "~/.nap/config.yaml"
$env.NAP_HOME = "~/.nap"
$env.NAP_DEFAULT_LANGUAGE = "ino"
$env.NAP_THEME = "catppuccin-mocha"

# Catppuccin colors for NAP
$env.NAP_PRIMARY_COLOR = "#CBA6F7"  # Mauve
$env.NAP_RED = "#EBA0AC"           # Maroon
$env.NAP_GREEN = "#A6E3A1"         # Green
$env.NAP_FOREGROUND = "#CDD6F4"    # Text
$env.NAP_BACKGROUND = "#1E1E2E"    # Base
$env.NAP_BLACK = "#181825"         # Mantle
$env.NAP_GRAY = "#585B70"          # Surface2
$env.NAP_WHITE = "#F5E0DC"         # Rosewater

$env.NVM_DIR = $"($env.HOME)/.nvm"
$env.ZEIT_DB = "/home/vaishnav/zeit_db/zeit.db"
$env.RUSTONIG_SYSTEM_LIBONIG = "1"

# PATH configuration - using static paths due to Nushell parsing constraints
$env.PATH = ($env.PATH | split row (char esep) | append [
    "/usr/local/bin"
    "/usr/local/go/bin" 
    "/home/vaishnav/.cargo/bin"
    "/home/vaishnav/.nimble/bin"
    "/home/vaishnav/go/bin"
    "/home/vaishnav/.modular/bin"
    "/home/vaishnav/.deno/bin"
    "/home/vaishnav/.local/bin"
    "/home/vaishnav/.local/lib/python3.13"
    "/home/vaishnav/.basher/bin"
    "/home/vaishnav/bin"
    "/opt/nvim-linux-x86_64/bin"
    "/home/vaishnav/zig-x86_64-linux-0.15.0-dev.936+fc2c1883b"
    "/home/vaishnav/.rustup/toolchains/esp/xtensa-esp-elf/esp-14.2.0_20240906/xtensa-esp-elf/bin"
    "/home/linuxbrew/.linuxbrew/bin"
] | uniq)

$env.LIBCLANG_PATH = "/home/vaishnav/.rustup/toolchains/esp/xtensa-esp32-elf-clang/esp-19.1.2_20250225/esp-clang/lib"

# Note: Conditional sourcing needs to be handled differently in Nushell
# You can manually source these files if they exist:
# source ~/.zsh_secrets
# source ~/.deno/env

# For dynamic loading, you might need to use a startup script or
# check these files manually

# Aliases
alias ll = ls -la
alias gs = git status  
alias ga = git add
alias type_test = /home/vaishnav/typer/typer
alias confetty = /home/vaishnav/go/bin/confetty
alias draw = /home/vaishnav/go/bin/draw
alias glyph = /home/vaishnav/go/bin/glyphs
alias cat = bat
alias pdf = evince
alias pic = eog
alias japanese = /home/vaishnav/japanese_class.sh
alias tm = /home/vaishnav/taskcli/tm
alias chess = /home/vaishnav/go/bin/gambit
def get_pio [] {
    # Set up PlatformIO environment variables manually
    # You may need to adjust these paths based on your PlatformIO installation
    let pio_venv_path = "~/.platformio/penv"
    
    if ($pio_venv_path | path expand | path exists) {
        $env.PATH = ($env.PATH | split row (char esep) | prepend $"($pio_venv_path | path expand)/bin" | uniq)
        $env.VIRTUAL_ENV = ($pio_venv_path | path expand)
        print "PlatformIO environment activated"
    } else {
        print "PlatformIO virtual environment not found"
    }
}
alias teensy = /home/vaishnav/Teensy_Loader/teensy
alias cutecom = /home/vaishnav/cutecom/cutecom
alias tree = eza --icons --hyperlink --tree
alias img = loupe
alias preview_md = gh markdown-preview
# temp_share_local function (ssh with complex arguments)
def temp_share_local [] {
    ssh -R 80:localhost:8888 nokey@localhost.run
}

# Custom functions

# QR code generator
def qr [link: string] {
    curl $"qrenco.de/($link)"
}

# File upload with QR
def file_upload [file: path] {
    let link = (ffsend upload $file | parse --regex 'https://[^\s]*' | get capture0.0)
    print ""
    curl $"qrenco.de/($link)"
}

# Mojo project creator
def mojo_project [project_name: string] {
    magic init $project_name --format mojoproject
    rm -rf $"($project_name)/.gitignore"
    rm -rf $"($project_name)/.gitattributes"
}

# Git add, commit, push with gum interface
def acp [] {
    # Check if gum is installed
    if not (which gum | is-not-empty) {
        print "Error: gum is not installed. Please install it from https://github.com/charmbracelet/gum"
        return
    }

    # Stage all changes
    git add .

    # Get commit message
    let commit_msg = (gum input --placeholder "commit message" | str trim)
    if ($commit_msg | is-empty) {
        print "Error: Commit message cannot be empty"
        return
    }

    # Commit changes
    git commit -m $commit_msg

    # Get branch selection
    let branches = (git branch | str replace "* " "" | str trim)
    let branch = (echo $branches | gum choose | str trim)
    if ($branch | is-empty) {
        print "Error: Branch name cannot be empty"
        return
    }

    # Checkout the branch
    git checkout $branch

    # Get all remotes and push to each
    let remotes = (git remote | lines)
    for remote in $remotes {
        print $"Pushing to remote - ($remote)"
        git push $remote $branch
    }

    print "Changes added, committed, and pushed to all remotes"
}

# Pomodoro timer
def pomodoro [session_type: string] {
    let pomo_options = {
        work: 25,
        break: 10
    }
    
    if ($session_type in $pomo_options) {
        let duration = ($pomo_options | get $session_type)
        print $session_type | lolcat
        timer $"($duration)m"
        notify-send $"'($session_type)' session done"
        spd-say $"'($session_type)' session done"
    }
}

alias wo = pomodoro work
alias br = pomodoro break

# Tere directory navigation
def --env tere [...args] {
    let result = (command tere ...$args)
    if not ($result | is-empty) {
        cd $result
    }
}

# Form management functions
def form_create [] {
    if not (which gum | is-not-empty) {
        print "Error: gum is not installed"
        return
    }
    
    let num_questions = (gum input --prompt "Enter number of questions: " --placeholder "e.g., 5")
    if not ($num_questions | str trim | parse --regex '^\d+$' | is-not-empty) {
        print "Error: Please enter a valid positive number"
        return
    }
    
    let code = (gum input --prompt "Enter form code: " --placeholder "e.g., myform123")
    if ($code | str trim | is-empty) {
        print "Error: Code cannot be empty"
        return
    }
    
    ssh -t bashform.me create $num_questions $code
}

def ans_form [] {
    if not (which gum | is-not-empty) {
        print "Error: gum is not installed"
        return
    }
    
    let code = (gum input --prompt "Enter form code: " --placeholder "e.g., myform123")
    if ($code | str trim | is-empty) {
        print "Error: Code cannot be empty"
        return
    }
    
    ssh -t bashform.me form $code
}

def view_forms [] {
    ssh -t bashform.me forms
}

# PDF management system
def pdf_manager [] {
    if not (which gum | is-not-empty) {
        print "Error: gum is not installed. Install it with: brew install gum"
        return
    }

    let action = (["Merge PDFs", "Separate PDF", "Remove Pages from PDF"] | gum choose)
    
    match $action {
        "Merge PDFs" => { merge_pdfs },
        "Separate PDF" => { separate_pdf },
        "Remove Pages from PDF" => { remove_pages },
        _ => { print "Operation cancelled" }
    }
}

def merge_pdfs [] {
    print "📚 Merging PDFs"
    
    let pdf_files = (ls *.pdf | get name 2>/dev/null)
    if ($pdf_files | is-empty) {
        print "❌ No PDF files found in current directory"
        return
    }
    
    let selected_files = ($pdf_files | gum choose --no-limit | lines)
    if ($selected_files | is-empty) {
        print "❌ No files selected"
        return
    }
    
    let output_file = (gum input --placeholder "Enter output filename (e.g., merged.pdf)")
    if ($output_file | is-empty) {
        print "❌ No output filename provided"
        return
    }
    
    let output_file = if not ($output_file | str ends-with ".pdf") { 
        $"($output_file).pdf" 
    } else { 
        $output_file 
    }
    
    print "Selected files:"
    for file in $selected_files {
        print $"  - ($file)"
    }
    print $"Output: ($output_file)"
    
    if (gum confirm "Proceed with merge?") {
        pdfunite ...$selected_files $output_file
        print $"✅ PDFs merged successfully: ($output_file)"
    } else {
        print "❌ Merge cancelled"
    }
}

def separate_pdf [] {
    print "📄 Separating PDF"
    
    let pdf_files = (ls *.pdf | get name 2>/dev/null)
    if ($pdf_files | is-empty) {
        print "❌ No PDF files found in current directory"
        return
    }
    
    let input_file = ($pdf_files | gum choose)
    if ($input_file | is-empty) {
        print "❌ No file selected"
        return
    }
    
    let base_name = (gum input --placeholder "Enter base name for output files (default: page)" --value "page")
    let base_name = if ($base_name | is-empty) { "page" } else { $base_name }
    
    if (gum confirm $"Separate ($input_file) into individual pages?") {
        pdfseparate $input_file $"($base_name)-%d.pdf"
        print $"✅ PDF separated successfully with pattern: ($base_name)-%d.pdf"
    } else {
        print "❌ Separation cancelled"
    }
}

def remove_pages [] {
    print "✂️  Removing Pages from PDF"
    
    let pdf_files = (ls *.pdf | get name 2>/dev/null)
    if ($pdf_files | is-empty) {
        print "❌ No PDF files found in current directory"
        return
    }
    
    let input_file = ($pdf_files | gum choose)
    if ($input_file | is-empty) {
        print "❌ No file selected"
        return
    }
    
    # Get total pages if pdfinfo is available
    let total_pages = if (which pdfinfo | is-not-empty) {
        let info = (pdfinfo $input_file | parse --regex 'Pages:\s+(\d+)' | get capture0.0 | first)
        print $"📊 Total pages in ($input_file): ($info)"
        $info | into int
    } else {
        print "⚠️  pdfinfo not available. Cannot show page count."
        gum input --placeholder "Enter total number of pages in the PDF" | into int
    }
    
    let pages_to_remove = (gum input --placeholder "Enter page numbers to remove (e.g., 2,5,7-9)")
    if ($pages_to_remove | is-empty) {
        print "❌ No pages specified"
        return
    }
    
    let output_file = (gum input --placeholder "Enter output filename" --value $"(($input_file | path parse).stem)_modified.pdf")
    if ($output_file | is-empty) {
        print "❌ No output filename provided"
        return
    }
    
    let output_file = if not ($output_file | str ends-with ".pdf") { 
        $"($output_file).pdf" 
    } else { 
        $output_file 
    }
    
    print $"Input: ($input_file)"
    print $"Pages to remove: ($pages_to_remove)"
    print $"Output: ($output_file)"
    
    if (gum confirm "Proceed with page removal?") {
        let temp_dir = (mktemp -d)
        let base_name = "temp_page"
        
        print "🔄 Separating pages..."
        pdfseparate $input_file $"($temp_dir)/($base_name)-%d.pdf"
        
        # Parse pages to remove and build keep list
        let remove_parts = ($pages_to_remove | split row ",")
        mut pages_to_remove_array = []
        
        for part in $remove_parts {
            let part = ($part | str trim)
            if ($part | str contains "-") {
                let range = ($part | split row "-")
                let start = ($range.0 | into int)
                let end = ($range.1 | into int)
                for i in $start..$end {
                    $pages_to_remove_array = ($pages_to_remove_array | append $i)
                }
            } else {
                $pages_to_remove_array = ($pages_to_remove_array | append ($part | into int))
            }
        }
        
        mut pages_to_keep = []
        for i in 1..$total_pages {
            if not ($i in $pages_to_remove_array) {
                let page_file = $"($temp_dir)/($base_name)-($i).pdf"
                if ($page_file | path exists) {
                    $pages_to_keep = ($pages_to_keep | append $page_file)
                }
            }
        }
        
        if ($pages_to_keep | is-empty) {
            print "❌ No pages would remain after removal"
            rm -rf $temp_dir
            return
        }
        
        print "🔄 Merging remaining pages..."
        pdfunite ...$pages_to_keep $output_file
        
        rm -rf $temp_dir
        
        let kept_pages = ($total_pages - ($pages_to_remove_array | length))
        print $"✅ Pages removed successfully: ($output_file)"
        print $"📊 Kept ($kept_pages) of ($total_pages) pages"
    } else {
        print "❌ Operation cancelled"
    }
}

# Disk usage warning
let threshold = 80
let usage = (df -h / | lines | skip 1 | first | split row " " | where $it != "" | get 4 | str replace "%" "" | into int)

if $usage >= $threshold {
    print $"Warning: Disk usage is at ($usage)%!"
} else {
    print "Disk usage is under control."
}

# Print newline for spacing
print ""


$env.config.show_banner = false
$env.config.buffer_editor = "nvim"
mkdir ($nu.data-dir | path join "vendor/autoload")
$env.STARSHIP_CONFIG = "/home/vaishnav/.config/starship-nu.toml"
starship init nu | save -f ($nu.data-dir | path join "vendor/autoload/starship.nu")
