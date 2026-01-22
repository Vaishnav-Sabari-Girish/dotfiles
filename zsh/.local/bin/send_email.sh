#!/usr/bin/env bash
# ~/.local/bin/send_email - Switch POP email accounts securely
# Shellcheck directives
# shellcheck source=/dev/null  # SC1090: Ignore non-constant source
# shellcheck disable=SC1090    # Alternative: Disable specific warning

# Use subshell for secrets or copy vars (secure option)
if [[ ! -r ~/.zsh_secrets ]]; then
  echo "Error: ~/.zsh_secrets not found or not readable"
  exit 1
fi

# Source in subshell and capture vars (avoids SC1090)
{
  source ~/.zsh_secrets
} >/dev/null 2>&1

# Check if secrets exist
if [[ -z "$POP_SMTP_USERNAME1" || -z "$POP_SMTP_PASSWORD1" ]]; then
  echo "Error: POP_SMTP_USERNAME1 or POP_SMTP_PASSWORD1 not set"
  exit 1
fi

# Account selection with gum (fallback to simple read)
if command -v gum >/dev/null 2>&1; then
  choice=$(gum choose "$POP_SMTP_USERNAME1" "${POP_SMTP_USERNAME2-}")
else
  echo "Choose account:"
  echo "1) $POP_SMTP_USERNAME1"
  [[ -n "$POP_SMTP_USERNAME2" ]] && echo "2) $POP_SMTP_USERNAME2"
  read -r choice # SC2162: Fixed with -r
fi

case "$choice" in # Quote for safety
"$POP_SMTP_USERNAME1" | "1")
  export POP_SMTP_USERNAME="$POP_SMTP_USERNAME1"
  export POP_SMTP_PASSWORD="$POP_SMTP_PASSWORD1"
  export POP_FROM="$POP_SMTP_USERNAME1"
  echo "✓ Switched to $POP_SMTP_USERNAME1"
  ;;
"$POP_SMTP_USERNAME2" | "2")
  if [[ -z "$POP_SMTP_USERNAME2" || -z "$POP_SMTP_PASSWORD2" ]]; then
    echo "✗ Secondary account not configured"
    exit 1
  fi
  export POP_SMTP_USERNAME="$POP_SMTP_USERNAME2"
  export POP_SMTP_PASSWORD="$POP_SMTP_PASSWORD2"
  export POP_FROM="$POP_SMTP_USERNAME2"
  echo "✓ Switched to $POP_SMTP_USERNAME2"
  ;;
*)
  echo "✗ Invalid choice"
  exit 1
  ;;
esac

# Run pop
if [[ $# -eq 0 ]]; then
  pop
else
  pop "$@"
fi
