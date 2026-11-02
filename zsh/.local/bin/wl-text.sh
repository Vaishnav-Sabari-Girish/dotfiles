#!/bin/sh
# Type some text, see it spelled out in particles.
#   wl-text "HAPPY|BIRTHDAY"      ("|" starts a new line)
#   wl-text "GOOD LUCK" -o all    (extra options go to wl-party)
#   wl-text                       (asks for the text: zenity window, or a prompt in a terminal)

dir="${XDG_CONFIG_HOME:-$HOME/.config}/wl-party/effects"
file="$dir/text.rhai"

if [ -x "$HOME/.cargo/bin/wl-party" ]; then
  party="$HOME/.cargo/bin/wl-party"
else
  party="wl-party"
fi

if [ ! -f "$file" ]; then
  echo "wl-text: $file not found. Copy text.rhai there first." >&2
  exit 1
fi

if [ $# -gt 0 ] && [ "${1#-}" = "$1" ]; then
  text="$1"
  shift
elif [ -t 0 ]; then
  printf 'Text (| = new line): '
  read -r text
else
  # Started from a keybind or menu: ask in a window. Cancel = do nothing.
  text=$(zenity --entry --title="wl-party" --text="Text (| = new line):" --width=420) || exit 0
fi

# Uppercase, then keep only characters the effect can draw.
clean=$(printf '%s' "$text" | tr 'a-z' 'A-Z' | tr '\n' '|' | tr -cd "A-Z0-9 !?.,:'*|-")

if [ -z "$clean" ]; then
  exit 0
fi

sed -i "s#^const TEXT = .*#const TEXT = \"$clean\";#" "$file"
exec "$party" text "$@"
