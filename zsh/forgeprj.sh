#!/usr/bin/env bash

# forgeproj - Interactive project + git + remote setup
# Requires: gum, git, git-cliff, gh (GitHub CLI), berg (Codeberg CLI)

forgeproj() {
  set -e

  # Check deps
  for cmd in gum git git-cliff; do
    if ! command -v "$cmd" &>/dev/null; then
      echo "Error: $cmd is not installed."
      return 1
    fi
  done

  gum style --foreground 212 --bold "🚀 Project Creator with Git & Remote"

  # Choose language first (same as mkproj)
  LANGUAGE=$(gum choose "C" "Rust" "Python" "Go" "Zig" "ESP32-Std")

  # Ask for project name once
  PROJECT_NAME=$(gum input --prompt "Enter project name: ")
  if [ -z "$PROJECT_NAME" ]; then
    echo "Error: project name cannot be empty."
    return 1
  fi

  # Create project based on language (inline logic from mkproj)
  case $LANGUAGE in
  "C")
    echo "📁 Creating C project..."
    mkdir -p "$PROJECT_NAME"
    cd "$PROJECT_NAME"

    cat >main.c <<'EOF'
#include <stdio.h>

int main() {
  printf("Hello, World!\n");
  return 0;
}
EOF

    cat >Justfile <<'EOF'
# Variables
CFLAGS := "-Wall -Wextra -O2"
SRC := "main.c"
OUT := "main.out"

# Build rule
build:
    @gcc {{SRC}} -o {{OUT}} {{CFLAGS}}

# Run rule
run:
    @./{{OUT}}

# Build + Run + Clean together
br:
    @just build && just run && just clean

# Remove built binary
clean:
    @rm {{OUT}}
EOF

    echo "✅ C project '$PROJECT_NAME' created successfully!"
    ;;

  "Rust")
    echo "🦀 Creating Rust project..."
    if ! command -v cargo &>/dev/null; then
      echo "Error: cargo is not installed. Please install Rust from https://rustup.rs/"
      return 1
    fi

    cargo new --bin "$PROJECT_NAME"
    cd "$PROJECT_NAME"
    echo "✅ Rust project '$PROJECT_NAME' created successfully!"
    ;;

  "Python")
    echo "🐍 Creating Python project..."
    if ! command -v uv &>/dev/null; then
      echo "Error: uv is not installed. Please install it from https://docs.astral.sh/uv/"
      return 1
    fi

    uv init "$PROJECT_NAME"
    cd "$PROJECT_NAME"
    echo "✅ Python project '$PROJECT_NAME' created successfully!"
    ;;

  "Go")
    echo "🐹 Creating Go project..."
    if ! command -v go &>/dev/null; then
      echo "Error: go is not installed. Please install Go from https://golang.org/dl/"
      return 1
    fi

    mkdir -p "$PROJECT_NAME"
    cd "$PROJECT_NAME"
    go mod init "$PROJECT_NAME"

    cat >main.go <<'EOF'
package main

import "fmt"

func main() {
    fmt.Println("Hello, World!")
}
EOF

    cat >Justfile <<'EOF'
# Variables
BINARY := "main"

# Build rule
build:
    @go build -o {{BINARY}} .

# Run rule
run:
    @go run .

# Build + Run together
br:
    @just build && ./{{BINARY}} && just clean

# Test rule
test:
    @go test ./...

# Format code
fmt:
    @go fmt ./...

# Clean build artifacts
clean:
    @rm -f {{BINARY}}

# Tidy modules
tidy:
    @go mod tidy
EOF

    echo "✅ Go project '$PROJECT_NAME' created successfully!"
    ;;

  "Zig")
    echo "⚡ Creating Zig project..."
    if ! command -v zig &>/dev/null; then
      echo "Error: zig is not installed. Please install Zig from https://ziglang.org/download/"
      return 1
    fi

    mkdir -p "$PROJECT_NAME"
    cd "$PROJECT_NAME"
    zig init

    cat >Justfile <<EOF
# Variables
BINARY := "zig-out/bin/$PROJECT_NAME"

# Build rule
build:
    @zig build

# Run rule (using zig build run)
run:
    @zig build run

# Build + Run together
br:
    @just build && just run

# Test rule
test:
    @zig build test

