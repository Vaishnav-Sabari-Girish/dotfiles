#!/usr/bin/env bash

# Path to your quotes.json file - update this path as needed
QUOTES_FILE="/home/vaishnav/dotfiles/zsh/quotes.json"

# Function to display a random anime quote
function display_random_quote() {
  # Check if quotes file exists
  if [ ! -f "$QUOTES_FILE" ]; then
    echo "Error: quotes.json file not found at $QUOTES_FILE"
    echo "Please update the QUOTES_FILE variable in this script to point to your quotes.json file."
    return 1
  fi

  # Check if jq is installed
  if ! command -v jq &>/dev/null; then
    echo "Error: jq is not installed. Please install jq to run this script."
    echo "On most systems: sudo apt install jq  or  sudo dnf install jq"
    return 1
  fi

  # Get total number of quotes
  total_quotes=$(jq 'length' "$QUOTES_FILE")

  if [ "$total_quotes" -eq 0 ]; then
    echo "No quotes found in the file."
    return 1
  fi

  # Generate random index (0 to total_quotes-1)
  random_index=$((RANDOM % total_quotes))

  # Extract the random quote, character, and show
  quote=$(jq -r ".[$random_index].quote" "$QUOTES_FILE")
  character=$(jq -r ".[$random_index].character" "$QUOTES_FILE")
  show=$(jq -r ".[$random_index].show" "$QUOTES_FILE")

  # Get terminal width for centering
  terminal_width=$(tput cols)
  wrap_width=70

  # Wrap and center align the quote
  wrapped_quote=$(echo "$quote" | fmt -w $wrap_width | while read -r line; do
    printf "%*s\n" $(((${#line} + terminal_width) / 2)) "$line"
  done)

  # Create attribution line
  attribution="- $character ($show)"

  # Center align the attribution
  centered_attribution=$(printf "%*s\n" $(((${#attribution} + terminal_width) / 2)) "$attribution")

  # Display the quote with colors
  echo
  echo -e "\033[1;36m$wrapped_quote\033[0m"
  echo
  echo -e "\033[1;33m$centered_attribution\033[0m"
  echo
}

# Call the function
display_random_quote
