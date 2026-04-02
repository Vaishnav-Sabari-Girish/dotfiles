#!/usr/bin/env bash

# mkproj - Multi-language project creator
# Creates project templates for C, Rust, Python, Go, Zig, ESP32-Std, STM32-Embassy, and RP2040-HAL

set -e

# Check if fzf is installed
if ! command -v fzf &>/dev/null; then
  echo "Error: fzf is not installed. Please install it using your package manager."
  exit 1
fi

# Choose language using fzf
echo "🚀 Project Creator"
language=$(printf "C\nRust\nPython\nGo\nZig\nESP32-Std\nSTM32-Embassy\nRP2040-HAL" | fzf --prompt="Choose language: " --height=10 --layout=reverse --border --cycle)

# Exit if the user pressed Esc or Ctrl-C in fzf
if [ -z "$language" ]; then
  echo "Aborted."
  exit 0
fi

case $language in
"C")
  echo "📁 Creating C project..."
  read -r -p "Enter project name: " project_name
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
  read -r -p "Enter project name: " project_name
  if ! command -v cargo &>/dev/null; then
    echo "Error: cargo not found."
    exit 1
  fi
  cargo new --bin "$project_name"
  echo "✅ Rust project '$project_name' created!"
  ;;

"Python")
  echo "🐍 Creating Python project..."
  read -r -p "Enter project name: " project_name
  if ! command -v uv &>/dev/null; then
    echo "Error: uv not found."
    exit 1
  fi
  uv init "$project_name"
  echo "✅ Python project '$project_name' created!"
  ;;

"Go")
  echo "🐹 Creating Go project..."
  read -r -p "Enter project name: " project_name
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
  read -r -p "Enter project name: " project_name
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
  read -r -p "Enter project name: " project_name
  if ! command -v cargo-generate &>/dev/null; then
    cargo install cargo-generate
  fi

  cargo generate esp-rs/esp-idf-template cargo --name "$project_name"
  cd "$project_name"

  echo "📊 Adding build-size.sh profiling script..."
  cat >build-size.sh <<'EOF'
#!/usr/bin/env zsh

set -e

WORKSPACE_ROOT="$(cd "$(dirname "$0")" && pwd)"
TARGET="riscv32imc-esp-espidf"

# gruvbox colors
local rst='\033[0m'
local bold='\033[1m'
local dim='\033[2m'
local bg0='\033[38;2;40;40;40m'
local fg='\033[38;2;235;219;178m'
local fg0='\033[38;2;251;241;199m'
local red='\033[38;2;251;73;52m'
local green='\033[38;2;184;187;38m'
local yellow='\033[38;2;250;189;47m'
local blue='\033[38;2;131;165;152m'
local purple='\033[38;2;211;134;155m'
local aqua='\033[38;2;142;192;124m'
local orange='\033[38;2;254;128;25m'
local gray='\033[38;2;146;131;116m'

# ESP32-C3 typical specs
FLASH_MAX=$((4096 * 1024)) # 4MB
RAM_MAX=$((400 * 1024))    # ~400KB internal SRAM

# prerequisite checks
missing=()
if ! command -v cargo &>/dev/null; then
    missing+=("  ${orange}cargo${rst}       ${gray}https://rustup.rs${rst}")
fi
if ! command -v jq &>/dev/null; then
    missing+=("  ${orange}jq${rst}          ${gray}install via system package manager${rst}")
fi
if ! command -v rust-size &>/dev/null; then
    missing+=("  ${orange}rust-size${rst}   ${gray}cargo install cargo-binutils && rustup component add llvm-tools${rst}")
fi
if ! command -v bc &>/dev/null; then
    missing+=("  ${orange}bc${rst}          ${gray}install via system package manager${rst}")