# Clean build artifacts
clean:
    @rm -rf zig-out .zig-cache
EOF

    echo "✅ Zig project '$PROJECT_NAME' created successfully!"
    ;;

  "ESP32-Std")
    echo "🔧 Creating ESP32 Rust (std) project..."
    if ! command -v cargo &>/dev/null; then
      echo "Error: cargo is not installed. Please install Rust from https://rustup.rs/"
      return 1
    fi

    if ! command -v cargo-generate &>/dev/null; then
      echo "⚠️  cargo-generate is not installed. Installing now..."
      cargo install cargo-generate
    fi

    # Use --name flag to avoid prompt
    cargo generate esp-rs/esp-idf-template cargo --name "$PROJECT_NAME"
    cd "$PROJECT_NAME"
    echo "✅ ESP32-Std project created successfully!"
    ;;
  esac

  echo "🎉 Project structure created!"

  # Initialize git
  gum spin --spinner dot --title "Initializing git repository..." -- git init

  # Setup git-cliff with custom configuration
  gum spin --spinner dot --title "Setting up git-cliff..." -- bash -c "true"

  # Create custom cliff.toml
  cat >cliff.toml <<EOF
[remote.github]
owner = "Vaishnav-Sabari-Girish"
repo = "$PROJECT_NAME"

[changelog]
# A Tera template to be rendered for each release in the changelog.
# See https://keats.github.io/tera/docs/#introduction
body = """
{% for group, commits in commits | group_by(attribute="group") %}
    ### {{ group | striptags | trim | upper_first }}
    {% for commit in commits %}
        {% if commit.scope -%}
            - **({{commit.scope}})** {{ commit.message | upper_first | trim }}\\
        {% else -%}
            - {{ commit.message | upper_first | trim }}\\
        {% endif -%}
        {% if commit.id %} - ([{{ commit.id | truncate(length=7, end="") }}](https://github.com/{{ remote.github.owner }}/{{ remote.github.repo }}/commit/{{ commit.id }})){%- endif -%}
        {% if commit.remote.pr_number %} in \\
            [#{{ commit.remote.pr_number }}](https://github.com/{{ remote.github.owner }}/{{ remote.github.repo }}/pull/{{ commit.remote.pr_number }}) \\
        {%- endif -%}
        {% if commit.remote.username %} by @{{ commit.remote.username }}{%- endif %}
    {% endfor %}
{% endfor %}
"""
# Remove leading and trailing whitespaces from the changelog's body.
trim = true
# A Tera template to be rendered as the changelog's footer.
# See https://keats.github.io/tera/docs/#introduction
footer = """
<!-- generated by git-cliff -->
"""
# An array of regex based postprocessors to modify the changelog.
# Replace the placeholder <REPO> with a URL.
postprocessors = []

