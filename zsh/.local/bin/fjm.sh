#!/usr/bin/env bash
# fjm — an fzf-driven menu for forgejo-cli (`fj`)
# https://codeberg.org/forgejo-contrib/forgejo-cli
#
# Usage:  ./fjm.sh [-H host]        (default host: $FJ_HOST or codeberg.org)
# Needs:  fj, fzf        (labels additionally need curl + jq)

set -u
set -o pipefail

FJ_BIN="${FJ_BIN:-fj}"
FJ_HOST="${FJ_HOST:-codeberg.org}"
BASH_PATH="$(command -v bash)"

usage() {
  cat <<EOF
fjm — fzf menu for forgejo-cli

  fjm.sh [-H|--host HOST]

Environment:
  FJ_HOST         Forgejo instance (default: codeberg.org)
  FJ_BIN          path to the fj binary (default: fj)
  FORGEJO_TOKEN   API token, only used for the Labels menu (fj has no
                  repo-label command, so labels go through the REST API)
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
  -H | --host)
    FJ_HOST="${2:?host required}"
    shift 2
    ;;
  -h | --help)
    usage
    exit 0
    ;;
  *)
    echo "unknown option: $1" >&2
    usage >&2
    exit 2
    ;;
  esac
done

for c in fzf "$FJ_BIN"; do
  command -v "$c" >/dev/null 2>&1 || {
    echo "Missing dependency: $c" >&2
    case "$c" in
    fzf) echo "  install: https://github.com/junegunn/fzf#installation" >&2 ;;
    *) echo "  install: https://codeberg.org/forgejo-contrib/forgejo-cli/wiki/Installation" >&2 ;;
    esac
    exit 1
  }
done

# ───────────────────────── helpers ─────────────────────────

fjx() { "$FJ_BIN" -H "$FJ_HOST" "$@"; }

c_dim=$'\033[2m'
c_red=$'\033[31m'
c_grn=$'\033[32m'
c_off=$'\033[0m'
info() { printf '%s\n' "${c_grn}$*${c_off}" >&2; }
warn() { printf '%s\n' "${c_red}$*${c_off}" >&2; }
pause() {
  read -rsn1 -p $'\n'"${c_dim}[press any key]${c_off} " _ </dev/tty
  echo
}

strip_ansi() { sed -E $'s/\033\\[[0-9;?]*[a-zA-Z]//g'; }

# pick <prompt> [fzf args...]  — reads choices on stdin, prints the selection
pick() {
  local prompt=$1
  shift
  SHELL="$BASH_PATH" fzf --prompt="$prompt > " --height=85% --min-height=15 \
    --reverse --border --ansi "$@"
}

# menu <title> <item>...
menu() {
  local t=$1
  shift
  printf '%s\n' "$@" | pick "$t"
}

confirm() { [ "$(printf 'No\nYes\n' | pick "$1")" = "Yes" ]; }

# ask <prompt> [prefill]
ask() {
  local v=""
  if [ $# -gt 1 ] && [ -n "$2" ]; then
    read -rep "$1: " -i "$2" v </dev/tty
  else read -rep "$1: " v </dev/tty; fi
  printf '%s' "$v"
}

# show <cmd...>: capture output, page it if long
show() {
  local out rc
  out=$("$@" 2>&1)
  rc=$?
  [ -z "$out" ] && out="(no output)"
  if [ "$(printf '%s\n' "$out" | wc -l)" -gt "$(tput lines 2>/dev/null || echo 24)" ] && command -v less >/dev/null; then
    printf '%s\n' "$out" | less -R
  else
    printf '%s\n' "$out"
    pause
  fi
  return $rc
}

# run <cmd...>: run attached to the terminal (editors, prompts), then pause
run() {
  "$@"
  local rc=$?
  [ $rc -ne 0 ] && warn "(exit status $rc)"
  pause
  return $rc
}

# Extract an issue/PR number from a list line
_num() {
  local s n
  s=$(printf '%s' "$1" | sed -E $'s/\033\\[[0-9;?]*[a-zA-Z]//g')
  n=$(printf '%s' "$s" | grep -oE '#[0-9]+' | head -1 | tr -d '#')
  [ -z "$n" ] && n=$(printf '%s' "$s" | grep -oE '[0-9]+' | head -1)
  printf '%s' "$n"
}

# Guess a title/tag from a list line (user can edit it before use)
_guess_name() {
  printf '%s' "$1" | sed -E $'s/\033\\[[0-9;?]*[a-zA-Z]//g; s/^[[:space:]*>-]+//; s/ {2,}.*$//; s/[[:space:]]+\\(.*$//; s/[[:space:]]+$//'
}

_repo_preview() {
  case "$1" in *[!A-Za-z0-9_./-]* | "") return 0 ;; esac
  "$FJ_BIN" -H "$FJ_HOST" repo view "$1" 2>&1
}

