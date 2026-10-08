#!/usr/bin/env bash

# Usage: ocr.sh [LANGS] [PSM] [MODE]
#   LANGS: Tesseract language string, e.g. "eng", "jpn+eng", "chi_sim+eng" (default: eng)
#   PSM:   Tesseract page segmentation mode (default: 3, 6 for blocks, 5 for vertical text)
#   MODE:  "ocr" (default) or "translate" (OCR, then translate with translate-shell)
#
# Target language for translation: set OCR_TRANSLATE_TO (default: en)
LANGS="${1:-eng}"
PSM="${2:-3}"
MODE="${3:-ocr}"
TARGET="${OCR_TRANSLATE_TO:-en}"

# Temporary file paths
IMG_PATH="/tmp/ocr_screenshot_$$.png"
TESSE_BASE="/tmp/ocr_text_$$"
TXT_PATH="${TESSE_BASE}.txt"
TRANS_PATH="/tmp/ocr_translated_$$.txt"

cleanup() { rm -f "$IMG_PATH" "$TXT_PATH" "$TRANS_PATH" "${TRANS_PATH}.tmp"; }

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

# The file that ends up on the clipboard and in the editor
OUT_PATH="$TXT_PATH"
NOTIF_BODY="Got some text 🚀"

if [ "$MODE" = "translate" ]; then
  # translate-shell: -b = brief (translation only), ":xx" = target language, source auto-detected
  TRANS_ONLY="${TRANS_PATH}.tmp"
  if trans -b ":$TARGET" -i "$TXT_PATH" >"$TRANS_ONLY" 2>/dev/null && [ -s "$TRANS_ONLY" ]; then
    # Reading (romaji for Japanese, pinyin for Chinese) via translate-shell's phonetics
    PHON=""
    case "$LANGS" in
    *jpn* | *chi*)
      # The reading is printed as "(...)" under the original, so show the original,
      # hide the rest, and keep only the parenthesised lines.
      PHON="$(trans -no-ansi \
        -show-original y -show-translation n \
        -show-original-phonetics y -show-translation-phonetics n \
        -show-prompt-message n -show-languages n \
        -show-dictionary n -show-original-dictionary n -show-alternatives n \
        ":$TARGET" -i "$TXT_PATH" 2>/dev/null |
        grep '^(' | sed 's/^(//; s/)$//')"
      ;;
    esac

    # Original text, then the reading (if any), then the translation
    {
      cat "$TXT_PATH"
      if [ -n "$PHON" ]; then
        printf '\n\n──────── reading ────────\n\n%s' "$PHON"
      fi
      printf '\n\n──────── %s ────────\n\n' "$TARGET"
      cat "$TRANS_ONLY"
    } >"$TRANS_PATH"
    rm -f "$TRANS_ONLY"
    OUT_PATH="$TRANS_PATH"
    NOTIF_BODY="Translated to $TARGET 🌏"
  else
    notify-send -u critical "Translation Failed" "Showing the original OCR text instead."
  fi
fi

# Success notification
notify-send -u low "Oh Captain, Read!" "$NOTIF_BODY" \
  -i "$HOME/Pictures/System/ocr.jpg" -t 2000 \
  -h "string:x-canonical-private-synchronous:ocr-notif" --transient

# Copy the result directly to the clipboard
wl-copy <"$OUT_PATH"

# Open the result in a floating Foot terminal running LazyVim
foot --app-id=ocr-editor -o initial-window-mode=windowed -o colors-dark.alpha=0.8 ${EDITOR:-nvim} "$OUT_PATH"

# Clean up temporary files only after you close the editor
cleanup
