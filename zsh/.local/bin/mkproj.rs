#!/usr/bin/env rust-script
//! ```cargo
//! [dependencies]
//! inquire = "0.7"
//! ```

use inquire::{Select, Text};
use std::fs::{self, File};
use std::io::Write;
use std::process::{Command, exit};
use std::env;
use std::path::Path;

fn main() {
    println!("🚀 Project Creator");

    let languages = vec![
        "C",
        "Ada",
        "D-simple",
        "Rust",
        "Python",
        "Go",
        "Zig",
        "ESP32-Std",
        "STM32-Embassy",
        "RP2040-HAL",
        "nRF52-Embassy",
        "Zephyr",
        "Arduino",
    ];

    let language = match Select::new("Choose language:", languages)
        .with_page_size(15)
        .prompt() {
        Ok(choice) => choice,
        Err(_) => {
            println!("Aborted.");
            exit(0);
        }
    };

    match language {
        "C" => create_c(),
        "Rust" => create_rust(),
        "Python" => create_python(),
        "Go" => create_go(),
        "Zig" => create_zig(),
        "ESP32-Std" => create_esp32_std(),
        "STM32-Embassy" => create_stm32_embassy(),
        "RP2040-HAL" => create_rp2040_hal(),
        "nRF52-Embassy" => create_nrf52_embassy(),
        "Zephyr" => create_zephyr(),
        "Arduino" => create_arduino(),
        "Ada" => create_ada(),
        "D-simple" => create_d_simple(),
        _ => unreachable!(),
    }

    println!("🎉 Happy coding!");
}

fn prompt_project_name() -> String {
    Text::new("Enter project name:")
        .prompt()
        .unwrap_or_else(|_| {
            println!("Aborted.");
            exit(0);
        })
}

fn create_dir_and_cd(name: &str) {
    fs::create_dir_all(name).expect("Failed to create project directory");
    env::set_current_dir(name).expect("Failed to change directory");
}

fn write_file(path: &str, content: &str) {
    let mut file = File::create(path).expect(&format!("Failed to create {}", path));
    file.write_all(content.as_bytes())
        .expect(&format!("Failed to write {}", path));
}

// ==================== C ====================
fn create_c() {
    println!("📁 Creating C project...");
    let project_name = prompt_project_name();
    create_dir_and_cd(&project_name);

    write_file(
        "main.c",
        r#"#include <stdio.h>
int main() {
  printf("Hello, World!\n");
  return 0;
}
"#,
    );

    write_file(
        "Grimoire.toml",
        r#"version = "1"

[ingredients]
c_compiler = "gcc"
cflags = "-Wall -Wextra -O2"
src = "main.c"
out = "main.out"

[sigil.build]
description = "Build the C project"
language = "shell"
silent = true
run = "{{c_compiler}} {{src}} -o {{out}} {{cflags}}"

[sigil.run]
description = "Run the binary"
language = "shell"
silent = true
run = "./{{out}}"

[sigil.br]
description = "Build + Run + Clean"
language = "shell"
silent = true
run = '''
{{c_compiler}} {{src}} -o {{out}} {{cflags}}
./{{out}}
rm -f {{out}}
'''

[sigil.clean]
description = "Remove the binary"
language = "shell"
silent = true
run = "rm -f {{out}}"
"#,
    );

    println!("✅ C project '{}' created!", project_name);
}

// ==================== Rust ====================
fn create_rust() {
    println!("🦀 Creating Rust project...");
    let project_name = prompt_project_name();

    if Command::new("cargo").arg("--version").output().is_err() {
        eprintln!("Error: cargo not found.");
        exit(1);
    }

    let status = Command::new("cargo")
        .args(["new", "--bin", &project_name])
        .status()
        .expect("Failed to run cargo new");

    if !status.success() {
        exit(1);
    }

    println!("✅ Rust project '{}' created!", project_name);
}

// ==================== Python ====================
fn create_python() {
    println!("🐍 Creating Python project...");
    let project_name = prompt_project_name();

    if Command::new("uv").arg("--version").output().is_err() {
        eprintln!("Error: uv not found.");
        exit(1);
    }

    let status = Command::new("uv")
        .args(["init", &project_name])
        .status()
        .expect("Failed to run uv init");

    if !status.success() {
        exit(1);
    }

    println!("✅ Python project '{}' created!", project_name);
}