_thing_preview() { # kind repo line
  local n
  n=$(_num "$3")
  [ -n "$n" ] || return 0
  "$FJ_BIN" -H "$FJ_HOST" "$1" view "$2#$n" 2>&1 | head -80
}

export FJ_BIN FJ_HOST
export -f _num _repo_preview _thing_preview

# ───────────────────────── state ─────────────────────────

LOGGED_IN=0
REPOS_CACHE=""
CHOSEN_REPO=""
API_TOKEN=""

refresh_login() {
  if fjx whoami >/dev/null 2>&1; then LOGGED_IN=1; else LOGGED_IN=0; fi
}

load_repos() {
  fjx user repos 2>/dev/null | strip_ansi |
    grep -oE '[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+' |
    awk -F/ -v h="$FJ_HOST" '$1 != h && !seen[$0]++'
}

# choose_repo → sets CHOSEN_REPO (owner/name); returns 1 on cancel
choose_repo() {
  local manual="✎ type a repo name manually" refresh="↻ refresh list" sel
  CHOSEN_REPO=""
  [ -z "$REPOS_CACHE" ] && REPOS_CACHE=$(load_repos)
  while :; do
    sel=$({
      printf '%s\n' "$manual" "$refresh"
      [ -n "$REPOS_CACHE" ] && printf '%s\n' "$REPOS_CACHE"
    } |
      pick "repo" --preview '_repo_preview {}' --preview-window=right:50%) || return 1
    case "$sel" in
    "$refresh") REPOS_CACHE=$(load_repos) ;;
    "$manual")
      sel=$(ask "owner/repo")
      case "$sel" in */*)
        CHOSEN_REPO=$sel
        return 0
        ;;
      "") ;; *) warn "Use the form owner/repo" ;; esac
      ;;
    *)
      CHOSEN_REPO=$sel
      return 0
      ;;
    esac
  done
}

# ───────────────────────── auth ─────────────────────────

do_login() {
  local how
  how=$(menu "login to $FJ_HOST" \
    "Browser (OAuth) — fj auth login" \
    "Application token — fj auth add-key" \
    "Cancel") || return
  case "$how" in Browser* | Application*) ;; *) return ;; esac
  # A stale/revoked key makes login fail with "Key already exists" and every
  # other call with "unable to parse refresh token", so clear it first.
  if fjx auth list 2>/dev/null | grep -qF "$FJ_HOST"; then
    info "Removing the existing (stale) key for $FJ_HOST first…"
    fjx auth logout "$FJ_HOST" >/dev/null 2>&1
  fi
  case "$how" in
  Browser*) run fjx auth login ;;
  Application*)
    info "Create a token at https://$FJ_HOST/user/settings/applications"
    run fjx auth add-key
    ;;
  esac
  refresh_login
  [ "$LOGGED_IN" -eq 1 ] && REPOS_CACHE=""
}

do_logout() {
  confirm "Log out of $FJ_HOST?" || return
  run fjx auth logout "$FJ_HOST"
  refresh_login
  REPOS_CACHE=""
}

# ───────────────────────── repos ─────────────────────────

create_repo() {
  local name desc vis mode
  local args
  name=$(ask "New repo name (or org/name)")
  [ -z "$name" ] && return
  desc=$(ask "Description (optional)")
  vis=$(menu "visibility" "public" "private") || return
  args=(repo create "$name")
  [ -n "$desc" ] && args+=(--description "$desc")
  [ "$vis" = private ] && args+=(--private)
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    mode=$(menu "current directory is a git repo" \
      "Just create the repo" \
      "Create + add it as remote 'origin'" \
      "Create + add remote 'origin' + push") || return
    case "$mode" in
    *"+ add it"*) args+=(--remote origin) ;;
    *"+ push") args+=(--remote origin --push) ;;
    esac
  fi
  run fjx "${args[@]}" && REPOS_CACHE=""
}

repo_menu() {
  local repo=$1 a p
  while :; do
    a=$(menu "repo · $repo" \
      "View details" "Read README" "Open in browser" "Clone" \
      "Star" "Unstar" "Fork" "View wiki page" "Delete repo" "Back") || return
    case "$a" in
    "View details") show fjx repo view "$repo" ;;
    "Read README") show fjx repo readme "$repo" ;;
    "Open in browser") fjx repo browse "$repo" ;;
    "Clone")
      p=$(ask "Target directory (blank = default)")
      if [ -n "$p" ]; then run fjx repo clone "$repo" "$p"; else run fjx repo clone "$repo"; fi
      ;;
    "Star") run fjx repo star "$repo" ;;
    "Unstar") run fjx repo unstar "$repo" ;;
    "Fork") run fjx repo fork "$repo" && REPOS_CACHE="" ;;
    "View wiki page")
      p=$(ask "Wiki page name")
      [ -n "$p" ] && show fjx wiki view --repo "$repo" "$p"
      ;;
    "Delete repo")
      p=$(ask "Type '$repo' to confirm deletion")
      if [ "$p" = "$repo" ]; then run fjx repo delete "$repo" && REPOS_CACHE=""; else
        warn "Not confirmed."
        pause
      fi
      ;;
    *) return ;;
    esac
  done
}

# ───────────────────────── issues & PRs ─────────────────────────

labels_args() { # prints --add/--remove flags from two comma lists
  local IFS=, x
  for x in $1; do [ -n "${x// /}" ] && printf '%s\0' --add "$(printf '%s' "$x" | sed 's/^ *//;s/ *$//')"; done
  for x in $2; do [ -n "${x// /}" ] && printf '%s\0' --remove "$(printf '%s' "$x" | sed 's/^ *//;s/ *$//')"; done
}

