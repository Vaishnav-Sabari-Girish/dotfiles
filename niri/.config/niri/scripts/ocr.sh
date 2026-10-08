#!/usr/bin/env bash

# Usage: ocr.sh [LANGS] [PSM]
#   LANGS: Tesseract language string, e.g. "eng", "jpn+eng", "chi_sim+eng" (default: eng)
#   PSM:   Tesseract page segmentation mode (default: 3, 6 for blocks, 5 for vertical text)
LANGS="${1:-eng}"
PSM="${2:-3}"

# Temporary file paths
IMG_PATH="/tmp/ocr_screenshot_$$.png"
TESSE_BASE="/tmp/ocr_text_$$"
TXT_PATH="${TESSE_BASE}.txt"

# Select and capture the region
if ! /usr/bin/grim -g "$(slurp)" "$IMG_PATH"; then
  exit 0
fi

# Process the image with Tesseract
if ! tesseract -l "$LANGS" --psm "$PSM" "$IMG_PATH" "$TESSE_BASE" &>/dev/null; then
  notify-send -u critical "OCR Failed" "Tesseract failed to process the image."
  rm -f "$IMG_PATH"
  exit 1
fi

# Success notification
notify-send -u low "Oh Captain, Read!" "Got some text 🚀" \
  -i "$HOME/Pictures/System/ocr.jpg" -t 2000 \
  -h "string:x-canonical-private-synchronous:ocr-notif" --transient

# Clean up CJK output (English text keeps its normal spacing).
# Only ASCII + \x{...} escapes are used in the Perl code to avoid encoding issues.
perl -CSD -0777 -i -pe '
  my $c = qr/[\p{Han}\p{Hiragana}\p{Katakana}\x{3000}-\x{303F}\x{FF00}-\x{FFEF}]/;
  s/($c)[ \t]+(?=$c)/$1/g;        # CJK space CJK -> CJKCJK
  s/($c)[ \t]+(?=[,.!?;:])/$1/g;  # CJK space ASCII punctuation -> no space
  s/($c)\n(?=$c)/$1/g;            # join wrapped lines between CJK characters
  s/($c)!/$1\x{FF01}/g;           # ! -> full-width
  s/($c);/$1\x{FF1B}/g;           # ; -> full-width
  s/($c)\?/$1\x{FF1F}/g;          # ? -> full-width
  s/($c):/$1\x{FF1A}/g;           # : -> full-width
  s/([\x{FF01}\x{FF1B}\x{FF1F}\x{FF1A}])[ \t]+(?=$c)/$1/g;  # no space after full-width punctuation
' "$TXT_PATH"

# Copy the extracted text directly to the clipboard
wl-copy <"$TXT_PATH"

# Open the text in a floating Foot terminal running LazyVim
foot --app-id=ocr-editor -o initial-window-mode=windowed -o colors-dark.alpha=0.8 ${EDITOR:-nvim} "$TXT_PATH"

# Clean up temporary files only after you close the editor
rm -f "$IMG_PATH" "$TXT_PATH"