// ==================== Go ====================
fn create_go() {
    println!("🐹 Creating Go project...");
    let project_name = prompt_project_name();
    create_dir_and_cd(&project_name);

    let status = Command::new("go")
        .args(["mod", "init", &project_name])
        .status()
        .expect("Failed to run go mod init");

    if !status.success() {
        exit(1);
    }

    write_file(
        "main.go",
        r#"package main
import "fmt"
func main() {
    fmt.Println("Hello, Go!")
}
"#,
    );

    write_file(
        "Grimoire.toml",
        r#"version = "1"

[sigil.run]
description = "Run the Go project"
language = "shell"
silent = true
run = "go run ."

[sigil.build]
description = "Build the binary"
language = "shell"
silent = true
run = "go build -o main ."

[sigil.clean]
description = "Remove the binary"
language = "shell"
silent = true
run = "rm -f main"
"#,
    );

    println!("✅ Go project '{}' created!", project_name);
}

// ==================== Zig ====================
fn create_zig() {
    println!("⚡ Creating Zig project...");
    let project_name = prompt_project_name();
    create_dir_and_cd(&project_name);

    let status = Command::new("zig")
        .arg("init")
        .status()
        .expect("Failed to run zig init");

    if !status.success() {
        exit(1);
    }

    write_file(
        "Grimoire.toml",
        r#"version = "1"

[sigil.run]
description = "Run the Zig project"
language = "shell"
silent = true
run = "zig build run"

[sigil.build]
description = "Build the project"
language = "shell"
silent = true
run = "zig build"

[sigil.clean]
description = "Clean build artifacts"
language = "shell"
silent = true
run = "rm -rf zig-out .zig-cache"
"#,
    );

    println!("✅ Zig project '{}' created!", project_name);
}

// ==================== ESP32-Std ====================
fn create_esp32_std() {
    println!("🔧 Creating ESP32 Rust (std) project...");
    let project_name = prompt_project_name();

    if Command::new("cargo-generate").arg("--version").output().is_err() {
        println!("Installing cargo-generate...");
        let status = Command::new("cargo")
            .args(["install", "cargo-generate"])
            .status()
            .expect("Failed to install cargo-generate");
        if !status.success() {
            exit(1);
        }
    }

    let status = Command::new("cargo")
        .args([
            "generate",
            "esp-rs/esp-idf-template",
            "cargo",
            "--name",
            &project_name,
        ])
        .status()
        .expect("Failed to run cargo generate");

    if !status.success() {
        exit(1);
    }

    env::set_current_dir(&project_name).expect("Failed to cd into project");

    println!("📊 Adding build-size.sh profiling script...");
    write_file(
        "build-size.sh",
        r#"#!/usr/bin/env zsh
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
RAM_MAX=$((400 * 1024)) # ~400KB internal SRAM
# prerequisite checks
missing=()
if ! command -v cargo &>/dev/null; then
    missing+=(" ${orange}cargo${rst} ${gray}https://rustup.rs${rst}")
fi
if ! command -v jq &>/dev/null; then
    missing+=(" ${orange}jq${rst} ${gray}install via system package manager${rst}")
fi
if ! command -v rust-size &>/dev/null; then
    missing+=(" ${orange}rust-size${rst} ${gray}cargo install cargo-binutils && rustup component add llvm-tools${rst}")
fi
if ! command -v bc &>/dev/null; then
    missing+=(" ${orange}bc${rst} ${gray}install via system package manager${rst}")
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
    printf " ${color}%-18s${rst} ${fg}%'10d${rst} ${gray}bytes${rst} ${dim}(%6.1f KB)${rst}\n" \
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
printf "${yellow}${bold} FLASH${rst} "
bar $flash_total $FLASH_MAX
printf " ${dim}%'d / %'d bytes${rst}\n" $flash_total $FLASH_MAX
echo ""
print_section ".flash.text" "${sections[.flash.text]:-0}" "$blue"
print_section ".flash.rodata" "${sections[.flash.rodata]:-0}" "$purple"
print_section ".iram0.text" "${sections[.iram0.text]:-0}" "$aqua"
print_section ".dram0.data" "${sections[.dram0.data]:-0}" "$orange"
echo ""
printf "${aqua}${bold} RAM${rst} "
bar $ram_total $RAM_MAX
printf " ${dim}%'d / %'d bytes${rst}\n" $ram_total $RAM_MAX
echo ""
print_section ".iram0.text" "${sections[.iram0.text]:-0}" "$blue"
print_section ".iram0.vectors" "${sections[.iram0.vectors]:-0}" "$aqua"
print_section ".dram0.data" "${sections[.dram0.data]:-0}" "$orange"
print_section ".dram0.bss" "${sections[.dram0.bss]:-0}" "$gray"
echo ""
"#,
    );

    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        let mut perms = fs::metadata("build-size.sh").unwrap().permissions();
        perms.set_mode(0o755);
        fs::set_permissions("build-size.sh", perms).ok();
    }

    println!("📝 Writing Grimoire.toml...");
    write_file(
        "Grimoire.toml",
        r#"version = "1"

[sigil.sz]
description = "Show binary size"
language = "shell"
silent = true
run = "./build-size.sh ."

[sigil.f]
description = "Size + Run (release)"
language = "shell"
silent = true
run = '''
./build-size.sh .
cargo run --release
'''
"#,
    );

    println!("✅ ESP32 project '{}' created with memory profiling tools!", project_name);
}

