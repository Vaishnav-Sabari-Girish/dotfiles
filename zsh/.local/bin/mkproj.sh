#!/usr/bin/env bash

# mkproj - Multi-language project creator
# Creates project templates for C, Rust, Python, Go, Zig, ESP32-Std, and STM32-Embassy

set -e

# Check if gum is installed
if ! command -v gum &>/dev/null; then
  echo "Error: gum is not installed. Please install it from https://github.com/charmbracelet/gum"
  exit 1
fi

# Choose language
echo "🚀 Project Creator"
language=$(gum choose "C" "Rust" "Python" "Go" "Zig" "ESP32-Std" "STM32-Embassy")

case $language in
"C")
  echo "📁 Creating C project..."
  project_name=$(gum input --prompt "Enter project name: ")
  mkdir -p "$project_name"
  cd "$project_name"

  cat >main.c <<'EOF'
#include <stdio.h>

int main() {
    printf("Hello, World!\n");
    return 0;
}
EOF

  cat >Justfile <<'EOF'
CFLAGS := "-Wall -Wextra -O2"
SRC := "main.c"
OUT := "main.out"

build:
    @gcc {{SRC}} -o {{OUT}} {{CFLAGS}}

run:
    @./{{OUT}}

br:
    @just build && just run && just clean

clean:
    @rm {{OUT}}
EOF
  echo "✅ C project '$project_name' created!"
  ;;

"Rust")
  echo "🦀 Creating Rust project..."
  project_name=$(gum input --prompt "Enter project name: ")
  if ! command -v cargo &>/dev/null; then
    echo "Error: cargo not found."
    exit 1
  fi
  cargo new --bin "$project_name"
  echo "✅ Rust project '$project_name' created!"
  ;;

"Python")
  echo "🐍 Creating Python project..."
  project_name=$(gum input --prompt "Enter project name: ")
  if ! command -v uv &>/dev/null; then
    echo "Error: uv not found."
    exit 1
  fi
  uv init "$project_name"
  echo "✅ Python project '$project_name' created!"
  ;;

"Go")
  echo "🐹 Creating Go project..."
  project_name=$(gum input --prompt "Enter project name: ")
  mkdir -p "$project_name"
  cd "$project_name"
  go mod init "$project_name"
  cat >main.go <<'EOF'
package main
import "fmt"

func main() {
    fmt.Println("Hello, Go!")
}
EOF
  cat >Justfile <<'EOF'
run:
    @go run .
build:
    @go build -o main .
clean:
    @rm -f main
EOF
  echo "✅ Go project '$project_name' created!"
  ;;

"Zig")
  echo "⚡ Creating Zig project..."
  project_name=$(gum input --prompt "Enter project name: ")
  mkdir -p "$project_name"
  cd "$project_name"
  zig init
  cat >Justfile <<'EOF'
run:
    @zig build run
build:
    @zig build
clean:
    @rm -rf zig-out .zig-cache
EOF
  echo "✅ Zig project '$project_name' created!"
  ;;

"ESP32-Std")
  echo "🔧 Creating ESP32 Rust (std) project..."
  if ! command -v cargo-generate &>/dev/null; then
    cargo install cargo-generate
  fi
  cargo generate esp-rs/esp-idf-template cargo
  ;;

"STM32-Embassy")
  echo "🦀 Creating STM32 Embassy (no-std) project..."
  project_name=$(gum input --prompt "Enter project name: ")

  # Ensure the cross-compilation target is installed
  echo "⚙️  Checking Rust target..."
  rustup target add thumbv7m-none-eabi || true

  # 1. Initialize Project
  echo "📦 Initializing Cargo project..."
  cargo new --bin "$project_name"
  cd "$project_name"

  # 2. Add Dependencies via cargo add
  echo "➕ Adding dependencies..."

  # Standard Crates
  cargo add cortex-m --features "inline-asm,critical-section-single-core"
  cargo add cortex-m-rt
  cargo add panic-halt
  cargo add heapless

  cargo add embassy-executor --features "arch-cortex-m,executor-thread"
  cargo add embassy-stm32 --features "stm32f103c8,unstable-pac,memory-x,time-driver-any,exti"
  cargo add embassy-time --features tick-hz-1_000_000

  # 3. .cargo/config.toml (Removed defmt.x)
  echo "⚙️  Configuring build target..."
  mkdir -p .cargo
  cat >.cargo/config.toml <<'EOF'
[target.'cfg(all(target_arch = "arm", target_os = "none"))']
runner = "probe-rs run --chip STM32F103C8"

rustflags = [
  "-C", "link-arg=-Tlink.x",
]

[build]
target = "thumbv7m-none-eabi" # Cortex-M3 for STM32F103

[env]
DEFMT_LOG = "trace"
EOF

  # 4. Embed.toml
  cat >Embed.toml <<'EOF'
[default.general]
chip = "STM32F103C8"

[default.reset]
halt_afterwards = false

[default.rtt]
enabled = false

[default.gdb]
enabled = false
EOF

  # 5. src/main.rs
  echo "📝 Writing main.rs..."
  cat >src/main.rs <<'EOF'
#![no_std]
#![no_main]

use panic_halt as _;
use embassy_executor::Spawner;
use embassy_stm32::usart::{Config, UartTx, InterruptHandler};
use embassy_stm32::peripherals;
use embassy_time::Timer;
use core::fmt::Write;
use heapless::String;
use embassy_stm32::bind_interrupts;

bind_interrupts!(struct Irqs {
    USART1 => InterruptHandler<peripherals::USART1>;
});

#[embassy_executor::main]
async fn main(_spawner: Spawner) {
    let p = embassy_stm32::init(Default::default());

    // USART1 TX on PA9, using DMA1 Channel 4 (Standard for Blue Pill)
    let mut tx = UartTx::new(p.USART1, p.PA9, p.DMA1_CH4, Config::default()).unwrap();

    loop {
        let mut s: String<64> = String::new();
        let _ = writeln!(s, "Embassy Running! Uptime: {}s\r\n", embassy_time::Instant::now().as_secs());
        
        // Async write to FTDI
        let _ = tx.write(s.as_bytes()).await;

        Timer::after_millis(1000).await;
    }
}
EOF

  # 6. Justfile
  cat >Justfile <<'EOF'
run:
    @cargo run

build:
    @cargo build --release

clean:
    @cargo clean
EOF

  echo "✅ STM32 project '$project_name' created!"
  echo "📝 Hardware: STM32F103C8 (Blue Pill)"
  echo "🔌 Wiring: Connect PA9 (TX) to FTDI RX"
  echo "🔨 Run 'just run' to flash."
  ;;
esac

echo "🎉 Happy coding!"