thing_actions() { # kind repo num
  local kind=$1 repo=$2 num=$3 id="$2#$3" a v m add rm
  local acts margs la
  while :; do
    if [ "$kind" = issue ]; then
      acts=("View" "View comments" "Add comment" "Edit title" "Edit body (editor)"
        "Add/remove labels" "Assign users" "Close" "Open in browser" "Back")
    else
      acts=("View" "CI / mergeability status" "View comments" "Add comment" "Edit title"
        "Edit body (editor)" "Add/remove labels" "Merge" "Close"
        "Check out locally (run from a clone)" "Open in browser" "Back")
    fi
    a=$(menu "$kind $id" "${acts[@]}") || return
    case "$a" in
    "View") show fjx "$kind" view "$id" ;;
    "CI / mergeability status") show fjx pr status "$id" ;;
    "View comments") show fjx "$kind" view "$id" comments ;;
    "Add comment")
      m=$(ask "Comment (blank = open editor)")
      if [ -n "$m" ]; then run fjx "$kind" comment "$id" "$m"; else run fjx "$kind" comment "$id"; fi
      ;;
    "Edit title")
      m=$(ask "New title")
      [ -n "$m" ] && run fjx "$kind" edit "$id" title "$m"
      ;;
    "Edit body (editor)") run fjx "$kind" edit "$id" body ;;
    "Add/remove labels")
      add=$(ask "Labels to add (comma separated)")
      rm=$(ask "Labels to remove (comma separated)")
      la=()
      while IFS= read -r -d '' v; do la+=("$v"); done < <(labels_args "$add" "$rm")
      if [ ${#la[@]} -gt 0 ]; then run fjx "$kind" edit "$id" labels "${la[@]}"; fi
      ;;
    "Assign users")
      m=$(ask "Usernames (space separated)")
      # shellcheck disable=SC2086
      [ -n "$m" ] && run fjx issue assign --repo "$repo" "$num" $m
      ;;
    "Merge")
      v=$(menu "merge method" default merge rebase squash) || continue
      margs=()
      [ "$v" != default ] && margs+=(--method "$v")
      confirm "Delete the PR's remote branch after merging?" && margs+=(--delete)
      run fjx pr merge "$id" ${margs[@]+"${margs[@]}"}
      ;;
    "Close")
      confirm "Close $kind $id?" || continue
      m=$(ask "Closing comment (blank = none)")
      if [ -n "$m" ]; then run fjx "$kind" close "$id" --with-msg "$m"; else run fjx "$kind" close "$id"; fi
      ;;
    "Check out locally"*) run fjx pr checkout "$num" ;;
    "Open in browser") fjx "$kind" browse "$id" ;;
    *) return ;;
    esac
  done
}

