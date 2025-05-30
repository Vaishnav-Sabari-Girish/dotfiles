#!/bin/bash
# /* ---- 💫 https://github.com/JaKooLit 💫 ---- */
# This script for selecting wallpapers (SUPER W) using Hyprpaper

# WALLPAPERS PATH
terminal=kitty
wallDIR="$HOME/Pictures/wallpapers"
SCRIPTSDIR="$HOME/.config/hypr/scripts"
wallpaper_current="$HOME/.config/hypr/wallpaper_effects/.wallpaper_current"

# Directory for swaync
iDIR="$HOME/.config/swaync/images"
iDIRi="$HOME/.config/swaync/icons"

# Hyprpaper configuration
HYPERPAPER_CONF="$HOME/.config/hypr/hyprpaper.conf"

# Check if package bc exists
if ! command -v bc &>/dev/null; then
  notify-send -i "$iDIR/error.png" "bc missing" "Install package bc first"
  exit 1
fi

# Variables
rofi_theme="$HOME/.config/rofi/config-wallpaper.rasi"
focused_monitor=$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .name')

# Ensure focused_monitor is detected
if [[ -z "$focused_monitor" ]]; then
  notify-send -i "$iDIR/error.png" "E-R-R-O-R" "Could not detect focused monitor"
  exit 1
fi

# Monitor details
scale_factor=$(hyprctl monitors -j | jq -r --arg mon "$focused_monitor" '.[] | select(.name == $mon) | .scale')
monitor_height=$(hyprctl monitors -j | jq -r --arg mon "$focused_monitor" '.[] | select(.name == $mon) | .height')

icon_size=$(echo "scale=1; ($monitor_height * 3) / ($scale_factor * 150)" | bc)
adjusted_icon_size=$(echo "$icon_size" | awk '{if ($1 < 15) $1 = 20; if ($1 > 25) $1 = 25; print $1}')
rofi_override="element-icon{size:${adjusted_icon_size}%;}"

# Kill existing wallpaper daemons
kill_wallpaper_daemons() {
  pkill swww-daemon 2>/dev/null
  pkill mpvpaper 2>/dev/null
  pkill hyprpaper 2>/dev/null
  sleep 1
  # Restart Hyprpaper
  hyprpaper &
}

# Retrieve wallpapers (images only, excluding videos for Hyprpaper)
mapfile -d '' PICS < <(find -L "${wallDIR}" -type f \( \
  -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.gif" -o \
  -iname "*.bmp" -o -iname "*.tiff" -o -iname "*.webp" \) -print0)

RANDOM_PIC="${PICS[$((RANDOM % ${#PICS[@]}))]}"
RANDOM_PIC_NAME=". random"

# Rofi command
rofi_command="rofi -i -show -dmenu -config $rofi_theme -theme-str $rofi_override"

# Sorting Wallpapers
menu() {
  IFS=$'\n' sorted_options=($(sort <<<"${PICS[*]}"))

  printf "%s\x00icon\x1f%s\n" "$RANDOM_PIC_NAME" "$RANDOM_PIC"

  for pic_path in "${sorted_options[@]}"; do
    pic_name=$(basename "$pic_path")
    if [[ "$pic_name" =~ \.gif$ ]]; then
      cache_gif_image="$HOME/.cache/gif_preview/${pic_name}.png"
      if [[ ! -f "$cache_gif_image" ]]; then
        mkdir -p "$HOME/.cache/gif_preview"
        magick "$pic_path[0]" -resize 1920x1080 "$cache_gif_image"
      fi
      printf "%s\x00icon\x1f%s\n" "$pic_name" "$cache_gif_image"
    else
      printf "%s\x00icon\x1f%s\n" "$(echo "$pic_name" | cut -d. -f1)" "$pic_path"
    fi
  done
}

# Offer SDDM Sequoia Wallpaper Option
set_sddm_wallpaper() {
  sleep 1
  sddm_sequoia="/usr/share/sddm/themes/sequoia_2"

  if [ -d "$sddm_sequoia" ]; then
    if pidof yad >/dev/null; then
      killall yad
    fi

    if yad --info --text="Set current wallpaper as SDDM background?\n\nNOTE: This only applies to SEQUOIA SDDM Theme" \
      --text-align=left \
      --title="SDDM Background" \
      --timeout=5 \
      --timeout-indicator=right \
      --button="yes:0" \
      --button="no:1"; then

      if ! command -v "$terminal" &>/dev/null; then
        notify-send -i "$iDIR/error.png" "Missing $terminal" "Install $terminal to enable setting of wallpaper background"
        exit 1
      fi

      $terminal -e bash -c "echo 'Enter your password to set wallpaper as SDDM Background'; \
            sudo cp -r $wallpaper_current '$sddm_sequoia/backgrounds/default' && \
            notify-send -i '$iDIR/ja.png' 'SDDM' 'Background SET'"
    fi
  fi
}

# Update Startup_Apps.conf for Hyprpaper
modify_startup_config() {
  local startup_config="$HOME/.config/hypr/UserConfigs/Startup_Apps.conf"

  # Ensure Hyprpaper is started, disable swww and mpvpaper
  sed -i '/^\s*exec-once\s*=\s*swww-daemon\s*--format\s*xrgb\s*$/s/^/#/' "$startup_config"
  sed -i '/^\s*exec-once\s*=\s*mpvpaper\s*.*$/s/^/#/' "$startup_config"
  sed -i '/^\s*#\s*exec-once\s*=\s*hyprpaper\s*$/s/^#\s*//; t; $aexec-once = hyprpaper' "$startup_config"
}

# Apply Image Wallpaper with Hyprpaper
apply_image_wallpaper() {
  local image_path="$1"

  kill_wallpaper_daemons

  # Apply wallpaper using Hyprpaper
  hyprctl hyprpaper wallpaper "$focused_monitor,$image_path"

  # Update wallpaper_current for SDDM
  echo "$image_path" >"$wallpaper_current"

  # Run additional scripts
  "$SCRIPTSDIR/WallustSwww.sh" # Note: May need adjustment if WallustSwww.sh is swww-specific
  sleep 2
  "$SCRIPTSDIR/Refresh.sh"
  sleep 1

  set_sddm_wallpaper
}

# Main function
main() {
  choice=$(menu | $rofi_command)
  choice=$(echo "$choice" | xargs)
  RANDOM_PIC_NAME=$(echo "$RANDOM_PIC_NAME" | xargs)

  if [[ -z "$choice" ]]; then
    echo "No choice selected. Exiting."
    exit 0
  fi

  # Handle random selection
  if [[ "$choice" == "$RANDOM_PIC_NAME" ]]; then
    choice=$(basename "$RANDOM_PIC")
  fi

  choice_basename=$(basename "$choice" | sed 's/\(.*\)\.[^.]*$/\1/')

  # Search for the selected file
  selected_file=$(find "$wallDIR" -iname "$choice_basename.*" -print -quit)

  if [[ -z "$selected_file" ]]; then
    echo "File not found. Selected choice: $choice"
    exit 1
  fi

  # Modify startup config for Hyprpaper
  modify_startup_config

  # Apply the wallpaper (only images supported by Hyprpaper)
  apply_image_wallpaper "$selected_file"
}

# Check if rofi is already running
if pidof rofi >/dev/null; then
  pkill rofi
fi

main
