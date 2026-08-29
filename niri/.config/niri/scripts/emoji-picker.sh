#!/usr/bin/env bash
# Prefer latuicon if installed, otherwise fall back to fzf-based emoji picker

if command -v latuicon >/dev/null 2>&1; then
  # latuicon prints the selected icon to stdout
  CHOICE=$(latuicon)
else
  # Fallback: original fzf-based picker
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
  CHOICE=$(fzf --prompt="🔍 " --layout=reverse <"$EMOJI_DB" | awk '{print $1}')
fi

if [ -n "$CHOICE" ]; then
  # Use wl-copy for Wayland
  echo -n "$CHOICE" | wl-copy
fi
