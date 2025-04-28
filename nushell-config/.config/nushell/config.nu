$env.config.show_banner = false
$env.config.buffer_editor = "neovide"

$env.path ++= ["~/.local/bin"]
$env.path ++= ["~/.cargo/bin"]

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

let threshold = 80

let usage = (
    df -h / 
    | lines 
    | skip 1 
    | split column " " --collapse-empty 
    | get column5 
    | first 
    | str replace '%' '' 
    | into int
)

if $usage >= $threshold {
    print $"Warning: Disk usage is at ($usage)%!"
} else {
    print "Disk usage is under control."
}
