#!/usr/bin/env zsh
# pdf_manager.zsh — PDF utility functions using fzf
# Source this file or add to your .zshrc: source /path/to/pdf_manager.zsh

# ── Color palette ─────────────────────────────────────────────────────────────
_RED=$'\033[0;31m'
_GREEN=$'\033[0;32m'
_YELLOW=$'\033[0;33m'
_CYAN=$'\033[0;36m'
_GREY=$'\033[0;90m'
_WHITE=$'\033[0;97m'
_BOLD=$'\033[1m'
_RESET=$'\033[0m'

_err() { echo "${_RED}${_BOLD}error:${_RESET}${_RED} $*${_RESET}"; }
_warn() { echo "${_YELLOW}${_BOLD}warn:${_RESET}${_YELLOW}  $*${_RESET}"; }
_ok() { echo "${_GREEN}${_BOLD}done:${_RESET}${_GREEN}  $*${_RESET}"; }
_info() { echo "${_CYAN}${_BOLD}info:${_RESET}${_CYAN}  $*${_RESET}"; }
_step() { echo "${_GREY}  -->  $*${_RESET}"; }
_cancel() { echo "${_YELLOW}cancelled${_RESET}"; }
_header() { echo "${_BOLD}${_CYAN}==> $*${_RESET}"; }
_label() { printf "${_WHITE}${_BOLD}%-20s${_RESET}${_CYAN}%s${_RESET}\n" "$1" "$2"; }

# ─────────────────────────────────────────────────────────────────────────────

pdf_manager() {
  if ! command -v fzf &>/dev/null; then
    _err "fzf is not installed. Install it with: brew install fzf"
    return 1
  fi

  local action=$(printf "Merge PDFs\nSeparate PDF\nRemove Pages from PDF" |
    fzf --reverse --prompt="PDF Manager > " --height=10 --cycle --border)

  case $action in
  "Merge PDFs") merge_pdfs ;;
  "Separate PDF") separate_pdf ;;
  "Remove Pages from PDF") remove_pages ;;
  *)
    _cancel
    return 0
    ;;
  esac
}

