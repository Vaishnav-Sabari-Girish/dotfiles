#!/usr/bin/env bash

# mkproj - Multi-language project creator
# Creates project templates for C, Rust, Python, Go, Zig, ESP32-Std, STM32-Embassy, and RP2040-HAL

set -e

# Check if gum is installed
if ! command -v gum &>/dev/null; then
  echo "Error: gum is not installed. Please install it from https://github.com/charmbracelet/gum"
  exit 1
fi

# Choose language
echo "🚀 Project Creator"
language=$(gum choose "C" "Rust" "Python" "Go" "Zig" "ESP32-Std" "STM32-Embassy" "RP2040-HAL")

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

"RP2040-HAL")
  echo "🍓 Creating RP2040 (no-std) project..."
  project_name=$(gum input --prompt "Enter project name: ")

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
  cargo add rp2040-hal@0.11.0 --features "critical-section-impl"
  cargo add smart-leds
  cargo add ws2812-pio

  # 3. Append Release/Dev Profiles to Cargo.toml
  echo "⚙️  Configuring build profiles..."
  cat >>Cargo.toml <<'EOF'

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
use smart_leds::{SmartLedsWrite, RGB8};
use ws2812_pio::Ws2812;

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

    let (mut pio, sm0, _, _, _) = pac.PIO0.split(&mut pac.RESETS);
    
    // Set up the WS2812 NeoPixel on GP16
    let mut ws = Ws2812::new(
        pins.gpio16.into_function(),
        &mut pio,
        sm0,
        clocks.peripheral_clock.freq(),
        timer.count_down(),
    );

    loop {
        // Red
        ws.write([RGB8::new(32, 0, 0)].iter().cloned()).unwrap();
        delay.delay_ms(500);
        
        // Green
        ws.write([RGB8::new(0, 32, 0)].iter().cloned()).unwrap();
        delay.delay_ms(500);
        
        // Blue
        ws.write([RGB8::new(0, 0, 32)].iter().cloned()).unwrap();
        delay.delay_ms(500);
    }
}
EOF

  # 7. Download Flash Nuke Utility
  echo "🧹 Downloading flash_nuke.uf2 utility..."
  curl -L -O -s https://datasheets.raspberrypi.com/soft/flash_nuke.uf2

  # 8. Justfile
  cat >Justfile <<'EOF'
run:
    @cargo run

build:
    @cargo build --release

clean:
    @cargo clean
EOF

  echo "✅ RP2040 project '$project_name' created!"
  echo "📝 Hardware: Waveshare RP2040 Zero"
  echo "🔌 NeoPixel on GP16"
  echo "🔨 Run 'just run' to flash."
  ;;
esac

echo "🎉 Happy coding!"