browse_things() { # kind repo state
  local kind=$1 repo=$2 state=$3 out rc sel num
  local args=("$kind" search --repo "$repo")
  [ "$state" != open ] && args+=(--state "$state")
  out=$(fjx "${args[@]}" 2>&1)
  rc=$?
  if [ $rc -ne 0 ]; then
    warn "fj failed:"
    printf '%s\n' "$out"
    pause
    return
  fi
  if [ -z "$(printf '%s' "$out" | tr -d '[:space:]')" ]; then
    info "No $state ${kind}s found."
    pause
    return
  fi
  while :; do
    sel=$(printf '%s\n' "$out" | strip_ansi | grep -v '^[[:space:]]*$' |
      pick "$kind" --preview "_thing_preview $kind $repo {}" --preview-window=right:55%) || return
    num=$(_num "$sel")
    if [ -z "$num" ]; then
      warn "Couldn't find a number in: $sel"
      pause
      continue
    fi
    thing_actions "$kind" "$repo" "$num"
  done
}

thing_menu() { # kind (issue|pr)
  local kind=$1 repo a state=open t
  choose_repo || return
  repo=$CHOSEN_REPO
  while :; do
    a=$(menu "$kind · $repo" "Browse & pick ($state)" "Create new" "Change state filter" "Back") || return
    case "$a" in
    Browse*) browse_things "$kind" "$repo" "$state" ;;
    "Create new")
      t=$(ask "Title")
      [ -z "$t" ] && continue
      if [ "$kind" = issue ]; then
        run fjx issue create --repo "$repo" "$t"
      else
        warn "PR creation uses the git repo in the current directory."
        run fjx pr create "$t"
      fi
      ;;
    "Change state filter") state=$(menu "state" open closed all) || state=open ;;
    *) return ;;
    esac
  done
}

# ───────────────────────── milestones ─────────────────────────

milestones_menu() {
  local repo a out sel title v m
  choose_repo || return
  repo=$CHOSEN_REPO
  while :; do
    a=$(menu "milestones · $repo" "Browse & pick" "Create new" "Back") || return
    case "$a" in
    "Create new")
      title=$(ask "Milestone title")
      [ -z "$title" ] && continue
      v=$(menu "initial state" open closed) || continue
      run fjx milestone create --repo "$repo" --state "$v" "$title"
      ;;
    Browse*)
      out=$(fjx milestone search --repo "$repo" 2>&1) || {
        printf '%s\n' "$out"
        pause
        continue
      }
      [ -z "$(printf '%s' "$out" | tr -d '[:space:]')" ] && {
        info "No milestones."
        pause
        continue
      }
      while :; do
        sel=$(printf '%s\n' "$out" | strip_ansi | grep -v '^[[:space:]]*$' | pick "milestone") || break
        title=$(ask "Milestone title (edit if my guess is off)" "$(_guess_name "$sel")")
        [ -z "$title" ] && continue
        v=$(menu "milestone $title" "View" "Rename" "Set description" "Set state" "Delete" "Back") || continue
        case "$v" in
        View) show fjx milestone view --repo "$repo" "$title" ;;
        Rename)
          m=$(ask "New title")
          [ -n "$m" ] && run fjx milestone edit --repo "$repo" --new-title "$m" "$title"
          ;;
        "Set description")
          m=$(ask "Description")
          run fjx milestone edit --repo "$repo" --description "$m" "$title"
          ;;
        "Set state") m=$(menu "state" open closed) && run fjx milestone edit --repo "$repo" --state "$m" "$title" ;;
        Delete) confirm "Delete milestone '$title'?" && run fjx milestone delete --repo "$repo" "$title" ;;
        esac
      done
      ;;
    *) return ;;
    esac
  done
}

