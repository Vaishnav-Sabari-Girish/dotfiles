#!/usr/bin/env bash

# Gist Manager - Interactive gist creation and management using gum
# Uses git workflow instead of gh gist edit for maximum flexibility
# Requires: gh CLI, gum, git

set -e

# Colors and styling
export GUM_CHOOSE_CURSOR_FOREGROUND="#FF6B9D"
export GUM_CHOOSE_SELECTED_FOREGROUND="#C6A0F6"
export GUM_INPUT_CURSOR_FOREGROUND="#8BD5CA"
export GUM_INPUT_PROMPT_FOREGROUND="#F4DBD6"
export GUM_CONFIRM_PROMPT_FOREGROUND="#A6DA95"

# Your custom acp function integrated
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

# Functions
show_header() {
  gum style \
    --foreground 212 --border-foreground 212 --border double \
    --align center --width 50 --margin "1 2" --padding "1 2" \
    "🎀 Gist Manager 🎀" "Interactive GitHub Gist Workflow (Git-based)"
}

# Function to get files currently in gist (clean display)
get_gist_files() {
  local gist_id="$1"

  # Get files from gist view
  gh gist view "$gist_id" --files 2>/dev/null | while IFS= read -r line; do
    # Clean up the output - just show filenames
    if [[ -n "$line" && "$line" != "no files" ]]; then
      echo "$line"
    fi
  done
}

# Function to detect new files in current directory
detect_new_files() {
  echo ""
  gum style --foreground 147 "Checking for new files in current directory..."

  # Get all files in current directory
  ALL_FILES=()
  while IFS= read -r -d '' file; do
    if [[ "$file" != "./." && "$file" != "./.." ]]; then
      clean_file="${file#./}"
      # Skip hidden files and directories, and exclude common temp/system files
      if [[ ! "$clean_file" =~ ^\. && ! "$clean_file" =~ ^temp_gist_ && -f "$clean_file" ]]; then
        ALL_FILES+=("$clean_file")
      fi
    fi
  done < <(find . -maxdepth 1 -type f -print0 2>/dev/null)

  # Get files already in gist (from current working directory)
  EXISTING_FILES=()
  if [[ -d ".git" ]]; then
    while IFS= read -r file; do
      if [[ -n "$file" ]]; then
        EXISTING_FILES+=("$file")
      fi
    done < <(git ls-files 2>/dev/null)
  fi

  # Find new files (files that exist but are not tracked)
  NEW_FILES=()
  for file in "${ALL_FILES[@]}"; do
    local is_tracked=false
    for existing in "${EXISTING_FILES[@]}"; do
      if [[ "$file" == "$existing" ]]; then
        is_tracked=true
        break
      fi
    done
    if [[ "$is_tracked" == false ]]; then
      NEW_FILES+=("$file")
    fi
  done

  echo "${#NEW_FILES[@]}"
  printf '%s\n' "${NEW_FILES[@]}"
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

update_gist_with_git() {
  local gist_id="$1"
  echo ""
  gum style --foreground 99 "Update gist using Git workflow: $gist_id"

  # Show current gist files in a clean format
  echo ""
  gum style --foreground 147 "Files currently in gist:"
  CURRENT_FILES=$(get_gist_files "$gist_id")
  if [[ -n "$CURRENT_FILES" ]]; then
    echo "$CURRENT_FILES" | while IFS= read -r file; do
      echo " • $file"
    done
  else
    echo " (no files found)"
  fi
  echo ""

  # Check if we're already in a gist directory
  if [[ -d ".git" ]] && git remote -v | grep -q "gist.github.com.*$gist_id"; then
    gum style --foreground 147 "Already in gist directory. Ready to update!"
    UPDATE_IN_PLACE=true
    GIST_DIR="."
  else
    UPDATE_IN_PLACE=false

    # Clone the gist to work with it
    GIST_DIR="temp_gist_$gist_id"
    if [[ -d "$GIST_DIR" ]]; then
      rm -rf "$GIST_DIR"
    fi

    echo ""
    gum style --foreground 147 "Cloning gist to temporary directory..."
    if ! gum spin --spinner dot --title "Cloning gist..." -- gh gist clone "$gist_id" "$GIST_DIR"; then
      gum style --foreground 196 "❌ Failed to clone gist"
      return 1
    fi
  fi

  # Change to gist directory
  if [[ "$UPDATE_IN_PLACE" == false ]]; then
    cd "$GIST_DIR" || return 1
  fi

  # Go back to original directory to check for new files
  if [[ "$UPDATE_IN_PLACE" == false ]]; then
    cd ..
  fi

  # Detect new files
  NEW_FILE_INFO=$(detect_new_files)
  NEW_FILE_COUNT=$(echo "$NEW_FILE_INFO" | head -n1)
  NEW_FILES_LIST=$(echo "$NEW_FILE_INFO" | tail -n +2)

  # Go back to gist directory
  if [[ "$UPDATE_IN_PLACE" == false ]]; then
    cd "$GIST_DIR" || return 1
  fi

  # Build menu options based on detected new files
  MENU_OPTIONS=()

  if [[ $NEW_FILE_COUNT -gt 0 ]]; then
    MENU_OPTIONS+=("Add new files ($NEW_FILE_COUNT files)")
  fi

  MENU_OPTIONS+=("Create new files")
  MENU_OPTIONS+=("Edit existing files")
  MENU_OPTIONS+=("Remove files")
  MENU_OPTIONS+=("Update and push changes")
  MENU_OPTIONS+=("Cancel")

  # Show new files summary
  if [[ $NEW_FILE_COUNT -gt 0 ]]; then
    echo ""
    gum style --foreground 147 "New files detected in directory:"
    echo "$NEW_FILES_LIST" | while IFS= read -r file; do
      if [[ -n "$file" ]]; then
        echo " • $file"
      fi
    done
    echo ""
  else
    echo ""
    gum style --foreground 147 "No new files detected in current directory."
    echo ""
  fi

  # Choose what to update
  UPDATE_ACTION=$(gum choose --header "What would you like to update?" "${MENU_OPTIONS[@]}")

  case "$UPDATE_ACTION" in
  "Add new files"*)
    add_new_files "$NEW_FILES_LIST"
    ;;
  "Create new files")
    create_new_files_in_gist
    ;;
  "Edit existing files")
    edit_files_in_gist
    ;;
  "Remove files")
    remove_files_from_gist
    ;;
  "Update and push changes")
    push_gist_changes
    ;;
  "Cancel")
    cleanup_temp_dir
    return 0
    ;;
  esac

  # Ask if user wants to continue making changes
  echo ""
  if gum confirm "Make additional changes?"; then
    update_gist_with_git "$gist_id"
  else
    # Final push option
    echo ""
    if gum confirm "Push all changes now?"; then
      push_gist_changes
    fi
    cleanup_temp_dir
  fi
}