// ==================== STM32-Embassy ====================
fn create_stm32_embassy() {
    println!("🦀 Creating STM32 Embassy (no-std) project...");
    let project_name = prompt_project_name();

    println!("⚙️ Checking Rust target...");
    let _ = Command::new("rustup")
        .args(["target", "add", "thumbv7m-none-eabi"])
        .status();

    println!("📦 Initializing Cargo project...");
    let status = Command::new("cargo")
        .args(["new", "--bin", &project_name])
        .status()
        .expect("Failed to run cargo new");
    if !status.success() {
        exit(1);
    }

    env::set_current_dir(&project_name).expect("Failed to cd");

    println!("➕ Adding dependencies...");
    let deps = [
        ("cortex-m", &["--features", "inline-asm,critical-section-single-core"][..]),
        ("cortex-m-rt", &[][..]),
        ("panic-halt", &[][..]),
        ("heapless", &[][..]),
        ("embassy-executor", &["--features", "executor-thread"][..]),
        (
            "embassy-stm32",
            &["--features", "stm32f103c8,unstable-pac,memory-x,time-driver-any,exti"][..],
        ),
        ("embassy-time", &["--features", "tick-hz-1_000_000"][..]),
    ];

    for (crate_name, features) in deps {
        let mut cmd = Command::new("cargo");
        cmd.arg("add").arg(crate_name);
        for f in features {
            cmd.arg(f);
        }
        let status = cmd.status().expect("Failed to run cargo add");
        if !status.success() {
            eprintln!("Warning: failed to add {}", crate_name);
        }
    }

    println!("⚙️ Configuring build target...");
    fs::create_dir_all(".cargo").ok();
    write_file(
        ".cargo/config.toml",
        r#"[target.'cfg(all(target_arch = "arm", target_os = "none"))']
runner = "probe-rs run --chip STM32F103C8"
rustflags = [
  "-C", "link-arg=-Tlink.x",
]

[build]
target = "thumbv7m-none-eabi"

[env]
DEFMT_LOG = "trace"
"#,
    );

    write_file(
        "Embed.toml",
        r#"[default.general]
chip = "STM32F103C8"

[default.reset]
halt_afterwards = false

[default.rtt]
enabled = false

[default.gdb]
enabled = false
"#,
    );

    println!("📝 Writing main.rs...");
    write_file(
        "src/main.rs",
        r#"#![no_std]
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
"#,
    );

    write_file(
        "Grimoire.toml",
        r#"version = "1"

[sigil.run]
description = "Build and flash"
language = "shell"
silent = true
run = "cargo run"

[sigil.build]
description = "Release build"
language = "shell"
silent = true
run = "cargo build --release"

[sigil.clean]
description = "Clean"
language = "shell"
silent = true
run = "cargo clean"
"#,
    );

    println!("✅ STM32 project '{}' created!", project_name);
    println!("📝 Hardware: STM32F103C8 (Blue Pill)");
    println!("🔌 Wiring: Connect PA9 (TX) to FTDI RX");
    println!("🔨 Run 'grimoire run' to flash.");
}

