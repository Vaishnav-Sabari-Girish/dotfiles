#!/usr/bin/env bash

OUTPUT_DIR="$HOME/Pictures/Screenshots"

if [[ ! -d "$OUTPUT_DIR" ]]; then
  notify-send "Screenshot directory does not exist: $OUTPUT_DIR" -u critical -t 3000
  exit 1
fi

TIMESTAMP=$(date +'%Y-%m-%d_%H-%M-%S')

case "${1:-region}" in
region)
  grim -g "$(slurp)" - | satty \
    --filename - \
    --output-filename "$OUTPUT_DIR/screenshot-$TIMESTAMP.png" \
    --early-exit \
    --actions-on-enter save-to-clipboard \
    --save-after-copy \
    --copy-command 'wl-copy'
  ;;
screen)
  grim - | satty \
    --filename - \
    --output-filename "$OUTPUT_DIR/screenshot-$TIMESTAMP.png" \
    --early-exit \
    --actions-on-enter save-to-clipboard \
    --save-after-copy \
    --copy-command 'wl-copy'
  ;;
window)
  GEOMETRY=$(niri msg focused-window | grep -oP 'at \(\K[^)]+' | sed 's/, /,/; s/ size /+/; s/x/+/')
  grim -g "$GEOMETRY" - | satty \
    --filename - \
    --output-filename "$OUTPUT_DIR/screenshot-$TIMESTAMP.png" \
    --early-exit \
    --actions-on-enter save-to-clipboard \
    --save-after-copy \
    --copy-command 'wl-copy'
  ;;
esac
