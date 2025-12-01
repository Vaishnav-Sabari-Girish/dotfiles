#!/usr/bin/env bash

# Check dependencies
for cmd in aoc gum glow; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "Error: $cmd not found"
    exit 1
  fi
done

# Get default year
get_year() {
  local year=$(date +%Y)
  local month=$(date +%m)
  [ "$month" -lt 12 ] && year=$((year - 1))
  echo "$year"
}

# Main menu
while true; do
  clear
  gum style --border double --padding "1 2" --border-foreground 212 "🎄 Advent of Code Interactive"
  echo ""

  choice=$(gum choose "Read Puzzle" "Download" "Submit Answer" "Calendar" "Leaderboard" "Exit")

  case "$choice" in
  "Read Puzzle")
    clear
    echo "📖 Read Puzzle"
    echo ""

    year=$(gum input --prompt "Year: " --value "$(get_year)")
    day=$(gum input --prompt "Day (empty for latest): " --placeholder "auto")

    args=(-y "$year" -P -o)
    [ -n "$day" ] && args+=(-d "$day")

    tmpfile=$(mktemp --suffix=.md)
    args+=(-p "$tmpfile")

    if aoc download "${args[@]}" 2>&1; then
      glow -p "$tmpfile"
    else
      echo "Failed to fetch puzzle"
    fi

    rm -f "$tmpfile"
    echo ""
    read -p "Press Enter to continue..."
    ;;

  "Download")
    clear
    echo "💾 Download Puzzle & Input"
    echo ""

    year=$(gum input --prompt "Year: " --value "$(get_year)")
    day=$(gum input --prompt "Day: " --placeholder "auto")
    puzzle=$(gum input --prompt "Puzzle file: " --value "puzzle.md")
    input=$(gum input --prompt "Input file: " --value "input.txt")

    what=$(gum choose "Both" "Puzzle only" "Input only")

    args=(-y "$year" -p "$puzzle" -i "$input")
    [ -n "$day" ] && args+=(-d "$day")

    case "$what" in
    "Puzzle only") args+=(-P) ;;
    "Input only") args+=(-I) ;;
    esac

    if [ -f "$puzzle" ] || [ -f "$input" ]; then
      gum confirm "Overwrite existing files?" && args+=(-o) || continue
    fi

    aoc download "${args[@]}"

    if [ -f "$puzzle" ]; then
      gum confirm "View puzzle?" && glow -p "$puzzle"
    fi

    echo ""
    read -p "Press Enter to continue..."
    ;;

  "Submit Answer")
    clear
    echo "🚀 Submit Answer"
    echo ""

    year=$(gum input --prompt "Year: " --value "$(get_year)")
    day=$(gum input --prompt "Day: " --placeholder "auto")
    part=$(gum choose "1" "2")
    answer=$(gum input --prompt "Answer: ")

    [ -z "$answer" ] && continue

    echo ""
    echo "Year: $year"
    echo "Day: ${day:-auto}"
    echo "Part: $part"
    echo "Answer: $answer"
    echo ""

    gum confirm "Submit?" || continue

    args=(submit "$part" "$answer" -y "$year")
    [ -n "$day" ] && args+=(-d "$day")

    aoc "${args[@]}"

    echo ""
    read -p "Press Enter to continue..."
    ;;

  "Calendar")
    clear
    year=$(gum input --prompt "Year: " --value "$(get_year)")
    echo ""
    aoc calendar -y "$year"
    echo ""
    read -p "Press Enter to continue..."
    ;;

  "Leaderboard")
    clear
    year=$(gum input --prompt "Year: " --value "$(get_year)")
    id=$(gum input --prompt "Leaderboard ID: ")
    [ -z "$id" ] && continue
    echo ""
    aoc private-leaderboard "$id" -y "$year"
    echo ""
    read -p "Press Enter to continue..."
    ;;

  "Exit")
    clear
    echo "Happy coding! 🎄"
    exit 0
    ;;

  *)
    # Handles ESC or empty selection
    if [ -z "$choice" ]; then
      clear
      echo "Happy coding! 🎄"
      exit 0
    fi
    ;;
  esac
done