// ==================== RP2040-HAL ====================
fn create_rp2040_hal() {
    println!("🍓 Creating RP2040 (no-std) project...");
    let project_name = prompt_project_name();

    println!("⚙️ Checking Rust target...");
    let _ = Command::new("rustup")
        .args(["target", "add", "thumbv6m-none-eabi"])
        .status();

    println!("📦 Initializing Cargo project...");
    let status = Command::new("cargo")
        .args(["new", "--bin", &project_name])
        .status()
        .expect("Failed to run cargo new");
    if !status.success() {
        exit(1);
    }

    env::set_current_dir(&project_name).expect("Failed to cd");

    // Force edition 2024
    let cargo_toml = fs::read_to_string("Cargo.toml").expect("Failed to read Cargo.toml");
    let new_cargo = cargo_toml.replace("edition = \"2021\"", "edition = \"2024\"");
    write_file("Cargo.toml", &new_cargo);

    println!("➕ Adding dependencies...");
    let deps = [
        ("cortex-m", &[][..]),
        ("cortex-m-rt", &[][..]),
        ("embedded-hal", &[][..]),
        ("fugit", &[][..]),
        ("panic-halt", &[][..]),
        ("rp2040-boot2", &[][..]),
        ("rp2040-hal", &["--features", "critical-section-impl"][..]),
    ];

    for (crate_name, features) in deps {
        let mut cmd = Command::new("cargo");
        cmd.arg("add").arg(crate_name);
        for f in features {
            cmd.arg(f);
        }
        let _ = cmd.status();
    }

    println!("⚙️ Configuring build profiles...");
    let mut cargo_toml = fs::read_to_string("Cargo.toml").unwrap();
    cargo_toml.push_str(&format!(
        r#"
[[bin]]
name = "{}"
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
"#,
        project_name
    ));
    write_file("Cargo.toml", &cargo_toml);

    println!("⚙️ Configuring build target...");
    fs::create_dir_all(".cargo").ok();
    write_file(
        ".cargo/config.toml",
        r#"[build]
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
"#,
    );

    println!("🧠 Configuring memory map...");
    write_file(
        "memory.x",
        r#"MEMORY {
    BOOT2 : ORIGIN = 0x10000000, LENGTH = 0x100
    FLASH : ORIGIN = 0x10000100, LENGTH = 2048K - 0x100
    RAM : ORIGIN = 0x20000000, LENGTH = 256K
}
EXTERN(BOOT2_FIRMWARE)
SECTIONS {
    /* ### Boot loader */
    .boot2 ORIGIN(BOOT2) :
    {
        KEEP(*(.boot2));
    } > BOOT2
} INSERT BEFORE .text;
"#,
    );

    println!("📝 Writing main.rs...");
    write_file(
        "src/main.rs",
        r#"#![no_std]
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
"#,
    );

    println!("🧹 Downloading flash_nuke.uf2 utility...");
    let _ = Command::new("curl")
        .args([
            "-L",
            "-s",
            "-o",
            "flash_nuke.uf2",
            "https://raw.githubusercontent.com/Pwea/Flash-Nuke/main/flash_nuke.uf2",
        ])
        .status();

    println!("📊 Adding build-size.sh profiling script...");
    write_file(
        "build-size.sh",
        r#"#!/usr/bin/env zsh
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
    missing+=(" ${orange}cargo${rst} ${gray}https://rustup.rs${rst}")
fi
if ! command -v jq &>/dev/null; then
    missing+=(" ${orange}jq${rst} ${gray}install via system package manager${rst}")
fi
if ! command -v flip-link &>/dev/null; then
    missing+=(" ${orange}flip-link${rst} ${gray}cargo install flip-link${rst}")
fi
if ! command -v rust-size &>/dev/null; then
    missing+=(" ${orange}rust-size${rst} ${gray}cargo install cargo-binutils && rustup component add llvm-tools${rst}")
fi
if ! command -v bc &>/dev/null; then
    missing+=(" ${orange}bc${rst} ${gray}install via system package manager${rst}")
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
    printf " ${color}%-18s${rst} ${fg}%'10d${rst} ${gray}bytes${rst} ${dim}(%6.1f KB)${rst}\n" \
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
printf "${yellow}${bold} FLASH${rst} "
bar $flash_total $FLASH_MAX
printf " ${dim}%'d / %'d bytes${rst}\n" $flash_total $FLASH_MAX
echo ""
print_section ".text" "${sections[.text]:-0}" "$blue"
print_section ".rodata" "${sections[.rodata]:-0}" "$purple"
print_section ".vector_table" "${sections[.vector_table]:-0}" "$aqua"
print_section ".boot2" "${sections[.boot2]:-0}" "$aqua"
print_section ".data" "${sections[.data]:-0}" "$orange"
echo ""
printf "${aqua}${bold} RAM${rst} "
bar $ram_total $RAM_MAX
printf " ${dim}%'d / %'d bytes${rst}\n" $ram_total $RAM_MAX
echo ""
print_section ".bss" "${sections[.bss]:-0}" "$blue"
print_section ".data" "${sections[.data]:-0}" "$orange"
print_section ".uninit" "${sections[.uninit]:-0}" "$gray"
echo ""
"#,
    );

    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        let mut perms = fs::metadata("build-size.sh").unwrap().permissions();
        perms.set_mode(0o755);
        fs::set_permissions("build-size.sh", perms).ok();
    }

    write_file(
        "Grimoire.toml",
        r#"version = "1"

[sigil.build]
description = "Release build"
language = "shell"
silent = true
run = "cargo build --release"

[sigil.sz]
description = "Show size"
language = "shell"
silent = true
run = "./build-size.sh ."

[sigil.run]
description = "Build, convert to UF2 and flash"
language = "shell"
silent = false
run = '''
./build-size.sh .
echo "📦 Converting ELF to UF2..."
elf2uf2-rs convert target/thumbv6m-none-eabi/release/$(basename "$PWD") flash.uf2
echo "🔌 Mounting RP2040..."
sudo mount -t vfat -o sync /dev/sda1 /mnt/rp2
echo "⚡ Flashing..."
sudo cp flash.uf2 /mnt/rp2/
echo "✅ Done!"
sudo umount /mnt/rp2/ || true
'''

[sigil.nuke]
description = "Nuke flash memory"
language = "shell"
silent = false
run = '''
echo "🧹 Nuking RP2040 flash memory..."
if mountpoint -q /mnt/rp2; then
    echo "✓ Already mounted"
else
    sudo mount -t vfat -o sync /dev/sda1 /mnt/rp2
fi
sudo cp flash_nuke.uf2 /mnt/rp2/
sleep 2
sudo umount /mnt/rp2/ || true
echo "✅ Flash memory nuked!"
'''

[sigil.clean]
description = "Clean"
language = "shell"
silent = true
run = '''
cargo clean
rm -f flash.uf2
'''
"#,
    );

    println!("✅ RP2040 project '{}' created with memory profiling!", project_name);
    println!("📝 Hardware: Waveshare RP2040 Zero");
    println!("🔌 NeoPixel on GP16");
    println!("🔨 Run 'grimoire run' to flash.");
}

