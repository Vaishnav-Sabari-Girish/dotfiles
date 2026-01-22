#!/usr/bin/env bash
set -euo pipefail

# Requirements: ffmpeg, gum

command -v gum >/dev/null 2>&1 || {
  echo "gum not found."
  exit 1
}
command -v ffmpeg >/dev/null 2>&1 || {
  echo "ffmpeg not found."
  exit 1
}

gum style --foreground 212 "📁 Select input video file"
infile="$(ls *.mp4 2>/dev/null | gum choose)"
[ -z "${infile}" ] && {
  gum style --foreground 196 "No file selected."
  exit 1
}

gum style --foreground 212 "✏️  Enter output file name (without .gif)"
outbase="$(gum input --placeholder 'output_name')"
[ -z "${outbase}" ] && {
  gum style --foreground 196 "No output name entered."
  exit 1
}

gif="${outbase}.gif"
palette="${outbase}_palette.png"

# Defaults
fps=12
width=720

gum spin --title "Generating palette…" -- \
  ffmpeg -y -i "${infile}" -vf "fps=${fps},scale=${width}:-1:flags=lanczos,palettegen" "${palette}"

gum spin --title "Creating GIF…" -- \
  ffmpeg -y -i "${infile}" -i "${palette}" -lavfi "fps=${fps},scale=${width}:-1:flags=lanczos,paletteuse" "${gif}"

rm -f "${palette}"

gum style --foreground 46 "✅ Done — Created ${gif}"
