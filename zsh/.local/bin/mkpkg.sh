#!/usr/bin/env zsh
# mkpkg.sh — Interactive PKGBUILD generator

set -e

# Use subshell for secrets or copy vars (secure option)
if [[ ! -r ~/.zsh_secrets ]]; then
  echo "Error: ~/.zsh_secrets not found or not readable"
  exit 1
fi

# Source in subshell and capture vars (avoids SC1090)
{
  source ~/.zsh_secrets
} >/dev/null 2>&1

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
_header() { echo "\n${_BOLD}${_CYAN}==> $*${_RESET}"; }

# ─────────────────────────────────────────────────────────────────────────────

if ! command -v fzf &>/dev/null; then
  _err "fzf is not installed. Please install it using your package manager."
  exit 1
fi

_header "PKGBUILD Generator"

# 1. pkgname
printf "${_WHITE}${_BOLD}1. Enter pkgname:${_RESET} "
read -r pkgname
if [[ -z "$pkgname" ]]; then
  _err "pkgname cannot be empty."
  exit 1
fi

# 2. _pkgname
_pkgname_opt=$(printf "Keep same as pkgname\nDifferent one" | fzf --prompt="2. Choose _pkgname strategy > " --height=10 --layout=reverse --border --cycle)
if [[ "$_pkgname_opt" == "Different one" ]]; then
  printf "${_WHITE}${_BOLD}   Enter _pkgname:${_RESET} "
  read -r _pkgname
else
  _pkgname="$pkgname"
fi

# 3. pkgver
printf "${_WHITE}${_BOLD}3. Enter pkgver:${_RESET} "
read -r pkgver

# 4. pkgrel
printf "${_WHITE}${_BOLD}4. Enter pkgrel${_RESET} ${_GREY}[1]:${_RESET} "
read -r pkgrel
pkgrel=${pkgrel:-1}

# 5. pkgdesc
printf "${_WHITE}${_BOLD}5. Enter pkgdesc:${_RESET} "
read -r pkgdesc

# 6. arch
_info "6. Select supported architectures (Use TAB to multi-select, ENTER to confirm)"
selected_arch=$(printf "x86_64\naarch64\nriscv64" | fzf --multi --prompt="Arch > " --height=8 --layout=reverse --border --cycle)
if [[ -z "$selected_arch" ]]; then
  selected_arch="x86_64" # fallback
fi

arch_formatted=()
# Split the multiline fzf output into a zsh array and format for PKGBUILD
for a in ${(f)selected_arch}; do
  arch_formatted+=("'$a'")
done
arch_string="${arch_formatted[*]}"

# 7. url
printf "${_WHITE}${_BOLD}7. Enter url (e.g., https://github.com/user/repo):${_RESET} "
read -r url

# 8. license
raw_license=$(
  cat <<EOF | fzf --prompt="8. Choose License > " --height=20 --layout=reverse --border --cycle
GNU Affero General Public License v3.0
Apache License 2.0
BSD 2-Clause "Simplified" License
BSD 3-Clause "New" or "Revised" License
Boost Software License 1.0
Creative Commons Zero v1.0 Universal
Eclipse Public License 2.0
GNU General Public License v2.0
GNU General Public License v3.0
GNU Lesser General Public License v2.1
MIT License
Mozilla Public License 2.0
The Unlicense
EOF
)

case $raw_license in
*"Affero"*) license_code="AGPL3" ;;
*"Apache"*) license_code="Apache" ;;
*"BSD 2"*) license_code="BSD" ;;
*"BSD 3"*) license_code="BSD" ;;
*"Boost"*) license_code="BSL" ;;
*"Zero"*) license_code="CC0" ;;
*"Eclipse"*) license_code="EPL" ;;
*"GPL v2.0"*) license_code="GPL2" ;;
*"GPL v3.0"*) license_code="GPL3" ;;
*"Lesser"*) license_code="LGPL2.1" ;;
*"MIT"*) license_code="MIT" ;;
*"Mozilla"*) license_code="MPL2" ;;
*"Unlicense"*) license_code="Unlicense" ;;
*) license_code="custom" ;;
esac

# 9. source
source_string="\"\$_pkgname-\$pkgver.tar.gz::\$url/archive/v\$pkgver.tar.gz\""
dl_url="$url/archive/v$pkgver.tar.gz"

# 10. sha256sums
sum_opt=$(printf "SKIP\nGenerate (Downloads source temporarily to hash)" | fzf --prompt="10. sha256sums strategy > " --height=10 --layout=reverse --border --cycle)
sha_val="'SKIP'"

if [[ "$sum_opt" == *"Generate"* ]]; then
  _step "Downloading $dl_url to calculate sha256sum..."
  temp_file=$(mktemp)
  if curl -sL -f "$dl_url" -o "$temp_file"; then
    hash=$(sha256sum "$temp_file" | awk '{print $1}')
    sha_val="'$hash'"
    _ok "Calculated hash: $hash"
  else
    _warn "Failed to download source. Falling back to 'SKIP'."
  fi
  rm -f "$temp_file"
fi

# 11. Language
language=$(printf "Rust\nC (Placeholder)\nGo (Placeholder)" | fzf --prompt="11. Choose project language > " --height=7 --layout=reverse --border --cycle)

# --- Directory Creation ---
_step "Creating directory $pkgname..."
mkdir -p "$pkgname"
cd "$pkgname" || exit 1

_step "Writing PKGBUILD..."

cat <<EOF >PKGBUILD
# Maintainer: Vaishnav-Sabari-Girish <${AUR_MAINTAINER_EMAIL}>

pkgname=$pkgname
EOF

if [[ "$pkgname" != "$_pkgname" ]]; then
  echo "_pkgname=$_pkgname" >>PKGBUILD
fi

cat <<EOF >>PKGBUILD
pkgver=$pkgver
pkgrel=$pkgrel
pkgdesc="$pkgdesc"
arch=($arch_string)
url="$url"
license=('$license_code')
EOF

if [[ "$language" == "Rust" ]]; then
  cat <<EOF >>PKGBUILD

depends=('gcc-libs')
makedepends=(
  'cargo'
)
EOF
fi

cat <<EOF >>PKGBUILD

source=($source_string)
sha256sums=($sha_val)
EOF

if [[ "$language" == "Rust" ]]; then
  cat <<'EOF' >>PKGBUILD

build() {
  cd "$_pkgname-$pkgver"
  cargo build --release --frozen
}

package() {
  cd "$_pkgname-$pkgver"

  install -Dm755 \
    target/release/$_pkgname \
    "$pkgdir/usr/bin/$_pkgname"

  install -Dm644 LICENSE \
    "$pkgdir/usr/share/licenses/$pkgname/LICENSE"
}
EOF
fi

_ok "PKGBUILD generated successfully!"

# --- .SRCINFO Generation ---
_step "Generating .SRCINFO..."
if command -v makepkg &>/dev/null; then
  makepkg --printsrcinfo > .SRCINFO
  _ok ".SRCINFO generated successfully!"
else
  _warn "makepkg not found in PATH. Skipping .SRCINFO generation."
fi

_ok "All done! Project is ready in $(pwd)"
