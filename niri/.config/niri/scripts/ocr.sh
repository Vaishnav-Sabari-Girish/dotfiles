#!/usr/bin/env bash

# Temporary file paths
IMG_PATH="/tmp/ocr_screenshot_$$.png"
TESSE_BASE="/tmp/ocr_text_$$"
TXT_PATH="${TESSE_BASE}.txt"

# Select and capture the region
if ! grim -g "$(slurp)" "$IMG_PATH"; then
  exit 0
fi

# Process the image with Tesseract
if ! tesseract -l eng "$IMG_PATH" "$TESSE_BASE" &>/dev/null; then
  notify-send -u critical "OCR Failed" "Tesseract failed to process the image."
  rm -f "$IMG_PATH"
  exit 1
fi

# Success notification
notify-send -u low "Oh Captain, Read!" "Got some text 🚀" \
  -i "$HOME/Pictures/System/ocr.jpg" -t 2000 \
  -h "string:x-canonical-private-synchronous:ocr-notif" --transient

# Copy the extracted text directly to the clipboard
wl-copy <"$TXT_PATH"

# Open the text in a floating Foot terminal running LazyVim
foot --app-id=ocr-editor -o initial-window-mode=windowed -o colors.alpha=0.8 ${EDITOR:-nvim} "$TXT_PATH"

# Clean up temporary files only after you close the editor
rm -f "$IMG_PATH" "$TXT_PATH"
