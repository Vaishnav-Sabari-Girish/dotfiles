#!/usr/bin/env bash

# 1. Grab text: Check Wayland primary selection (highlighted text) first, then fallback to regular clipboard
word=${1:-$(wl-paste --primary 2>/dev/null || wl-paste 2>/dev/null)}

# 2. Sanitize input: Extract only the first word and strip any stray punctuation or newlines
word=$(echo "$word" | awk '{print $1}' | tr -d '[:punct:]')

# 3. Check for empty word after sanitization
[[ -z "$word" ]] && notify-send -h string:bgcolor:#bf616a -t 3000 "Invalid input." && exit 0

# 4. Fetch the definition from the API
query=$(curl -s --connect-timeout 5 --max-time 10 "https://api.dictionaryapi.dev/api/v2/entries/en_US/$word")

# 5. Check for connection error
[ $? -ne 0 ] && notify-send -h string:bgcolor:#bf616a -t 3000 "Connection error." && exit 1

# 6. Check for invalid word response
[[ "$query" == *"No Definitions Found"* ]] && notify-send -h string:bgcolor:#bf616a -t 3000 "Invalid word." && exit 0

# 7. Parse JSON to show only first 3 definitions
def=$(echo "$query" | jq -r '[.[].meanings[] | {pos: .partOfSpeech, def: .definitions[].definition}] | .[:3].[] | "\n\(.pos). \(.def)"')

# 8. Create a temporary file to safely handle quotes in the definition
temp_dict=$(mktemp /tmp/dict_XXXXXX.txt)
echo -e "Definition of: ${word^^}\n$def" >"$temp_dict"

# 9. Set up Neovim to act as a temporary popup buffer
# -R: Read-only mode
# buftype=nofile & noswapfile: Prevents annoying swap warnings
# nnoremap q :qa!<CR>: Lets you close the popup instantly by pressing 'q'
# autocmd VimLeave: Cleans up the temp file on exit
nvim_cmd="nvim '$temp_dict' -R -c 'setlocal buftype=nofile noswapfile' -c 'nnoremap <buffer> q :qa!<CR>' -c 'autocmd VimLeave * !rm $temp_dict'"

# 10. Execution: Open inline if in a terminal, or spawn floating Foot window if triggered via hotkey/Lua
if [ -t 1 ]; then
  eval "$nvim_cmd"
else
  # Explicitly force windowed mode and transparency for Wayland, mirroring your Super+D bind
  foot --app-id=dict-floating -o initial-window-mode=windowed -o colors.dark.alpha=0.8 sh -c "$nvim_cmd"
fi
