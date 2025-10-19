#!/usr/bin/env bash

# mkproj - Multi-language project creator
# Creates project templates for C, Rust, Python, and Go

set -e

# Check if gum is installed
if ! command -v gum &>/dev/null; then
  echo "Error: gum is not installed. Please install it from https://github.com/charmbracelet/gum"
  exit 1
fi

# Choose language
echo "🚀 Project Creator"
language=$(gum choose "C" "Rust" "Python" "Go")

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
package main

import "fmt"

func main() {
    fmt.Println("Hello, World!")
}
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
esac

echo "🎉 Happy coding!"