// ==================== nRF52-Embassy ====================
fn create_nrf52_embassy() {
    println!("📡 Creating nRF52840 Embassy (no-std) project...");
    let project_name = prompt_project_name();

    println!("⚙️ Checking Rust target...");
    let _ = Command::new("rustup")
        .args(["target", "add", "thumbv7em-none-eabi"])
        .status();

    println!("📦 Initializing Cargo project...");
    let status = Command::new("cargo")
        .args(["new", "--bin", &project_name, "--vcs", "none"])
        .status()
        .expect("Failed to run cargo new");
    if !status.success() {
        exit(1);
    }

    env::set_current_dir(&project_name).expect("Failed to cd");

    println!("➕ Adding dependencies...");
    let deps = [
        (
            "embassy-executor",
            &["--features", "platform-cortex-m,executor-thread,defmt"][..],
        ),
        (
            "embassy-time",
            &["--features", "defmt,defmt-timestamp-uptime,tick-hz-32_768"][..],
        ),
        (
            "embassy-nrf",
            &["--features", "defmt,nrf52840,time-driver-rtc1,gpiote"][..],
        ),
        ("defmt", &[][..]),
        ("defmt-rtt", &[][..]),
        ("panic-probe", &["--features", "print-defmt"][..]),
        (
            "cortex-m",
            &["--features", "inline-asm,critical-section-single-core"][..],
        ),
        ("cortex-m-rt", &[][..]),
    ];

    for (crate_name, features) in deps {
        let mut cmd = Command::new("cargo");
        cmd.arg("add").arg(crate_name);
        for f in features {
            cmd.arg(f);
        }
        let _ = cmd.status();
    }

    // Append profiles
    let mut cargo_toml = fs::read_to_string("Cargo.toml").unwrap();
    cargo_toml.push_str(&format!(
        r#"
[profile.release]
debug = 2
lto = true
opt-level = 'z' # Optimize for size

[[bin]]
name = "{}"
test = false
bench = false
doctest = false
"#,
        project_name
    ));
    write_file("Cargo.toml", &cargo_toml);

    fs::create_dir_all(".cargo").ok();
    write_file(
        ".cargo/config.toml",
        r#"[target.'cfg(all(target_arch = "arm", target_os = "none"))']
# replace nRF52840_xxAA with your chip as listed in `probe-rs chip list`
runner = "probe-rs run --chip nRF52840_xxAA"

[build]
target = "thumbv7em-none-eabi"

[env]
DEFMT_LOG = "trace"
"#,
    );

    write_file(
        "memory.x",
        r#"MEMORY
{
  /* NOTE 1 K = 1 KiBi = 1024 bytes */
  FLASH : ORIGIN = 0x00000000, LENGTH = 1024K
  RAM : ORIGIN = 0x20000000, LENGTH = 256K
  /* These values correspond to the NRF52840 with Softdevices S140 7.3.0 */
  /*
     FLASH : ORIGIN = 0x00027000, LENGTH = 868K
     RAM : ORIGIN = 0x20020000, LENGTH = 128K
  */
}
"#,
    );

    write_file(
        "build.rs",
        r#"//! This build script copies the `memory.x` file from the crate root into
//! a directory where the linker can always find it at build time.
use std::env;
use std::fs::File;
use std::io::Write;
use std::path::PathBuf;

fn main() {
    let out = &PathBuf::from(env::var_os("OUT_DIR").unwrap());
    File::create(out.join("memory.x"))
        .unwrap()
        .write_all(include_bytes!("memory.x"))
        .unwrap();
    println!("cargo:rustc-link-search={}", out.display());
    println!("cargo:rerun-if-changed=memory.x");
    println!("cargo:rustc-link-arg-bins=--nmagic");
    println!("cargo:rustc-link-arg-bins=-Tlink.x");
    println!("cargo:rustc-link-arg-bins=-Tdefmt.x");
}
"#,
    );

    write_file(
        "src/main.rs",
        r#"#![no_std]
#![no_main]

use defmt::info;
use defmt_rtt as _; // Initializes the global defmt logger
use panic_probe as _; // Catches panics and sends them through defmt

use embassy_executor::Spawner;
use embassy_nrf::gpio::{Level, Output, OutputDrive};
use embassy_time::{Duration, Timer};

#[embassy_executor::main]
async fn main(_spawner: Spawner) {
    // Initialize the HAL and grab the peripheral singleton
    let p = embassy_nrf::init(Default::default());
    loop {}
}
"#,
    );

    write_file(
        "Grimoire.toml",
        r#"version = "1"

[sigil.run]
description = "Build and flash with defmt"
language = "shell"
silent = true
run = "cargo run"

[sigil.build]
description = "Release build"
language = "shell"
silent = true
run = "cargo build --release"

[sigil.sz]
description = "Show size"
language = "shell"
silent = true
run = "./build-size.sh ."

[sigil.f]
description = "Size + Run release"
language = "shell"
silent = true
run = '''
./build-size.sh .
cargo run --release
'''

[sigil.clean]
description = "Clean"
language = "shell"
silent = true
run = "cargo clean"
"#,
    );

    println!("✅ nRF52840 Embassy project '{}' created!", project_name);
    println!("🔌 Connect your nRF52840-DK and run 'grimoire run' to compile, flash, and view defmt logs.");
}

