#!/usr/bin/env bash
# fanfic — download fanfics via fichub-cli and open them with bookokrat
# Usage:
#   fanfic i <url>   Download EPUB to ~/fanfic/ and open it
#   fanfic           Browse downloaded fanfics with fzf and open selected one

set -euo pipefail

FANFIC_DIR="${HOME}/fanfic"
READER="bookokrat"
DOWNLOADER="fichub_cli"

# Colors for messages
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

err() { echo -e "${RED}error:${NC} $*" >&2; }
warn() { echo -e "${YELLOW}warning:${NC} $*" >&2; }
ok() { echo -e "${GREEN}$*${NC}"; }

usage() {
  cat <<EOF
Usage:
  fanfic i <url>     Download fanfic as EPUB to ~/fanfic/ and open with bookokrat
  fanfic             Open fzf picker of downloaded fanfics in ~/fanfic/

Examples:
  fanfic i "https://archiveofourown.org/works/12345"
  fanfic
EOF
}

# Ensure required commands exist
require_cmd() {
  if ! command -v "$1" &>/dev/null; then
    err "'$1' is not installed or not in PATH."
    case "$1" in
    fichub_cli)
      echo "  Install with:  pip install -U fichub-cli" >&2
      ;;
    bookokrat)
      echo "  Install from:  https://github.com/bugzmanov/bookokrat" >&2
      echo "  (Homebrew: brew install bookokrat, or cargo install bookokrat)" >&2
      ;;
    fzf)
      echo "  Install fzf:   https://github.com/junegunn/fzf" >&2
      ;;
    esac
    exit 1
  fi
}

ensure_dir() {
  if [[ ! -d "$FANFIC_DIR" ]]; then
    mkdir -p "$FANFIC_DIR" || {
      err "Could not create directory: $FANFIC_DIR"
      exit 1
    }
    ok "Created $FANFIC_DIR"
  fi
}

# Find the most recently modified .epub in a directory (or under it)
find_newest_epub() {
  local dir="$1"
  # Prefer files directly in the dir, then any nested
  local file
  file=$(find "$dir" -maxdepth 1 -type f -iname '*.epub' -printf '%T@ %p\n' 2>/dev/null |
    sort -nr | head -n1 | cut -d' ' -f2-)
  if [[ -z "$file" ]]; then
    file=$(find "$dir" -type f -iname '*.epub' -printf '%T@ %p\n' 2>/dev/null |
      sort -nr | head -n1 | cut -d' ' -f2-)
  fi
  echo "$file"
}

download_and_open() {
  local url="$1"

  if [[ -z "$url" ]]; then
    err "No URL provided."
    usage
    exit 1
  fi

  # Basic URL sanity check
  if [[ ! "$url" =~ ^https?:// ]]; then
    err "URL must start with http:// or https://"
    exit 1
  fi

  require_cmd "$DOWNLOADER"
  require_cmd "$READER"
  ensure_dir

  # Snapshot existing epubs so we can detect the new one
  local before_list
  before_list=$(find "$FANFIC_DIR" -type f -iname '*.epub' -print 2>/dev/null | sort || true)

  ok "Downloading to $FANFIC_DIR ..."
  echo "  URL: $url"

  # Run fichub_cli. We capture exit status ourselves so set -e doesn't kill us early.
  local exit_code=0
  "$DOWNLOADER" -u "$url" -o "$FANFIC_DIR" --format epub || exit_code=$?

  if [[ $exit_code -ne 0 ]]; then
    err "fichub_cli failed (exit code $exit_code)."
    if [[ -f ./err.log ]]; then
      warn "Check err.log in the current directory for details."
    fi
    exit "$exit_code"
  fi

  # Find the newly created epub
  local after_list new_epubs epub
  after_list=$(find "$FANFIC_DIR" -type f -iname '*.epub' -print 2>/dev/null | sort || true)
  new_epubs=$(comm -13 <(echo "$before_list") <(echo "$after_list") || true)

  if [[ -n "$new_epubs" ]]; then
    # Prefer the single new file; if multiple, take the newest
    epub=$(echo "$new_epubs" | while read -r f; do
      stat -c '%Y %n' "$f" 2>/dev/null || stat -f '%m %N' "$f" 2>/dev/null
    done | sort -nr | head -n1 | cut -d' ' -f2-)
  else
    # Fallback: maybe it overwrote an existing file, or filename matched previous
    warn "Could not detect a brand-new file. Using most recent EPUB in $FANFIC_DIR"
    epub=$(find_newest_epub "$FANFIC_DIR")
  fi

  if [[ -z "$epub" || ! -f "$epub" ]]; then
    err "Download appeared to succeed but no EPUB was found in $FANFIC_DIR"
    err "Check that fichub_cli supports this site and try again."
    exit 1
  fi

  ok "Downloaded: $(basename "$epub")"
  echo "Opening with $READER ..."
  exec "$READER" "$epub"
}

browse_and_open() {
  require_cmd fzf
  require_cmd "$READER"
  ensure_dir

  local count
  count=$(find "$FANFIC_DIR" -type f -iname '*.epub' 2>/dev/null | wc -l | tr -d ' ')

  if [[ "$count" -eq 0 ]]; then
    err "No EPUB files found in $FANFIC_DIR"
    echo "  Download one first with:  fanfic i <url>" >&2
    exit 1
  fi

  # Use relative paths for cleaner fzf display, then resolve
  local selected
  selected=$(find "$FANFIC_DIR" -type f -iname '*.epub' -printf '%P\n' 2>/dev/null |
    sort -f |
    fzf --prompt="fanfic> " \
      --preview 'echo {}' \
      --height=40% \
      --reverse \
      --border \
      --header="Select a fanfic to open with bookokrat (Esc to cancel)")

  if [[ -z "$selected" ]]; then
    echo "Cancelled."
    exit 0
  fi

  local fullpath="${FANFIC_DIR}/${selected}"
  if [[ ! -f "$fullpath" ]]; then
    err "Selected file no longer exists: $fullpath"
    exit 1
  fi

  ok "Opening: $selected"
  exec "$READER" "$fullpath"
}

# ---------- main ----------
case "${1:-}" in
i | install | download | get)
  shift
  download_and_open "${1:-}"
  ;;
-h | --help | help)
  usage
  exit 0
  ;;
"")
  browse_and_open
  ;;
*)
  err "Unknown command: $1"
  usage
  exit 1
  ;;
esac
