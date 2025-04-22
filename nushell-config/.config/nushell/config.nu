$env.config.show_banner = false
$env.config.buffer_editor = "neovide"

$env.path ++= ["~/.local/bin"]
$env.path ++= ["~/.cargo/bin"]
$env.path ++= ["/home/linuxbrew/.linuxbrew/bin/"]

echo "Starship is loading with custom config..."
$env.STARSHIP_CONFIG = "~/.config/starship_nu.toml"

source ~/.cache/starship/init.nu

# Define qr command
def qr [url: string] {
  if ($url | is-empty) {
    error make {msg: "Usage: qr <link_to_website>"}
  }
  curl -s $"qrenco.de/($url)" | str trim
}

# Define file_upload command
def file_upload [file: path] {
  if ($file | is-empty) {
    error make {msg: "Usage: file_upload <path_to_file>"}
  }
  let link = (ffsend upload $file | grep -o 'https://[^ ]*' | str trim)
  print ""
  curl -s $"qrenco.de/($link)" | str trim
}