// ==================== Zephyr ====================
// ==================== Zephyr ====================
fn create_zephyr() {
    println!("🪁 Creating Zephyr RTOS project...");
    let project_name = prompt_project_name();

    let boards = vec![
        "nucleo_l433rc_p",
        "nrf52840dk/nrf52840",
        "frdm_mcxa156",
        "frdm_mcxn236",
        "rp2040_zero",
    ];

    let board = match Select::new("Choose board:", boards)
        .with_page_size(10)
        .prompt() {
        Ok(b) => b,
        Err(_) => {
            println!("Aborted.");
            exit(0);
        }
    };

    let flash_runner = if board.contains("frdm_mcxa156") || board.contains("frdm_mcxn236") {
        "jlink"
    } else if board == "rp2040_zero" {
        "uf2"
    } else {
        "openocd"
    };

    fs::create_dir_all(format!("{}/src", project_name)).ok();

    write_file(
        &format!("{}/CMakeLists.txt", project_name),
        &format!(
            r#"cmake_minimum_required(VERSION 3.20.0)
find_package(Zephyr REQUIRED HINTS $ENV{{ZEPHYR_BASE}})
project({})
# Export compile commands for clangd / Neovim
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
target_sources(app PRIVATE src/main.c)
"#,
            project_name
        ),
    );

    write_file(
        &format!("{}/prj.conf", project_name),
        r#"# CONFIG_PRINTK=y
# CONFIG_LOG=y
# CONFIG_GPIO=y
"#,
    );

    write_file(
        &format!("{}/src/main.c", project_name),
        r#"#include <zephyr/kernel.h>
int main(void)
{
    return 0;
}
"#,
    );

    // Write Grimoire.toml
    if board == "rp2040_zero" {
        write_file(
            &format!("{}/Grimoire.toml", project_name),
            r#"version = "1"

[sigil.build]
description = "Build"
language = "shell"
silent = true
run = "west build -b rp2040_zero ."

[sigil.pristine]
description = "Pristine build"
language = "shell"
silent = true
run = "west build -p always -b rp2040_zero ."

[sigil.flash]
description = "Flash UF2"
language = "shell"
silent = false
run = '''
echo "Looking for RP2040 in bootloader mode..."
DEV=$(lsblk -o NAME,LABEL -n -l | awk '$2=="RPI-RP2" {print "/dev/"$1}')
if [ -z "$DEV" ]; then
    echo "❌ No RPI-RP2 found!"
    echo " → Hold BOOT button, plug in USB (or press RESET while holding BOOT)"
    echo " → Then run 'grimoire flash' again"
    exit 1
fi
echo "✓ Found board at $DEV"
sudo mkdir -p /mnt/rp2
if ! mountpoint -q /mnt/rp2; then
    sudo mount -t vfat -o sync,uid=$(id -u),gid=$(id -g) "$DEV" /mnt/rp2
fi
echo "⚡ Flashing..."
cp build/zephyr/zephyr.uf2 /mnt/rp2/
echo "✅ Done! Board should reboot."
sleep 1.5
sudo umount /mnt/rp2 || true
'''

[sigil.nuke]
description = "Nuke flash"
language = "shell"
silent = false
run = '''
echo "🧹 Nuking RP2040 flash memory..."
DEV=$(lsblk -o NAME,LABEL -n -l | awk '$2=="RPI-RP2" {print "/dev/"$1}')
if [ -z "$DEV" ]; then
    echo "❌ No RPI-RP2 found! Put the board into bootloader mode first."
    exit 1
fi
sudo mkdir -p /mnt/rp2
if ! mountpoint -q /mnt/rp2; then
    sudo mount -t vfat -o sync,uid=$(id -u),gid=$(id -g) "$DEV" /mnt/rp2
fi
if [ ! -f flash_nuke.uf2 ]; then
    echo "⬇️ Downloading flash_nuke.uf2..."
    curl -L -s -o flash_nuke.uf2 https://raw.githubusercontent.com/Pwea/Flash-Nuke/main/flash_nuke.uf2
fi
echo "💣 Copying flash_nuke.uf2..."
cp flash_nuke.uf2 /mnt/rp2/
echo "⏳ Waiting for flash erase..."
sleep 2
sudo umount /mnt/rp2 || true
echo "✅ Flash memory nuked! Board will reboot."
'''

[sigil.clean]
description = "Clean"
language = "shell"
silent = true
run = "rm -rf build compile_commands.json"
"#,
        );
    } else {
        let mut grimoire = format!(
            r#"version = "1"

[sigil.build]
description = "Build"
language = "shell"
silent = true
run = "west build -b {} ."

[sigil.pristine]
description = "Pristine build"
language = "shell"
silent = true
run = "west build -p always -b {} ."

[sigil.flash]
description = "Flash"
language = "shell"
silent = true
run = "west flash --runner {}"

[sigil.clean]
description = "Clean"
language = "shell"
silent = true
run = "rm -rf build compile_commands.json"
"#,
            board, board, flash_runner
        );

        // Add recover target only for nRF52840-DK
        if board.contains("nrf52840dk") {
            grimoire.push_str(
                r#"
[sigil.recover]
description = "Mass erase Nordic chip (bypass APPROTECT)"
language = "shell"
silent = false
run = '''
/home/vaishnav/zephyr-sdk-1.0.1/hosttools/sysroots/x86_64-pokysdk-linux/usr/bin/openocd \
    -s /home/vaishnav/zephyr-sdk-1.0.1/hosttools/sysroots/x86_64-pokysdk-linux/usr/share/openocd/scripts \
    -c 'source [find interface/jlink.cfg]' \
    -c 'transport select swd' \
    -c 'source [find target/nrf52.cfg]' \
    -c 'init' -c 'nrf52_recover' -c 'exit'
'''
"#,
            );
        }

        write_file(&format!("{}/Grimoire.toml", project_name), &grimoire);
    }

    // -------------------------------------------------
    // Extra steps from the original bash version
    // -------------------------------------------------
    println!("🔨 Running initial pristine build to generate Devicetree headers...");

    if Command::new("west").arg("--version").output().is_err() {
        println!("⚠️  'west' command not found! Make sure your Zephyr Python venv is active.");
        println!("Project files created, but skipping automatic build and symlinking.");
    } else {
        let status = Command::new("west")
            .args([
                "build",
                "-p",
                "always",
                "-b",
                &board,
                "-d",
                &format!("{}/build", project_name),
                &project_name,
            ])
            .status()
            .expect("Failed to run west build");

        if status.success() {
            println!("🔗 Symlinking compile_commands.json for Neovim/clangd...");
            let compile_commands = format!("{}/build/compile_commands.json", project_name);
            if Path::new(&compile_commands).exists() {
                let _ = std::os::unix::fs::symlink(
                    "build/compile_commands.json",
                    format!("{}/compile_commands.json", project_name),
                );

                // Create .gitignore
                write_file(
                    &format!("{}/.gitignore", project_name),
                    "build/\ncompile_commands.json\n",
                );
            } else {
                println!("⚠️  compile_commands.json not found in build directory.");
            }
        } else {
            println!("⚠️  Initial west build failed. You may need to run it manually.");
        }
    }

    println!("✅ Zephyr project '{}' created for '{}'!", project_name, board);
}