merge_pdfs() {
  _header "Merge PDFs"

  local pdf_files=(*.pdf(N))
  if [[ ${#pdf_files[@]} -eq 0 ]]; then
    _err "No PDF files found in current directory"
    return 1
  fi

  # ── Order-aware multi-select ──────────────────────────────────────────────
  local order_file=$(mktemp)
  local counter_file=$(mktemp)
  echo 0 >"$counter_file"

  local preview_script='
        file={}
        order_file='"$order_file"'
        GREEN='"'"'\033[0;32m'"'"'
        GREY='"'"'\033[0;90m'"'"'
        CYAN='"'"'\033[0;36m'"'"'
        BOLD='"'"'\033[1m'"'"'
        RESET='"'"'\033[0m'"'"'
        if grep -qxF "$file" "$order_file" 2>/dev/null; then
            pos=$(grep -n "^${file}$" "$order_file" | cut -d: -f1)
            echo "${GREEN}${BOLD}selected${RESET}${GREEN} — position #${pos}${RESET}"
        else
            echo "${GREY}not selected${RESET}"
        fi
        echo ""
        echo "${CYAN}${BOLD}merge order:${RESET}"
        if [[ -s "$order_file" ]]; then
            nl -ba "$order_file" | sed "s/^/  /"
        else
            echo "${GREY}  (none yet)${RESET}"
        fi
    '

  local toggle_script='
        file={}
        order_file='"$order_file"'
        if grep -qxF "$file" "$order_file" 2>/dev/null; then
            grep -vxF "$file" "$order_file" > "${order_file}.tmp" && mv "${order_file}.tmp" "$order_file"
        else
            echo "$file" >> "$order_file"
        fi
    '

  printf '%s\n' "${pdf_files[@]}" | fzf \
    --reverse \
    --prompt="Select PDFs > " \
    --height=40% \
    --cycle \
    --multi \
    --preview="$preview_script" \
    --preview-window="right:40%:wrap" \
    --bind="tab:execute($toggle_script)+refresh-preview" \
    --bind="space:execute($toggle_script)+refresh-preview" \
    --bind="ctrl-a:select-all" \
    --header="TAB/SPACE = toggle in order  |  ENTER = confirm" \
    >/dev/null

  if [[ ! -s "$order_file" ]]; then
    _err "No files selected"
    rm -f "$order_file" "$counter_file"
    return 1
  fi

  local selected_files=()
  while IFS= read -r line; do
    selected_files+=("$line")
  done <"$order_file"
  rm -f "$order_file" "$counter_file"

  # ── Show selected order ───────────────────────────────────────────────────
  echo ""
  echo "${_CYAN}${_BOLD}merge order:${_RESET}"
  local i=1
  for f in "${selected_files[@]}"; do
    echo "${_GREY}  $i.${_RESET}  ${_WHITE}$f${_RESET}"
    ((i++))
  done

  echo ""
  printf "${_WHITE}${_BOLD}output filename${_RESET}${_GREY} [merged.pdf]:${_RESET} "
  read output_file
  output_file="${output_file:-merged.pdf}"
  [[ "$output_file" != *.pdf ]] && output_file="${output_file}.pdf"

  echo ""
  _label "output:" "$output_file"
  printf "${_WHITE}${_BOLD}proceed with merge?${_RESET} ${_GREY}[y/N]:${_RESET} "
  read confirm
  if [[ "${confirm:l}" == "y" ]]; then
    _step "running pdfunite..."
    pdfunite "${selected_files[@]}" "$output_file"
    _ok "merged successfully → $output_file"
  else
    _cancel
  fi
}

separate_pdf() {
  _header "Separate PDF"

  local pdf_files=(*.pdf(N))
  if [[ ${#pdf_files[@]} -eq 0 ]]; then
    _err "No PDF files found in current directory"
    return 1
  fi

  local input_file=$(printf '%s\n' "${pdf_files[@]}" |
    fzf --reverse --prompt="Select PDF to separate > " --height=20 --cycle --border)

  if [[ -z "$input_file" ]]; then
    _err "No file selected"
    return 1
  fi

  printf "${_WHITE}${_BOLD}base name for output files${_RESET}${_GREY} [page]:${_RESET} "
  read base_name
  base_name="${base_name:-page}"

  printf "${_WHITE}${_BOLD}separate${_RESET} ${_CYAN}$input_file${_RESET} ${_WHITE}${_BOLD}into individual pages?${_RESET} ${_GREY}[y/N]:${_RESET} "
  read confirm
  if [[ "${confirm:l}" == "y" ]]; then
    _step "running pdfseparate..."
    pdfseparate "$input_file" "${base_name}-%d.pdf"
    _ok "separated → pattern: ${base_name}-%d.pdf"
  else
    _cancel
  fi
}

remove_pages() {
  _header "Remove Pages from PDF"

  local pdf_files=(*.pdf(N))
  if [[ ${#pdf_files[@]} -eq 0 ]]; then
    _err "No PDF files found in current directory"
    return 1
  fi

  local input_file=$(printf '%s\n' "${pdf_files[@]}" |
    fzf --reverse --prompt="Select PDF > " --height=20 --cycle --border)

  if [[ -z "$input_file" ]]; then
    _err "No file selected"
    return 1
  fi

  local total_pages
  if command -v pdfinfo &>/dev/null; then
    total_pages=$(pdfinfo "$input_file" | grep "Pages:" | awk '{print $2}')
    _info "$input_file — $total_pages pages"
  else
    _warn "pdfinfo not available"
    printf "${_WHITE}${_BOLD}total pages in the PDF:${_RESET} "
    read total_pages
  fi

  printf "${_WHITE}${_BOLD}pages to remove${_RESET}${_GREY} (e.g. 2,5,7-9):${_RESET} "
  read pages_to_remove

  if [[ -z "$pages_to_remove" ]]; then
    _err "No pages specified"
    return 1
  fi

  local default_out="${input_file%.*}_modified.pdf"
  printf "${_WHITE}${_BOLD}output filename${_RESET}${_GREY} [$default_out]:${_RESET} "
  read output_file
  output_file="${output_file:-$default_out}"
  [[ "$output_file" != *.pdf ]] && output_file="${output_file}.pdf"

  echo ""
  _label "input:" "$input_file"
  _label "pages to remove:" "$pages_to_remove"
  _label "output:" "$output_file"
  printf "${_WHITE}${_BOLD}proceed?${_RESET} ${_GREY}[y/N]:${_RESET} "
  read confirm

  if [[ "${confirm:l}" != "y" ]]; then
    _cancel
    return 0
  fi

  local temp_dir=$(mktemp -d)
  local base_name="temp_page"

  _step "separating pages..."
  pdfseparate "$input_file" "$temp_dir/${base_name}-%d.pdf"

  # Parse pages to remove
  local pages_to_remove_array=()
  local remove_parts=(${(s:,:)pages_to_remove})
  for part in "${remove_parts[@]}"; do
    part=$(echo "$part" | tr -d ' ')
    if [[ "$part" == *-* ]]; then
      local start=${part%-*}
      local end=${part#*-}
      for ((i = start; i <= end; i++)); do
        pages_to_remove_array+=($i)
      done
    else
      pages_to_remove_array+=($part)
    fi
  done

  # Build list of pages to keep
  local pages_to_keep=()
  for ((i = 1; i <= total_pages; i++)); do
    local should_remove=false
    for remove_page in "${pages_to_remove_array[@]}"; do
      if [[ $i -eq $remove_page ]]; then
        should_remove=true
        break
      fi
    done
    if [[ $should_remove == false ]] && [[ -f "$temp_dir/${base_name}-$i.pdf" ]]; then
      pages_to_keep+=("$temp_dir/${base_name}-$i.pdf")
    fi
  done

  if [[ ${#pages_to_keep[@]} -eq 0 ]]; then
    _err "No pages would remain after removal"
    rm -rf "$temp_dir"
    return 1
  fi

  _step "merging remaining pages..."
  pdfunite "${pages_to_keep[@]}" "$output_file"
  rm -rf "$temp_dir"

  _ok "done → $output_file"
  _info "kept ${#pages_to_keep[@]} of $total_pages pages"
}
