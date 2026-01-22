#!/usr/bin/env bash

# mkproj - Multi-language project creator
# Creates project templates for C, Rust, Python, Go, Zig, and ESP32-Std

set -e

# Check if gum is installed
if ! command -v gum &>/dev/null; then
  echo "Error: gum is not installed. Please install it from https://github.com/charmbracelet/gum"
  exit 1
fi

# Choose language
echo "🚀 Project Creator"
language=$(gum choose "C" "Rust" "Python" "Go" "Zig" "ESP32-Std")

case $language in
"C")
  echo "📁 Creating C project..."
  project_name=$(gum input --prompt "Enter project name: ")

  # Create project directory
  mkdir -p "$project_name"
  cd "$project_name"

  # Create main.c with Hello World
  cat >main.c <<'EOF'
#include <stdio.h>

int main() {
  printf("Hello, World!\n");
  return 0;
}
EOF

  # Create Justfile
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
    @./{{OUT}} + just clean

# Build + Run + Clean together
br:
    @just build && just run && just clean

# Remove built binary
clean:
    @rm {{OUT}}
EOF

  echo "✅ C project '$project_name' created successfully!"
  echo "📝 Files created: main.c, Justfile"
  echo "🔨 Run 'just build' to compile, 'just run' to execute, or 'just br' to build and run"
  echo "🔨 Use 'just --list' to view all the available commands"
  ;;

"Rust")
  echo "🦀 Creating Rust project..."
  project_name=$(gum input --prompt "Enter project name: ")

  # Check if cargo is installed
  if ! command -v cargo &>/dev/null; then
    echo "Error: cargo is not installed. Please install Rust from https://rustup.rs/"
    exit 1
  fi

  cargo new --bin "$project_name"
  echo "✅ Rust project '$project_name' created successfully!"
  echo "📝 Binary project created with Cargo.toml and src/main.rs"
  echo "🔨 Run 'cargo run' to compile and execute"
  ;;

"Python")
  echo "🐍 Creating Python project..."
  project_name=$(gum input --prompt "Enter project name: ")

  # Check if uv is installed
  if ! command -v uv &>/dev/null; then
    echo "Error: uv is not installed. Please install it from https://docs.astral.sh/uv/"
    exit 1
  fi

  uv init "$project_name"
  echo "✅ Python project '$project_name' created successfully!"
  echo "📝 Project created with pyproject.toml, main.py, and other files"
  echo "🔨 Run 'uv run main.py' to execute"
  ;;

"Go")
  echo "🐹 Creating Go project..."
  project_name=$(gum input --prompt "Enter project name: ")

  # Check if go is installed
  if ! command -v go &>/dev/null; then
    echo "Error: go is not installed. Please install Go from https://golang.org/dl/"
    exit 1
  fi

  # Create project directory
  mkdir -p "$project_name"
  cd "$project_name"

  # Initialize Go module
  go mod init "$project_name"

  # Create main.go with Hello World
  cat >main.go <<'EOF'
//Your Golang Code goes here
EOF

  # Create Justfile for consistency
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

  echo "✅ Go project '$project_name' created successfully!"
  echo "📝 Files created: go.mod, main.go, Justfile"
  echo "🔨 Run 'go run .' or 'just run' to execute"
  echo "🔨 Run 'go build' or 'just build' to compile"
  echo "🔨 Use 'just --list' to view all the available commands"
  ;;

"Zig")
  echo "⚡ Creating Zig project..."
  project_name=$(gum input --prompt "Enter project name: ")

  # Check if zig is installed
  if ! command -v zig &>/dev/null; then
    echo "Error: zig is not installed. Please install Zig from https://ziglang.org/download/"
    exit 1
  fi

  # Create project directory
  mkdir -p "$project_name"
  cd "$project_name"

  # Initialize Zig project
  zig init

  # Create Justfile for consistency with C workflow
  cat >Justfile <<'EOF'
# Variables
BINARY := "zig-out/bin/{{PROJECT_NAME}}"

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

  # Replace placeholder in Justfile with actual project name
  sed -i "s/{{PROJECT_NAME}}/$project_name/g" Justfile

  echo "✅ Zig project '$project_name' created successfully!"
  echo "📝 Files created: build.zig, src/main.zig, Justfile"
  echo "🔨 Run 'just build' to compile, 'just run' to execute, or 'just br' to build and run"
  echo "🔨 Run 'zig build' or 'just build' to compile"
  echo "🔨 Use 'just --list' to view all the available commands"
  ;;

"ESP32-Std")
  echo "🔧 Creating ESP32 Rust (std) project..."

  # Check if cargo is installed
  if ! command -v cargo &>/dev/null; then
    echo "Error: cargo is not installed. Please install Rust from https://rustup.rs/"
    exit 1
  fi

  # Check if cargo-generate is installed
  if ! command -v cargo-generate &>/dev/null; then
    echo "⚠️  cargo-generate is not installed. Installing now..."
    cargo install cargo-generate
  fi

  # Generate project using esp-idf-template
  # The template will prompt for project name and configuration
  cargo generate esp-rs/esp-idf-template cargo

  echo "✅ ESP32-Std project created successfully!"
  echo "📝 Project created with ESP-IDF template (std support)"
  echo "🔨 Run 'cargo build' to compile for your selected ESP32 target"
  echo "🔨 Run 'cargo run' to build, flash, and monitor"
  echo "💡 Make sure you have the ESP-IDF prerequisites installed"
  echo "📚 See: https://docs.esp-rs.org/book/"
  ;;
esac

echo "🎉 Happy coding!"