// ==================== Arduino ====================
fn create_arduino() {
    println!("♾️ Creating Arduino project...");

    if Command::new("arduino-cli").arg("version").output().is_err() {
        eprintln!("Error: arduino-cli not found. Please install it first.");
        exit(1);
    }

    let project_name = prompt_project_name();

    let fqbn = Text::new("Enter board FQBN (e.g. arduino:avr:uno):")
        .prompt()
        .unwrap_or_else(|_| {
            println!("Aborted.");
            exit(0);
        });

    let status = Command::new("arduino-cli")
        .args(["sketch", "new", &project_name])
        .status()
        .expect("Failed to create sketch");
    if !status.success() {
        exit(1);
    }

    env::set_current_dir(&project_name).ok();

    println!("📎 Attaching board {} to generate sketch.yaml...", fqbn);
    let _ = Command::new("arduino-cli")
        .args(["board", "attach", "-b", &fqbn])
        .status();

    write_file(
        "Grimoire.toml",
        r#"version = "1"

[sigil.build]
description = "Compile the sketch"
language = "shell"
silent = true
run = "arduino-cli compile"

[sigil.upload]
description = "Upload (pass port as argument)"
language = "shell"
silent = true
run = "arduino-cli upload -p {{port}}"

[sigil.upload.args.port]
type = "text"
default = "/dev/ttyUSB0"

[sigil.monitor]
description = "Serial monitor"
language = "shell"
silent = false
run = "arduino-cli monitor -p {{port}}"

[sigil.monitor.args.port]
type = "text"
default = "/dev/ttyUSB0"

[sigil.clean]
description = "Clean"
language = "shell"
silent = true
run = "rm -rf build"
"#,
    );

    println!("✅ Arduino project '{}' created for '{}'!", project_name, fqbn);
}