[git]
# Parse commits according to the conventional commits specification.
# See https://www.conventionalcommits.org
conventional_commits = true
# Exclude commits that do not match the conventional commits specification.
filter_unconventional = false
# Split commits on newlines, treating each line as an individual commit.
split_commits = false
commit_parsers = [
    { message = "^feat", group = "<!-- 0 -->:rocket: New features" },
    { message = "^fix", group = "<!-- 1 -->:bug: Bug fixes" },
    { message = "^docs", group = "<!-- 2 -->:page_facing_up: Documentation" },
    { message = "^perf", group = "<!-- 3 -->:zap: Performance" },
    { message = "^chore", group = "<!-- 4 -->:wrench: Miscellaneous" },
    { message = "^refactor", group = "<!-- 5 -->:recycle: Refactoring" },
    { message = "^style", group = "<!-- 6 -->:art: Styling" },
    { message = "^test", group = "<!-- 7 -->:white_check_mark: Testing" },
    { message = ".*", group = "<!-- 8 -->:package: Other" },
]
# An array of regex based parsers to modify commit messages prior to further processing.
commit_preprocessors = [{ pattern = '\((\w+\s)?#([0-9]+)\)', replace = "" }]
# Exclude commits that are not matched by any commit parser.
filter_commits = false
# Order releases topologically instead of chronologically.
topo_order = false
# Order of commits in each group/release within the changelog.
# Allowed values: newest, oldest
sort_commits = "newest"
EOF

  git add .
  git commit -m "chore: initial commit" >/dev/null 2>&1 || true

  gum style --foreground 77 "✓ Git repository initialized with git-cliff"

  # Optional description
  REPO_DESC=$(gum input --placeholder "Enter repository description (optional)")

  # Choose hosting
  gum style --foreground 141 --bold "Choose code hosting platform:"
  HOSTING=$(gum choose "GitHub" "Codeberg" "Skip")

  case "$HOSTING" in
  "GitHub")
    if ! command -v gh &>/dev/null; then
      gum style --foreground 196 "Error: GitHub CLI (gh) not found"
      return 1
    fi

    gum style --foreground 141 "Repository visibility:"
    VISIBILITY=$(gum choose "Public" "Private")

    if [ "$VISIBILITY" = "Public" ]; then
      VIS_FLAG="--public"
    else
      VIS_FLAG="--private"
    fi

    if [ -n "$REPO_DESC" ]; then
      if gum spin --spinner dot --title "Creating GitHub repository..." -- \
        gh repo create "$PROJECT_NAME" $VIS_FLAG --description "$REPO_DESC" --source=. --push; then
        gum style --foreground 77 "✓ GitHub repository created and pushed"
      else
        gum style --foreground 196 "✗ Failed to create GitHub repository"
      fi
    else
      if gum spin --spinner dot --title "Creating GitHub repository..." -- \
        gh repo create "$PROJECT_NAME" $VIS_FLAG --source=. --push; then
        gum style --foreground 77 "✓ GitHub repository created and pushed"
      else
        gum style --foreground 196 "✗ Failed to create GitHub repository"
      fi
    fi
    ;;

  "Codeberg")
    if ! command -v berg &>/dev/null; then
      gum style --foreground 196 "Error: Codeberg CLI (berg) not found"
      return 1
    fi

    gum style --foreground 141 "Repository visibility:"
    VISIBILITY_C=$(gum choose "Public" "Private")

    # berg uses --private flag with true/false values
    if [ "$VISIBILITY_C" = "Private" ]; then
      VIS_FLAG_C="true"
    else
      VIS_FLAG_C="false"
    fi

    # Create with or without description
    if [ -n "$REPO_DESC" ]; then
      if gum spin --spinner dot --title "Creating Codeberg repository..." -- \
        berg repo create --name "$PROJECT_NAME" --description "$REPO_DESC" --default-branch main --private "$VIS_FLAG_C"; then
        gum style --foreground 77 "✓ Codeberg repository created"

        # Try to detect username and push
        BERG_USER=$(berg auth status 2>/dev/null | grep -oE "Logged in as[[:space:]]+[^[:space:]]+" | awk '{print $4}')
        if [ -n "$BERG_USER" ]; then
          git remote add origin "https://codeberg.org/$BERG_USER/$PROJECT_NAME.git" 2>/dev/null || true
          if git show-ref --verify --quiet refs/heads/main; then
            git push -u origin main || true
          else
            git push -u origin master || true
          fi
        fi
      else
        gum style --foreground 196 "✗ Failed to create Codeberg repository"
      fi
    else
      if gum spin --spinner dot --title "Creating Codeberg repository..." -- \
        berg repo create --name "$PROJECT_NAME" --default-branch main --private "$VIS_FLAG_C"; then
        gum style --foreground 77 "✓ Codeberg repository created"

        # Try to detect username and push
        BERG_USER=$(berg auth status 2>/dev/null | grep -oE "Logged in as[[:space:]]+[^[:space:]]+" | awk '{print $4}')
        if [ -n "$BERG_USER" ]; then
          git remote add origin "https://codeberg.org/$BERG_USER/$PROJECT_NAME.git" 2>/dev/null || true
          if git show-ref --verify --quiet refs/heads/main; then
            git push -u origin main || true
          else
            git push -u origin master || true
          fi
        fi
      else
        gum style --foreground 196 "✗ Failed to create Codeberg repository"
      fi
    fi
    ;;

  "Skip")
    gum style --foreground 214 "Skipping remote repository creation"
    ;;
  esac

  gum style \
    --foreground 212 --border-foreground 212 --border double \
    --align center --width 50 --margin "1 2" --padding "1 2" \
    "Project '$PROJECT_NAME' ready! 🚀"
}

# Make function available when sourced
if [ -n "$BASH_VERSION" ]; then
  export -f forgeproj
fi