# ───────────────────────── labels (REST API) ─────────────────────────
# fj has no repo-level label command, so this talks to /api/v1 directly.

ensure_token() {
  command -v curl >/dev/null && command -v jq >/dev/null || {
    warn "Labels need curl and jq."
    pause
    return 1
  }
  [ -n "$API_TOKEN" ] && return 0
  API_TOKEN="${FORGEJO_TOKEN:-}"
  if [ -z "$API_TOKEN" ]; then
    local f
    for f in "${XDG_DATA_HOME:-$HOME/.local/share}/forgejo-cli/keys.json" \
      "$HOME/Library/Application Support/forgejo-cli/keys.json"; do
      [ -r "$f" ] || continue
      API_TOKEN=$(jq -r --arg h "$FJ_HOST" '(.hosts[$h] // empty) | .token // empty' "$f" 2>/dev/null)
      [ -n "$API_TOKEN" ] && break
    done
  fi
  if [ -z "$API_TOKEN" ]; then
    read -rsp "API token for $FJ_HOST (kept in memory only; or set FORGEJO_TOKEN): " API_TOKEN </dev/tty
    echo
  fi
  [ -n "$API_TOKEN" ]
}

api() { # api METHOD PATH [json-body]
  local m=$1 p=$2
  shift 2
  curl -sS -X "$m" -H "Authorization: token $API_TOKEN" -H 'Content-Type: application/json' \
    ${1:+-d "$1"} "https://$FJ_HOST/api/v1$p"
}

labels_menu() {
  local repo a out sel id name color desc v body
  ensure_token || return
  choose_repo || return
  repo=$CHOSEN_REPO
  while :; do
    a=$(menu "labels · $repo" "Browse & pick" "Create new" "Back") || return
    case "$a" in
    "Create new")
      name=$(ask "Label name")
      [ -z "$name" ] && continue
      color=$(ask "Colour hex (e.g. 0075ca)" "0075ca")
      desc=$(ask "Description (optional)")
      body=$(jq -n --arg n "$name" --arg c "#${color#\#}" --arg d "$desc" '{name:$n,color:$c,description:$d}')
      show api POST "/repos/$repo/labels" "$body"
      ;;
    Browse*)
      while :; do
        out=$(api GET "/repos/$repo/labels?limit=100" | jq -r '.[]? | "\(.id)\t#\(.color)\t\(.name)\t\(.description)"') || {
          warn "API call failed"
          pause
          break
        }
        [ -z "$out" ] && {
          info "No labels (or no permission)."
          pause
          break
        }
        sel=$(printf '%s\n' "$out" | pick "label" --delimiter=$'\t' --with-nth=2..) || break
        id=${sel%%$'\t'*}
        name=$(printf '%s' "$sel" | cut -f3)
        v=$(menu "label $name" "Rename" "Change colour" "Change description" "Delete" "Back") || continue
        case "$v" in
        Rename)
          m=$(ask "New name")
          [ -n "$m" ] && show api PATCH "/repos/$repo/labels/$id" "$(jq -n --arg x "$m" '{name:$x}')"
          ;;
        "Change colour")
          m=$(ask "Colour hex")
          [ -n "$m" ] && show api PATCH "/repos/$repo/labels/$id" "$(jq -n --arg x "#${m#\#}" '{color:$x}')"
          ;;
        "Change description")
          m=$(ask "Description")
          show api PATCH "/repos/$repo/labels/$id" "$(jq -n --arg x "$m" '{description:$x}')"
          ;;
        Delete) confirm "Delete label '$name'?" && {
          api DELETE "/repos/$repo/labels/$id"
          info "Deleted."
          pause
        } ;;
        esac
      done
      ;;
    *) return ;;
    esac
  done
}

# ───────────────────────── releases ─────────────────────────