// ==================== Ada ====================
fn create_ada() {
    println!("⚙️ Creating Ada SPARK project...");

    if Command::new("alr").arg("--version").output().is_err() {
        eprintln!("Error: Alire (alr) not found. Please ensure it is in your PATH.");
        exit(1);
    }

    let project_name = prompt_project_name();

    println!("📦 Initializing Alire project...");
    let status = Command::new("alr")
        .args(["init", "--bin", &project_name])
        .status()
        .expect("Failed to run alr init");
    if !status.success() {
        exit(1);
    }

    env::set_current_dir(&project_name).ok();

    println!("➕ Adding gnatprove dependency...");
    let _ = Command::new("alr").args(["with", "gnatprove"]).status();

    let adb_file = format!("src/{}.adb", project_name.to_lowercase());
    write_file(
        &adb_file,
        &format!(
            r#"with Ada.Text_IO; use Ada.Text_IO;
procedure {} is
begin
end {};
"#,
            project_name, project_name
        ),
    );

    write_file(
        ".gitignore",
        r#"# Compiled Objects and Executables
/obj/
/bin/
# Alire-specific configuration and cache
/alire/
/config/
alire.toml.prev
alire.lock.prev
# SPARK Verification Artifacts
gnatprove/
*.log
*.spark
"#,
    );

    write_file(
        "Grimoire.toml",
        r#"version = "1"

[sigil.build]
description = "Build with Alire"
language = "shell"
silent = true
run = "alr build"

[sigil.run]
description = "Run"
language = "shell"
silent = true
run = "alr run"

[sigil.prove]
description = "Run gnatprove"
language = "shell"
silent = false
run = "alr gnatprove"

[sigil.clean]
description = "Clean"
language = "shell"
silent = true
run = '''
alr clean
rm -rf obj/ bin/
'''
"#,
    );

    println!("✅ Ada SPARK project '{}' created!", project_name);
}

// ==================== D-simple ====================
fn create_d_simple() {
    println!("🇩 Creating D (simple) project...");
    let project_name = prompt_project_name();
    let description = Text::new("Enter project description:")
        .prompt()
        .unwrap_or_else(|_| "A D project".to_string());

    create_dir_and_cd(&project_name);

    let content = format!(
        r#"#!/usr/bin/env dub
/+ dub.sdl:
      name "{}"
      description "{}"
 +/
import std.stdio : writeln;
void main() {{
    writeln("Hello from D!");
}}
"#,
        project_name, description
    );

    write_file(&format!("{}.d", project_name), &content);

    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        let mut perms = fs::metadata(format!("{}.d", project_name))
            .unwrap()
            .permissions();
        perms.set_mode(0o755);
        fs::set_permissions(format!("{}.d", project_name), perms).ok();
    }

    println!("✅ D-simple project '{}' created!", project_name);
    println!("🚀 You can run it directly using: ./{}.d", project_name);
}