fi
if (( ${#missing} > 0 )); then
    printf "${red}${bold}missing required tools:${rst}\n"
    for m in "${missing[@]}"; do
        printf "$m\n"
    done
    exit 1
fi

usage() {
    echo "Usage: ./build-size.sh <project>"
    exit 1
}

bar() {
    local used=$1 max=$2 width=40
    local pct=$((used * 100 / max))
    local filled=$((used * width / max))
    (( filled > width )) && filled=$width
    local empty=$((width - filled))

    local color=$green
    (( pct > 70 )) && color=$yellow
    (( pct > 90 )) && color=$orange
    (( pct > 98 )) && color=$red

    printf "${dim}[${rst}"
    printf "${color}%${filled}s${rst}" | tr ' ' '#'
    printf "${gray}%${empty}s${rst}" | tr ' ' '.'
    printf "${dim}]${rst}"
    printf " ${color}${bold}%d%%${rst}" "$pct"
}

print_section() {
    local name=$1 size=$2 color=$3
    printf "  ${color}%-18s${rst} ${fg}%'10d${rst} ${gray}bytes${rst}  ${dim}(%6.1f KB)${rst}\n" \
        "$name" "$size" "$(echo "scale=1; $size / 1024" | bc)"
}

if [[ $# -lt 1 ]]; then
    usage
fi

project="$1"
project_dir="$WORKSPACE_ROOT/$project"

if [[ ! -d "$project_dir" ]]; then
    echo "${red}error:${rst} project '$project' not found"
    exit 1
fi

# 2. Get Cargo metadata
METADATA="$(cargo metadata --no-deps --format-version 1 --manifest-path "$project_dir/Cargo.toml" 2>/dev/null)"

TARGET_DIR="$(echo "$METADATA" | jq -r '.target_directory')"

if [[ -z "$TARGET_DIR" || "$TARGET_DIR" == "null" ]]; then
    echo "${red}error:${rst} failed to determine target directory via cargo metadata"
    exit 1
fi

# Extract the exact binary name from Cargo.toml so we don't guess based on the folder path
BIN_NAME="$(echo "$METADATA" | jq -r '.packages[0].targets[] | select(.kind[] == "bin") | .name' | head -n 1)"
BINARY_DIR="$TARGET_DIR/$TARGET/release"

# 3. Build and calculate sizes
cd "$project_dir"

printf "${dim}building ${fg0}${bold}$BIN_NAME${rst} ${dim}(release, $TARGET)${rst}\n"
cargo build --release --target "$TARGET" 2>&1

binary="$BINARY_DIR/$BIN_NAME"
if [[ ! -f "$binary" ]]; then
    echo "${red}error:${rst} binary not found at $binary"
    exit 1
fi

# parse ESP-IDF sections
typeset -A sections
while read -r name size _addr; do
    sections[$name]=$size
done < <(rust-size -A "$binary" | grep -E '^\.')

# Flash takes the flash text/rodata, plus the initial values for DRAM and IRAM
flash_total=$(( ${sections[.flash.text]:-0} + ${sections[.flash.rodata]:-0} + ${sections[.dram0.data]:-0} + ${sections[.iram0.text]:-0} ))

# RAM is the sum of Instruction RAM (IRAM) and Data RAM (DRAM)
ram_total=$(( ${sections[.iram0.text]:-0} + ${sections[.iram0.vectors]:-0} + ${sections[.dram0.data]:-0} + ${sections[.dram0.bss]:-0} ))

echo ""
printf "${yellow}${bold}  FLASH${rst}  "
bar $flash_total $FLASH_MAX
printf "  ${dim}%'d / %'d bytes${rst}\n" $flash_total $FLASH_MAX
echo ""
print_section ".flash.text"   "${sections[.flash.text]:-0}"   "$blue"
print_section ".flash.rodata" "${sections[.flash.rodata]:-0}" "$purple"
print_section ".iram0.text"   "${sections[.iram0.text]:-0}"   "$aqua"
print_section ".dram0.data"   "${sections[.dram0.data]:-0}"   "$orange"

echo ""
printf "${aqua}${bold}  RAM${rst}    "
bar $ram_total $RAM_MAX
printf "  ${dim}%'d / %'d bytes${rst}\n" $ram_total $RAM_MAX
echo ""
print_section ".iram0.text"   "${sections[.iram0.text]:-0}"   "$blue"
print_section ".iram0.vectors" "${sections[.iram0.vectors]:-0}" "$aqua"
print_section ".dram0.data"   "${sections[.dram0.data]:-0}"   "$orange"
print_section ".dram0.bss"    "${sections[.dram0.bss]:-0}"    "$gray"
echo ""
EOF
  chmod +x build-size.sh

  echo "📝 Writing Justfile..."
  cat >Justfile <<'EOF'
sz:
    @./build-size.sh .

f: sz
    @cargo run --release
EOF

  echo "✅ ESP32 project '$project_name' created with memory profiling tools!"
  ;;

"STM32-Embassy")
  echo "🦀 Creating STM32 Embassy (no-std) project..."
  read -r -p "Enter project name: " project_name

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

  # 3. .cargo/config.toml
  echo "⚙️  Configuring build target..."
  mkdir -p .cargo
  cat >.cargo/config.toml <<'EOF'
[target.'cfg(all(target_arch = "arm", target_os = "none"))']
runner = "probe-rs run --chip STM32F103C8"

rustflags = [
  "-C", "link-arg=-Tlink.x",
]

[build]
target = "thumbv7m-none-eabi"

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

    let mut tx = UartTx::new(p.USART1, p.PA9, p.DMA1_CH4, Config::default()).unwrap();

    loop {
        let mut s: String<64> = String::new();
        let _ = writeln!(s, "Embassy Running! Uptime: {}s\r\n", embassy_time::Instant::now().as_secs());
        
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

"RP2040-HAL")
  echo "🍓 Creating RP2040 (no-std) project..."
  read -r -p "Enter project name: " project_name

  # Ensure the cross-compilation target is installed
  echo "⚙️  Checking Rust target..."
  rustup target add thumbv6m-none-eabi || true

  # 1. Initialize Project
  echo "📦 Initializing Cargo project..."
  cargo new --bin "$project_name"
  cd "$project_name"

  # Force Cargo edition to 2024 to support #[unsafe(...)]
  sed -i 's/edition = "2021"/edition = "2024"/' Cargo.toml

  # 2. Add Dependencies via cargo add
  echo "➕ Adding dependencies..."
  cargo add cortex-m
  cargo add cortex-m-rt
  cargo add embedded-hal
  cargo add fugit
  cargo add panic-halt
  cargo add rp2040-boot2
  cargo add rp2040-hal --features "critical-section-impl"

  # 3. Append Release/Dev Profiles to Cargo.toml
  echo "⚙️  Configuring build profiles..."
  cat >>Cargo.toml <<EOF

[[bin]]
name = "$project_name"
test = false
bench = false
doctest = false

[profile.dev]
codegen-units = 1 
debug = 2 
debug-assertions = true
incremental = false 
opt-level = 3
overflow-checks = true

[profile.release]
codegen-units = 1 
debug = 2 
debug-assertions = false
incremental = false 
lto = 'fat'
opt-level = 3
overflow-checks = false
EOF

  # 4. .cargo/config.toml
  echo "⚙️  Configuring build target..."
  mkdir -p .cargo
  cat >.cargo/config.toml <<'EOF'
[build]
target = "thumbv6m-none-eabi"

[target.'cfg(all(target_arch = "arm", target_os = "none"))']
runner = "elf2uf2-rs deploy --family rp2040"
linker = "flip-link"
rustflags = [
  "-C", "link-arg=--nmagic",
  "-C", "link-arg=-Tlink.x",
  "-C", "no-vectorize-loops",
]

[env]
DEFMT_LOG = "debug"
EOF

  # 5. memory.x
  echo "🧠 Configuring memory map..."
  cat >memory.x <<'EOF'
MEMORY {
    BOOT2 : ORIGIN = 0x10000000, LENGTH = 0x100
    FLASH : ORIGIN = 0x10000100, LENGTH = 2048K - 0x100
    RAM   : ORIGIN = 0x20000000, LENGTH = 256K
}

EXTERN(BOOT2_FIRMWARE)

SECTIONS {
    /* ### Boot loader */
    .boot2 ORIGIN(BOOT2) :
    {
        KEEP(*(.boot2));
    } > BOOT2
} INSERT BEFORE .text;
EOF

  # 6. src/main.rs
  echo "📝 Writing main.rs..."
  cat >src/main.rs <<'EOF'
#![no_std]
#![no_main]

use cortex_m_rt::entry;
use panic_halt as _;
use rp2040_hal::{
    clocks::{init_clocks_and_plls, Clock},
    pac,
    pio::PIOExt,
    timer::Timer,
    watchdog::Watchdog,
    Sio,
};

// --- THE IGNITION KEY ---
// This places the 256-byte bootloader at the very start of the flash memory.
// Without this, the RP2040 ROM refuses to jump to our code.
#[unsafe(link_section = ".boot2")]
#[used]
pub static BOOT2: [u8; 256] = rp2040_boot2::BOOT_LOADER_W25Q080;
// ------------------------

#[entry]
fn main() -> ! {
    let mut pac = pac::Peripherals::take().unwrap();
    let cp = pac::CorePeripherals::take().unwrap();
    
    let mut wdt = Watchdog::new(pac.WATCHDOG);

    let clocks = init_clocks_and_plls(
        12_000_000u32,
        pac.XOSC,
        pac.CLOCKS,
        pac.PLL_SYS,
        pac.PLL_USB,
        &mut pac.RESETS,
        &mut wdt,
    )
    .ok()
    .unwrap();

    let timer = Timer::new(pac.TIMER, &mut pac.RESETS, &clocks);
    let mut delay = cortex_m::delay::Delay::new(cp.SYST, clocks.system_clock.freq().to_Hz());

    let sio = Sio::new(pac.SIO);
    let pins = rp2040_hal::gpio::Pins::new(
        pac.IO_BANK0,
        pac.PADS_BANK0,
        sio.gpio_bank0,
        &mut pac.RESETS,
    );

    loop {
        cortex_m::asm::wfi();
    }
}
EOF

  # 7. Download Flash Nuke Utility
  echo "🧹 Downloading flash_nuke.uf2 utility..."
  curl -L -s -o flash_nuke.uf2 https://raw.githubusercontent.com/Pwea/Flash-Nuke/main/flash_nuke.uf2

  # 8. Add build-size.sh
  echo "📊 Adding build-size.sh profiling script..."
  cat >build-size.sh <<'EOF'
#!/usr/bin/env zsh

set -e

WORKSPACE_ROOT="$(cd "$(dirname "$0")" && pwd)"
TARGET="thumbv6m-none-eabi"

# gruvbox colors
local rst='\033[0m'
local bold='\033[1m'
local dim='\033[2m'
local bg0='\033[38;2;40;40;40m'
local fg='\033[38;2;235;219;178m'
local fg0='\033[38;2;251;241;199m'
local red='\033[38;2;251;73;52m'
local green='\033[38;2;184;187;38m'
local yellow='\033[38;2;250;189;47m'
local blue='\033[38;2;131;165;152m'
local purple='\033[38;2;211;134;155m'
local aqua='\033[38;2;142;192;124m'
local orange='\033[38;2;254;128;25m'
local gray='\033[38;2;146;131;116m'

FLASH_MAX=$((2048 * 1024))
RAM_MAX=$((256 * 1024))

# prerequisite checks
missing=()
if ! command -v cargo &>/dev/null; then
    missing+=("  ${orange}cargo${rst}       ${gray}https://rustup.rs${rst}")
fi
if ! command -v jq &>/dev/null; then
    missing+=("  ${orange}jq${rst}          ${gray}install via system package manager${rst}")
fi
if ! command -v flip-link &>/dev/null; then
    missing+=("  ${orange}flip-link${rst}   ${gray}cargo install flip-link${rst}")
fi
if ! command -v rust-size &>/dev/null; then
    missing+=("  ${orange}rust-size${rst}   ${gray}cargo install cargo-binutils && rustup component add llvm-tools${rst}")
fi
if ! command -v bc &>/dev/null; then
    missing+=("  ${orange}bc${rst}          ${gray}install via system package manager${rst}")
fi
if (( ${#missing} > 0 )); then
    printf "${red}${bold}missing required tools:${rst}\n"
    for m in "${missing[@]}"; do
        printf "$m\n"
    done
    exit 1
fi

usage() {
    echo "Usage: ./build-size.sh <project>"
    exit 1
}

bar() {
    local used=$1 max=$2 width=40
    local pct=$((used * 100 / max))
    local filled=$((used * width / max))
    (( filled > width )) && filled=$width
    local empty=$((width - filled))

    local color=$green
    (( pct > 70 )) && color=$yellow
    (( pct > 90 )) && color=$orange
    (( pct > 98 )) && color=$red

    printf "${dim}[${rst}"
    printf "${color}%${filled}s${rst}" | tr ' ' '#'
    printf "${gray}%${empty}s${rst}" | tr ' ' '.'
    printf "${dim}]${rst}"
    printf " ${color}${bold}%d%%${rst}" "$pct"
}

print_section() {
    local name=$1 size=$2 color=$3
    printf "  ${color}%-18s${rst} ${fg}%'10d${rst} ${gray}bytes${rst}  ${dim}(%6.1f KB)${rst}\n" \
        "$name" "$size" "$(echo "scale=1; $size / 1024" | bc)"
}

# 1. Parse arguments and check directories first
if [[ $# -lt 1 ]]; then
    usage
fi

project="$1"
project_dir="$WORKSPACE_ROOT/$project"

if [[ ! -d "$project_dir" ]]; then
    echo "${red}error:${rst} project '$project' not found"
    exit 1
fi

# 2. Get Cargo metadata
METADATA="$(cargo metadata --no-deps --format-version 1 --manifest-path "$project_dir/Cargo.toml" 2>/dev/null)"

TARGET_DIR="$(echo "$METADATA" | jq -r '.target_directory')"

if [[ -z "$TARGET_DIR" || "$TARGET_DIR" == "null" ]]; then
    echo "${red}error:${rst} failed to determine target directory via cargo metadata"
    exit 1
fi

# Extract exact binary name to support "." as argument
BIN_NAME="$(echo "$METADATA" | jq -r '.packages[0].targets[] | select(.kind[] == "bin") | .name' | head -n 1)"
BINARY_DIR="$TARGET_DIR/$TARGET/release"

# 3. Build and calculate sizes
cd "$project_dir"

printf "${dim}building ${fg0}${bold}$BIN_NAME${rst} ${dim}(release, $TARGET)${rst}\n"
cargo build --release --target "$TARGET" 2>&1

binary="$BINARY_DIR/$BIN_NAME"
if [[ ! -f "$binary" ]]; then
    echo "${red}error:${rst} binary not found at $binary"
    exit 1
fi

# parse sections
typeset -A sections
while read -r name size _addr; do
    sections[$name]=$size
done < <(rust-size -A "$binary" | grep -E '^\.')

flash_total=$(( ${sections[.boot2]:-0} + ${sections[.vector_table]:-0} + ${sections[.text]:-0} + ${sections[.rodata]:-0} + ${sections[.data]:-0} ))
ram_total=$(( ${sections[.data]:-0} + ${sections[.bss]:-0} + ${sections[.uninit]:-0} ))

echo ""
printf "${yellow}${bold}  FLASH${rst}  "
bar $flash_total $FLASH_MAX
printf "  ${dim}%'d / %'d bytes${rst}\n" $flash_total $FLASH_MAX
echo ""
print_section ".text"         "${sections[.text]:-0}"         "$blue"
print_section ".rodata"       "${sections[.rodata]:-0}"       "$purple"
print_section ".vector_table" "${sections[.vector_table]:-0}" "$aqua"
print_section ".boot2"        "${sections[.boot2]:-0}"        "$aqua"
print_section ".data"         "${sections[.data]:-0}"         "$orange"

echo ""
printf "${aqua}${bold}  RAM${rst}    "
bar $ram_total $RAM_MAX
printf "  ${dim}%'d / %'d bytes${rst}\n" $ram_total $RAM_MAX
echo ""
print_section ".bss"    "${sections[.bss]:-0}"    "$blue"
print_section ".data"   "${sections[.data]:-0}"   "$orange"
print_section ".uninit" "${sections[.uninit]:-0}" "$gray"
echo ""
EOF
  chmod +x build-size.sh

  # 9. Justfile
  cat >Justfile <<'EOF'
# Grab the name of the current directory to use as the binary name
BIN_NAME := `basename "$PWD"`

build:
    @cargo build --release

sz:
    @./build-size.sh .

run: sz
    @echo "📦 Converting ELF to UF2..."
    @elf2uf2-rs convert target/thumbv6m-none-eabi/release/{{BIN_NAME}} flash.uf2
    @echo "🔌 Mounting RP2040 synchronously (requires sudo)..."
    @sudo mount -t vfat -o sync /dev/sda1 /mnt/rp2
    @echo "⚡ Flashing memory..."
    @sudo cp flash.uf2 /mnt/rp2/
    @echo "✅ Done! Program Flashed successfully"
    @sudo umount /mnt/rp2/ || true

nuke:
    @echo "🧹 Nuking RP2040 flash memory..."
    @if mountpoint -q /mnt/rp2; then \
        echo "✓ Drive already mounted at /mnt/rp2"; \
    else \
        echo "🔌 Mounting RP2040..."; \
        sudo mount -t vfat -o sync /dev/sda1 /mnt/rp2; \
    fi
    @echo "💣 Copying flash_nuke.uf2..."
    @sudo cp flash_nuke.uf2 /mnt/rp2/
    @echo "⏳ Waiting for flash erase to complete..."
    @sleep 2
    @sudo umount /mnt/rp2/ || true
    @echo "✅ Flash memory nuked! Board will reboot."

clean:
    @cargo clean
    @rm -f flash.uf2
EOF

  echo "✅ RP2040 project '$project_name' created with memory profiling!"
  echo "📝 Hardware: Waveshare RP2040 Zero"
  echo "🔌 NeoPixel on GP16"
  echo "🔨 Run 'just run' to flash."
  ;;
esac

echo "🎉 Happy coding!"
