#!/usr/bin/env bash

# Gist Manager - Interactive gist creation and management using gum
# Requires: gh CLI, gum, git

set -e

# Colors and styling
export GUM_CHOOSE_CURSOR_FOREGROUND="#FF6B9D"
export GUM_CHOOSE_SELECTED_FOREGROUND="#C6A0F6"
export GUM_INPUT_CURSOR_FOREGROUND="#8BD5CA"
export GUM_INPUT_PROMPT_FOREGROUND="#F4DBD6"
export GUM_CONFIRM_PROMPT_FOREGROUND="#A6DA95"

# Functions
show_header() {
  gum style \
    --foreground 212 --border-foreground 212 --border double \
    --align center --width 50 --margin "1 2" --padding "1 2" \
    "🎀 Gist Manager 🎀" "Interactive GitHub Gist Workflow"
}

create_new_gist() {
  echo ""
  gum style --foreground 99 "Creating a new gist..."

  # Get description
  DESCRIPTION=$(gum input --placeholder "Enter gist description" --prompt "Description: ")

  # Choose visibility
  VISIBILITY=$(gum choose --header "Choose visibility:" "Public" "Secret")

  # Choose files to include
  echo ""
  gum style --foreground 147 "Select files to include in the gist:"

  # File selection method
  FILE_METHOD=$(gum choose --header "How do you want to add files?" "Select existing files" "Create new files")

  FILES=()

  if [[ "$FILE_METHOD" == "Select existing files" ]]; then
    # Get all files in current directory (including hidden files)
    ALL_FILES=()

    # Use find to get all files in current directory
    while IFS= read -r -d '' file; do
      # Skip . and .. directories
      if [[ "$file" != "./." && "$file" != "./.." ]]; then
        # Remove the ./ prefix for cleaner display
        clean_file="${file#./}"
        ALL_FILES+=("$clean_file")
      fi
    done < <(find . -maxdepth 1 -type f -print0 2>/dev/null)

    if [[ ${#ALL_FILES[@]} -eq 0 ]]; then
      gum style --foreground 196 "No files found in current directory."
      echo "Current directory: $(pwd)"
      echo ""
      if gum confirm "Continue with creating new files instead?"; then
        FILE_METHOD="Create new files"
      else
        return 1
      fi
    else
      echo ""
      gum style --foreground 147 "Found ${#ALL_FILES[@]} files in current directory"
      echo ""

      # Use gum choose with --no-limit for multiple selection
      # Note: gum choose with --no-limit allows space/tab to select multiple items
      SELECTED_FILES=$(printf '%s\n' "${ALL_FILES[@]}" | gum choose --no-limit --header "Select files (use SPACE to select multiple, ENTER to confirm):")

      # Convert selected files to array
      if [[ -n "$SELECTED_FILES" ]]; then
        while IFS= read -r file; do
          if [[ -f "$file" ]]; then
            FILES+=("$file")
            echo "✅ Selected: $file"
          fi
        done <<<"$SELECTED_FILES"
      fi

      if [[ ${#FILES[@]} -eq 0 ]]; then
        gum style --foreground 196 "No files selected."
        if gum confirm "Continue with creating new files instead?"; then
          FILE_METHOD="Create new files"
        else
          return 1
        fi
      fi
    fi
  fi

  if [[ "$FILE_METHOD" == "Create new files" ]]; then
    # Create new files interactively
    while true; do
      FILENAME=$(gum input --placeholder "filename.ext" --prompt "New file name: ")
      if [[ -n "$FILENAME" ]]; then
        echo ""
        gum style --foreground 147 "Enter content for $FILENAME:"
        CONTENT=$(gum write --placeholder "Enter file content..." --height 10)
        echo "$CONTENT" >"$FILENAME"
        FILES+=("$FILENAME")
        echo "✅ Created: $FILENAME"

        ADD_MORE=$(gum confirm "Create another file?" && echo "yes" || echo "no")
        if [[ "$ADD_MORE" == "no" ]]; then
          break
        fi
      else
        break
      fi
    done
  fi

  if [[ ${#FILES[@]} -eq 0 ]]; then
    gum style --foreground 196 "No files selected. Exiting."
    return 1
  fi

  # Show selected files
  echo ""
  gum style --foreground 147 "Selected files (${#FILES[@]}):"
  printf ' • %s\n' "${FILES[@]}"
  echo ""

  # Confirm before creating
  if ! gum confirm "Create gist with these files?"; then
    gum style --foreground 147 "Cancelled."
    return 1
  fi

  # Build gh command
  GH_CMD="gh gist create"

  if [[ "$VISIBILITY" == "Public" ]]; then
    GH_CMD="$GH_CMD --public"
  fi

  if [[ -n "$DESCRIPTION" ]]; then
    GH_CMD="$GH_CMD -d \"$DESCRIPTION\""
  fi

  # Add files
  for file in "${FILES[@]}"; do
    GH_CMD="$GH_CMD \"$file\""
  done

  echo ""
  gum style --foreground 147 "Creating gist..."
  echo ""

  # Create the gist
  if gum spin --spinner dot --title "Creating gist..." -- bash -c "$GH_CMD"; then
    echo ""
    gum style --foreground 46 "✅ Gist created successfully!"

    # Show created gist URL
    GIST_URL=$(gh gist list --limit 1 | head -n1 | awk '{print "https://gist.github.com/" $1}')
    if [[ -n "$GIST_URL" ]]; then
      echo "🔗 URL: $GIST_URL"
    fi
  else
    gum style --foreground 196 "❌ Failed to create gist"
    return 1
  fi
}

clone_gist() {
  echo ""
  gum style --foreground 99 "Clone an existing gist"

  # Get gist URL or ID
  GIST_INPUT=$(gum input --placeholder "https://gist.github.com/user/gist_id or just gist_id" --prompt "Gist URL/ID: ")

  if [[ -z "$GIST_INPUT" ]]; then
    gum style --foreground 196 "No gist provided. Exiting."
    return
  fi

  # Extract gist ID from URL if needed
  if [[ "$GIST_INPUT" =~ https://gist\.github\.com/.*/([a-f0-9]+) ]]; then
    GIST_ID="${BASH_REMATCH[1]}"
  else
    GIST_ID="$GIST_INPUT"
  fi

  # Optional: specify directory name
  CLONE_DIR=$(gum input --placeholder "Leave empty for default" --prompt "Clone directory name (optional): ")

  # Build clone command
  CLONE_CMD="gh gist clone $GIST_ID"
  if [[ -n "$CLONE_DIR" ]]; then
    CLONE_CMD="$CLONE_CMD $CLONE_DIR"
  fi

  echo ""
  gum style --foreground 147 "Cloning with command:"
  echo "$CLONE_CMD"
  echo ""

  # Clone the gist
  if gum spin --spinner dot --title "Cloning gist..." -- bash -c "$CLONE_CMD"; then
    echo ""
    gum style --foreground 46 "✅ Gist cloned successfully!"

    # Show directory info
    if [[ -n "$CLONE_DIR" ]]; then
      TARGET_DIR="$CLONE_DIR"
    else
      TARGET_DIR="$GIST_ID"
    fi

    echo "📁 Location: ./$TARGET_DIR"
    echo ""

    # Ask if user wants to cd into directory
    if gum confirm "Open directory in current shell?"; then
      echo "cd $TARGET_DIR"
      exec bash -c "cd $TARGET_DIR && exec bash"
    fi
  else
    gum style --foreground 196 "❌ Failed to clone gist"
  fi
}

manage_existing_gist() {
  echo ""
  gum style --foreground 99 "Manage existing gists"

  echo ""
  gum style --foreground 147 "Fetching your gists..."

  GISTS_OUTPUT=$(gh gist list --limit 50 2>/dev/null)

  if [[ -z "$GISTS_OUTPUT" ]]; then
    gum style --foreground 196 "No gists found."
    echo ""
    echo "Possible reasons:"
    echo "• You haven't created any gists yet"
    echo "• Authentication issues (try: gh auth refresh -s gist)"
    echo "• Try: gh gist list"
    return
  fi

  GIST_OPTIONS=()
  while IFS= read -r line; do
    if [[ "$line" =~ ^[a-f0-9]{32} ]]; then
      gist_id="${line:0:32}"

      # USE POSITION 33 (not 34!) - this preserves the first character
      rest="${line:33}"

      # Clean description by removing trailing metadata
      description=$(echo "$rest" | sed -E 's/[[:space:]]+[0-9]+[[:space:]]+files?[[:space:]]+[a-z]+[[:space:]]+.*$//' | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')

      # Handle empty descriptions
      if [[ -z "$description" ]]; then
        description="(no description)"
      fi

      GIST_OPTIONS+=("$gist_id: $description")
    fi
  done <<<"$GISTS_OUTPUT"

  if [[ ${#GIST_OPTIONS[@]} -eq 0 ]]; then
    gum style --foreground 196 "No gists available."
    return
  fi

  echo ""
  gum style --foreground 147 "Found ${#GIST_OPTIONS[@]} gist(s)"

  # Better display options
  SELECTED_GIST=$(gum choose --header "Select a gist to manage:" --height 10 "${GIST_OPTIONS[@]}")
  SELECTED_GIST_ID=$(echo "$SELECTED_GIST" | cut -d':' -f1 | tr -d '[:space:]')

  # Choose action
  ACTION=$(gum choose --header "What would you like to do?" "Clone locally" "Edit gist" "View gist" "Delete gist")

  case "$ACTION" in
  "Clone locally")
    CLONE_DIR=$(gum input --placeholder "Leave empty for gist ID" --prompt "Clone directory name: ")
    CLONE_CMD="gh gist clone $SELECTED_GIST_ID"
    if [[ -n "$CLONE_DIR" ]]; then
      CLONE_CMD="$CLONE_CMD $CLONE_DIR"
    fi
    echo ""
    if gum spin --spinner dot --title "Cloning gist..." -- bash -c "$CLONE_CMD"; then
      gum style --foreground 46 "✅ Gist cloned successfully!"
      [[ -n "$CLONE_DIR" ]] && echo "📁 Location: ./$CLONE_DIR" || echo "📁 Location: ./$SELECTED_GIST_ID"
    else
      gum style --foreground 196 "❌ Failed to clone gist"
    fi
    ;;
  "Edit gist")
    gh gist edit "$SELECTED_GIST_ID"
    ;;
  "View gist")
    echo ""
    gh gist view "$SELECTED_GIST_ID"
    ;;
  "Delete gist")
    if gum confirm "Are you sure you want to delete this gist?"; then
      if gh gist delete "$SELECTED_GIST_ID" --confirm; then
        gum style --foreground 46 "✅ Gist deleted"
      else
        gum style --foreground 196 "❌ Failed to delete gist"
      fi
    fi
    ;;
  esac
}

# Check dependencies
check_dependencies() {
  local missing=()

  command -v gh >/dev/null 2>&1 || missing+=("gh (GitHub CLI)")
  command -v gum >/dev/null 2>&1 || missing+=("gum")
  command -v git >/dev/null 2>&1 || missing+=("git")
  command -v find >/dev/null 2>&1 || missing+=("find")

  if [[ ${#missing[@]} -gt 0 ]]; then
    gum style --foreground 196 "Missing dependencies:"
    printf '%s\n' "${missing[@]}"
    echo ""
    gum style --foreground 147 "Install missing dependencies and try again."
    exit 1
  fi

  # Check gh auth
  if ! gh auth status >/dev/null 2>&1; then
    gum style --foreground 196 "GitHub CLI not authenticated."
    echo "Run: gh auth login"
    exit 1
  fi
}

# Main menu
main_menu() {
  while true; do
    clear
    show_header
    echo ""

    CHOICE=$(gum choose --header "What would you like to do?" \
      "Create new gist" \
      "Clone existing gist" \
      "Manage my gists" \
      "Exit")

    case "$CHOICE" in
    "Create new gist")
      create_new_gist
      ;;
    "Clone existing gist")
      clone_gist
      ;;
    "Manage my gists")
      manage_existing_gist
      ;;
    "Exit")
      echo ""
      gum style --foreground 147 "Goodbye! 👋"
      exit 0
      ;;
    esac

    echo ""
    gum style --foreground 147 "Press any key to continue..."
    read -n 1 -s
  done
}

# Main execution
main() {
  check_dependencies
  main_menu
}

# Handle arguments
if [[ "$1" == "--help" || "$1" == "-h" ]]; then
  echo "Gist Manager - Interactive GitHub Gist Workflow"
  echo ""
  echo "Usage: $0 [--help]"
  echo ""
  echo "This script provides an interactive TUI for:"
  echo "- Creating new gists with multiple files (use SPACE to select multiple)"
  echo "- Cloning gists by URL or ID"
  echo "- Managing existing gists"
  echo ""
  echo "Requirements: gh, gum, git, find"
  exit 0
fi

main "$@"
