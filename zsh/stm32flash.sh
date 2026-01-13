#!/usr/bin/env bash

# 1. Check if a filename was provided
if [ -z "$1" ]; then
    echo "❌ Error: Missing file argument."
    echo "Usage: $(basename "$0") your_program.elf"
    exit 1
fi

# 2. Check if the file actually exists
if [ ! -f "$1" ]; then
    echo "❌ Error: File '$1' not found!"
    exit 1
fi

# --- CONFIGURATION ---
PROG="/opt/stm32cubeprog/bin/STM32_Programmer_CLI"
flags=(-c port=SWD freq=480 mode=HotPlug)

echo "=========================================="
echo "⚙️  STEP 1: Disabling Write Protection..."
echo "=========================================="

# We execute the unprotect command FIRST.
# If this fails, we exit immediately because we can't erase a locked chip.
if ! "$PROG" "${flags[@]}" -ob WRP0=1 WRP1=1 WRP2=1 WRP3=1 WRP4=1 WRP5=1 WRP6=1 WRP7=1 WRP8=1 WRP9=1 WRP10=1 WRP11=1 WRP12=1 WRP13=1 WRP14=1 WRP15=1 WRP16=1 WRP17=1 WRP18=1 WRP19=1 WRP20=1 WRP21=1 WRP22=1 WRP23=1 WRP24=1 WRP25=1 WRP26=1 WRP27=1 WRP28=1 WRP29=1 WRP30=1 WRP31=1; then
    echo "❌ Step 1 Failed. Could not unprotect the chip. Aborting."
    exit 1
fi

echo "=========================================="
echo "🧹 STEP 2: Mass Erasing Flash..."
echo "=========================================="

if ! "$PROG" "${flags[@]}" -e all; then
    echo "❌ Step 2 Failed. Erase could not complete. Aborting."
    exit 1
fi

echo "=========================================="
echo "⚡ STEP 3: Flashing '$1'..."
echo "=========================================="

if "$PROG" "${flags[@]}" -w "$1" -v; then
    echo "✅ SUCCESS: Device flashed and verified!"
else
    echo "❌ Flashing Failed."
    exit 1
fi
