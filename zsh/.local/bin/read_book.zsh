#!/usr/bin/env zsh

# The absolute path to your library
BOOKS_DIR="$HOME/books"

# 1. Select the Author
# Added '! -name ".*"' to ignore hidden folders like .git at the root level
AUTHOR=$(find "$BOOKS_DIR" -mindepth 1 -maxdepth 1 -type d ! -name ".*" -exec basename {} \; |
  fzf --prompt="📚 Author ❯ " --layout=reverse --border --height=40%)

# Exit if you press Esc or Ctrl-C
[[ -z "$AUTHOR" ]] && exit 0

# 2. Select the Series (or a standalone book)
# Added '! -name ".*"' to ignore hidden folders/files inside the Author folder
ITEM=$(cd "$BOOKS_DIR/$AUTHOR" && find . -mindepth 1 -maxdepth 1 ! -name ".*" ! -name "*.md" | sed 's|^\./||' |
  fzf --prompt="📂 Series/Book ❯ " --layout=reverse --border --height=40%)

# Exit if you press Esc
[[ -z "$ITEM" ]] && exit 0

TARGET_PATH="$BOOKS_DIR/$AUTHOR/$ITEM"

# 3. If a Series (folder) was selected, list the books inside it
if [[ -d "$TARGET_PATH" ]]; then
    # Added '! -path "*/\.*"' to recursively ignore any hidden folders/files deeper in the tree
    BOOK=$(cd "$TARGET_PATH" && find . -type f ! -path "*/\.*" ! -name "*.md" | sed 's|^\./||' |
      fzf --prompt="📖 Book ❯ " --layout=reverse --border --height=60%)
      
    # Exit if you press Esc at the book level
    [[ -z "$BOOK" ]] && exit 0
    
    FINAL_PATH="$TARGET_PATH/$BOOK"
else
    # If a standalone book (file) was selected in Step 2, bypass Step 3
    FINAL_PATH="$TARGET_PATH"
fi

# 4. Open the file
bookokrat "$FINAL_PATH" 