releases_menu() {
  local repo a out sel tag v name body att args
  choose_repo || return
  repo=$CHOSEN_REPO
  while :; do
    a=$(menu "releases · $repo" "Browse & pick" "Create new" "Back") || return
    case "$a" in
    "Create new")
      tag=$(ask "Tag (e.g. v1.0.0)")
      [ -z "$tag" ] && continue
      name=$(ask "Release name (blank = tag)" "$tag")
      body=$(ask "Notes (blank = none)")
      att=$(ask "File to attach (blank = none)")
      v=$(menu "tag" "Use existing tag" "Create the tag") || continue
      args=(release create --repo "$repo")
      if [ "$v" = "Create the tag" ]; then args+=(--create-tag "$tag"); else args+=(--tag "$tag"); fi
      [ -n "$body" ] && args+=(--body "$body")
      [ -n "$att" ] && args+=(--attach "$att")
      confirm "Mark as pre-release?" && args+=(--prerelease)
      run fjx "${args[@]}" "${name:-$tag}"
      ;;
    Browse*)
      out=$(fjx release list --repo "$repo" 2>&1) || {
        printf '%s\n' "$out"
        pause
        continue
      }
      [ -z "$(printf '%s' "$out" | tr -d '[:space:]')" ] && {
        info "No releases."
        pause
        continue
      }
      while :; do
        sel=$(printf '%s\n' "$out" | strip_ansi | grep -v '^[[:space:]]*$' | pick "release") || break
        tag=$(ask "Release/tag name (edit if my guess is off)" "$(_guess_name "$sel")")
        [ -z "$tag" ] && continue
        v=$(menu "release $tag" "View" "Open in browser" "Delete" "Back") || continue
        case "$v" in
        View) show fjx release view --repo "$repo" "$tag" ;;
        "Open in browser") fjx release browse --repo "$repo" "$tag" ;;
        Delete) confirm "Delete release '$tag'?" && run fjx release delete --repo "$repo" "$tag" ;;
        esac
      done
      ;;
    *) return ;;
    esac
  done
}

# ───────────────────────── users / misc ─────────────────────────

users_menu() {
  local who a
  who=$(ask "Username (blank = yourself)")
  while :; do
    a=$(menu "user ${who:-me}" "Profile" "Repos" "Organizations" "Followers" "Following" \
      "Activity" "Follow" "Unfollow" "Back") || return
    case "$a" in
    Profile) show fjx user view ${who:+"$who"} ;;
    Repos) show fjx user repos ${who:+"$who"} ;;
    Organizations) show fjx user orgs ${who:+"$who"} ;;
    Followers) show fjx user followers ${who:+"$who"} ;;
    Following) show fjx user following ${who:+"$who"} ;;
    Activity) show fjx user activity ${who:+"$who"} ;;
    Follow) [ -n "$who" ] && run fjx user follow "$who" ;;
    Unfollow) [ -n "$who" ] && run fjx user unfollow "$who" ;;
    *) return ;;
    esac
  done
}

account_menu() {
  local a h
  a=$(menu "account · $FJ_HOST" "Who am I" "List logins" "Switch host" "Log out" "Back") || return
  case "$a" in
  "Who am I") show fjx whoami ;;
  "List logins") show fjx auth list ;;
  "Switch host")
    h=$(ask "Host (e.g. codeberg.org)" "$FJ_HOST")
    [ -n "$h" ] && {
      FJ_HOST=$h
      export FJ_HOST
      REPOS_CACHE=""
      refresh_login
    }
    ;;
  "Log out") do_logout ;;
  esac
}

pick_repo_then() { choose_repo && "$1" "$CHOSEN_REPO"; }

# ───────────────────────── main ─────────────────────────

main() {
  local items c
  refresh_login
  while :; do
    items=()
    [ "$LOGGED_IN" -eq 0 ] && items+=("Login")
    items+=("Create new repo" "Issues" "Pull requests" "Milestones" "Labels" "Releases"
      "Repo details & actions" "Users & profiles" "Account" "Quit")
    c=$(menu "fj @ $FJ_HOST" "${items[@]}") || break
    case "$c" in
    Login) do_login ;;
    "Create new repo") create_repo ;;
    Issues) thing_menu issue ;;
    "Pull requests") thing_menu pr ;;
    Milestones) milestones_menu ;;
    Labels) labels_menu ;;
    Releases) releases_menu ;;
    "Repo details & actions") pick_repo_then repo_menu ;;
    "Users & profiles") users_menu ;;
    Account) account_menu ;;
    Quit | *) break ;;
    esac
  done
}

main
