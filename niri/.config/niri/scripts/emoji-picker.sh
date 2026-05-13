#!/usr/bin/env bash

# Database location
EMOJI_DB="$HOME/.emoji-menu-db"

# Download if missing
if [ ! -f "$EMOJI_DB" ]; then
  curl -s 'https://raw.githubusercontent.com/jchook/emoji-menu/master/data/emojis.txt' >"$EMOJI_DB"
  {
    echo "⚡ zig"
    echo "🦀 rust"
    echo "⭐ github"
  } >>"$EMOJI_DB"
fi

# Run fzf and extract the emoji
# awk '{print $1}' gets just the emoji character
CHOICE=$(fzf --prompt="🔍 " --layout=reverse <"$EMOJI_DB" | awk '{print $1}')

if [ -n "$CHOICE" ]; then
  # Use wl-copy for Wayland
  echo -n "$CHOICE" | wl-copy
fi