add_new_files() {
  local new_files_list="$1"
  echo ""
  gum style --foreground 147 "Add new files to gist"

  if [[ -z "$new_files_list" ]]; then
    gum style --foreground 196 "No new files to add."
    return 1
  fi

  # Convert to array for selection
  NEW_FILES_ARRAY=()
  while IFS= read -r file; do
    if [[ -n "$file" ]]; then
      NEW_FILES_ARRAY+=("$file")
    fi
  done <<<"$new_files_list"

  if [[ ${#NEW_FILES_ARRAY[@]} -eq 0 ]]; then
    gum style --foreground 196 "No new files available."
    return 1
  fi

  echo ""
  gum style --foreground 147 "Available new files:"
  printf ' • %s\n' "${NEW_FILES_ARRAY[@]}"
  echo ""

  # Allow user to select which new files to add
  SELECTED_FILES=$(printf '%s\n' "${NEW_FILES_ARRAY[@]}" | gum choose --no-limit --header "Select new files to add (use SPACE to select multiple):")

  if [[ -n "$SELECTED_FILES" ]]; then
    echo ""
    gum style --foreground 147 "Selected files to add:"
    echo "$SELECTED_FILES" | while IFS= read -r file; do
      echo " • $file"
    done
    echo ""

    if gum confirm "Add these files to the gist?"; then
      echo ""
      # Copy selected files from parent directory
      while IFS= read -r file; do
        if [[ -n "$file" && -f "../$file" ]]; then
          cp "../$file" .
          echo "✅ Added: $file"
        fi
      done <<<"$SELECTED_FILES"
      echo ""
      gum style --foreground 147 "Files added. Use 'Update and push changes' to save to gist."
    fi
  else
    gum style --foreground 147 "No files selected."
  fi
}

create_new_files_in_gist() {
  echo ""
  gum style --foreground 147 "Create new files in gist"

  # Create new files in gist directory
  while true; do
    FILENAME=$(gum input --placeholder "filename.ext" --prompt "New file name: ")
    if [[ -n "$FILENAME" ]]; then
      echo ""
      gum style --foreground 147 "Enter content for $FILENAME:"
      CONTENT=$(gum write --placeholder "Enter file content..." --height 10)
      echo "$CONTENT" >"$FILENAME"
      echo "✅ Created: $FILENAME"

      ADD_MORE=$(gum confirm "Create another file?" && echo "yes" || echo "no")
      if [[ "$ADD_MORE" == "no" ]]; then
        break
      fi
    else
      break
    fi
  done

  echo ""
  gum style --foreground 147 "Files created. Use 'Update and push changes' to save to gist."
}

edit_files_in_gist() {
  echo ""
  gum style --foreground 147 "Edit files in gist"

  # Get list of files in current directory (excluding .git and directories)
  FILES=(*)
  ACTUAL_FILES=()
  for file in "${FILES[@]}"; do
    if [[ -f "$file" && "$file" != ".git" ]]; then
      ACTUAL_FILES+=("$file")
    fi
  done

  if [[ ${#ACTUAL_FILES[@]} -eq 0 ]]; then
    gum style --foreground 196 "No editable files found."
    return 1
  fi

  echo ""
  FILE_TO_EDIT=$(gum choose --header "Select file to edit:" "${ACTUAL_FILES[@]}")

  if [[ -n "$FILE_TO_EDIT" ]]; then
    echo ""
    gum style --foreground 147 "Opening $FILE_TO_EDIT in your default editor..."
    ${EDITOR:-nano} "$FILE_TO_EDIT"
    echo ""
    echo "✅ File edited. Use 'Update and push changes' to save to gist."
  fi
}

remove_files_from_gist() {
  echo ""
  gum style --foreground 147 "Remove files from gist"

  # Get list of files in current directory (excluding .git and directories)
  FILES=(*)
  ACTUAL_FILES=()
  for file in "${FILES[@]}"; do
    if [[ -f "$file" && "$file" != ".git" ]]; then
      ACTUAL_FILES+=("$file")
    fi
  done

  if [[ ${#ACTUAL_FILES[@]} -eq 0 ]]; then
    gum style --foreground 196 "No files found to remove."
    return 1
  fi

  echo ""
  FILES_TO_REMOVE=$(printf '%s\n' "${ACTUAL_FILES[@]}" | gum choose --no-limit --header "Select files to remove (use SPACE to select multiple):")

  if [[ -n "$FILES_TO_REMOVE" ]]; then
    echo ""
    gum style --foreground 196 "Files to remove:"
    echo "$FILES_TO_REMOVE" | while IFS= read -r file; do
      echo " • $file"
    done
    echo ""

    if gum confirm "⚠️  Are you sure you want to remove these files?"; then
      echo ""
      while IFS= read -r file; do
        if [[ -f "$file" ]]; then
          rm "$file"
          echo "✅ Removed: $file"
        fi
      done <<<"$FILES_TO_REMOVE"
    fi
  fi
}

push_gist_changes() {
  echo ""
  gum style --foreground 147 "Pushing changes to gist using your custom acp function..."

  # Check if there are any changes
  if ! git diff --quiet || ! git diff --cached --quiet || [[ -n $(git ls-files --others --exclude-standard) ]]; then
    echo ""
    gum style --foreground 147 "Changes detected. Using your acp function to commit and push..."
    echo ""

    # Call your custom acp function
    if acp; then
      echo ""
      gum style --foreground 46 "✅ Gist updated successfully using Git workflow!"
    else
      echo ""
      gum style --foreground 196 "❌ Failed to push changes"
    fi
  else
    gum style --foreground 147 "No changes detected in gist."
  fi
}

cleanup_temp_dir() {
  if [[ "$UPDATE_IN_PLACE" == false && -d "../$GIST_DIR" ]]; then
    cd ..
    rm -rf "$GIST_DIR"
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

  # Choose action - USING GIT WORKFLOW
  ACTION=$(gum choose --header "What would you like to do?" \
    "Clone locally" \
    "Update with Git" \
    "View gist" \
    "Delete gist")

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
  "Update with Git")
    update_gist_with_git "$SELECTED_GIST_ID"
    ;;
  "View gist")
    echo ""
    gh gist view "$SELECTED_GIST_ID" | gum pager
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
  echo "Gist Manager - Interactive GitHub Gist Workflow (Git-based)"
  echo ""
  echo "Usage: $0 [--help]"
  echo ""
  echo "This script provides an interactive TUI for:"
  echo "- Creating new gists with multiple files (use SPACE to select multiple)"
  echo "- Cloning gists by URL or ID"
  echo "- Managing existing gists using Git workflow (supports ALL file types)"
  echo "- Using your custom acp() function for commits and pushes"
  echo "- Simple new file detection"
  echo ""
  echo "Features:"
  echo "- Automatic detection of new files in current directory"
  echo "- No file type restrictions (supports binary files, images, etc.)"
  echo "- Uses Git directly for maximum flexibility"
  echo "- Integrates your custom commit/push workflow"
  echo "- Interactive file editing with your preferred editor"
  echo ""
  echo "Requirements: gh, gum, git, find"
  exit 0
fi

main "$@"
