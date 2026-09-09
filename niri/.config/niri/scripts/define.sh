#!/usr/bin/env bash

# 1. Grab text: Check Wayland primary selection (highlighted text) first, then fallback to regular clipboard
word=${1:-$(wl-paste --primary 2>/dev/null || wl-paste 2>/dev/null)}

# 2. Sanitize input: Extract only the first word and strip any stray punctuation or newlines
word=$(echo "$word" | awk '{print $1}' | tr -d '[:punct:]')

# 3. Check for empty word after sanitization
[[ -z "$word" ]] && notify-send -h string:bgcolor:#bf616a -t 3000 "Invalid input." && exit 0

# 4. Fetch the definition from Wiktionary's REST API (no key needed, backed by Wikimedia infra)
query=$(curl -s --connect-timeout 5 --max-time 10 "https://en.wiktionary.org/api/rest_v1/page/definition/$word")
curl_exit=$?

# 5. Check for connection error
if [ $curl_exit -eq 28 ]; then
  notify-send -h string:bgcolor:#bf616a -t 3000 "Dictionary API timed out."
  exit 1
elif [ $curl_exit -ne 0 ]; then
  notify-send -h string:bgcolor:#bf616a -t 3000 "Connection error (exit $curl_exit)."
  exit 1
fi

# 6. Check for invalid word / no entry found (Wiktionary returns a "title" key with an error message on 404)
if echo "$query" | jq -e 'has("title")' >/dev/null 2>&1; then
  notify-send -h string:bgcolor:#bf616a -t 3000 "Invalid word."
  exit 0
fi

# 7. Parse JSON: group by part of speech, dedupe repeated definitions, number each sense.
#    Limits to 4 parts of speech and 4 definitions per part of speech to keep the popup readable.
def=$(echo "$query" | jq -r '
  .en // [] |
  group_by(.partOfSpeech) |
  map({
    pos: (.[0].partOfSpeech // "unknown" | ascii_upcase),
    defs: ([.[].definitions[].definition
      | gsub("(?s)<ol>.*?</ol>"; "")
      | gsub("\\s+"; " ")
      | gsub("^\\s+|\\s+$"; "")
    ] | unique | map(select(length > 0)))
  }) |
  .[:4] |
  map(
    "## " + .pos + "\n" +
    ( .defs[:4] | to_entries | map("  \(.key + 1). \(.value)") | join("\n") )
  ) |
  join("\n\n")
' | sed -E 's/<[^>]+>//g')

# 8. Handle the case where the word exists but has no English section
if [[ -z "$def" ]]; then
  notify-send -h string:bgcolor:#bf616a -t 3000 "No English definition found."
  exit 0
fi

# 9. Create a temporary file to safely handle quotes in the definition.
#    Markdown headers (# / ##) let nvim's built-in syntax highlighting color the word and parts of speech.
temp_dict=$(mktemp /tmp/dict_XXXXXX.md)
echo -e "# ${word^^}\n\n$def" >"$temp_dict"

# 10. Set up Neovim to act as a temporary popup buffer
# -R: Read-only mode
# buftype=nofile & noswapfile: Prevents annoying swap warnings
# nnoremap q :qa!<CR>: Lets you close the popup instantly by pressing 'q'
# autocmd VimLeave: Cleans up the temp file on exit
nvim_cmd="nvim '$temp_dict' -R -c 'setlocal buftype=nofile noswapfile' -c 'nnoremap <buffer> q :qa!<CR>' -c 'autocmd VimLeave * !rm $temp_dict'"

# 11. Execution: Open inline if in a terminal, or spawn floating Foot window if triggered via hotkey/Lua
if [ -t 1 ]; then
  eval "$nvim_cmd"
else
  # Explicitly force windowed mode and transparency for Wayland, mirroring your Super+D bind
  foot --app-id=dict-floating -o initial-window-mode=windowed -o colors.dark.alpha=0.8 sh -c "$nvim_cmd"
fi
