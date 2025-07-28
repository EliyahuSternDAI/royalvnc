#!/bin/bash

# This script demonstrates a sequence of key events to type "Hello world"
# with a capital H by holding and releasing the Shift key.

# --- Configuration ---
VNC_TARGET_HOST="192.168.64.11"
VNC_TARGET_USER="experiuser1"
LEFT_SHIFT_KEYSYM="0xffe1"

# --- Helper to check for vnc_test.sh ---
if [ ! -x "./vnc_test.sh" ]; then
    echo "Error: vnc_test.sh not found or not executable." >&2
    echo "Please ensure you are in the correct directory and have run 'chmod +x vnc_test.sh'." >&2
    exit 1
fi

# --- Keystroke Sequence ---

echo "Starting keystroke sequence for '$VNC_TARGET_USER@$VNC_TARGET_HOST'..."
echo "----------------------------------------"

# 1. Hold down the Left Shift key
echo "Holding down Left Shift..."
./vnc_test.sh send-key --vnc-host "$VNC_TARGET_HOST" --vnc-user "$VNC_TARGET_USER" --key "$LEFT_SHIFT_KEYSYM" --key-action down && \
sleep 0.2

# 2. Send the "h" character (will be uppercase because Shift is held down)
echo "Sending 'h'..."
./vnc_test.sh send-key --vnc-host "$VNC_TARGET_HOST" --vnc-user "$VNC_TARGET_USER" --key "0x68" --key-action down && \
sleep 0.2
./vnc_test.sh send-key --vnc-host "$VNC_TARGET_HOST" --vnc-user "$VNC_TARGET_USER" --key "0x68" --key-action up && \
sleep 0.2

# 3. Release the Left Shift key
echo "Releasing Left Shift..."
./vnc_test.sh send-key --vnc-host "$VNC_TARGET_HOST" --vnc-user "$VNC_TARGET_USER" --key "$LEFT_SHIFT_KEYSYM" --key-action up && \

# 4. Send the rest of the string
echo "Sending 'ello world'..."
./vnc_test.sh send-string --vnc-host "$VNC_TARGET_HOST" --vnc-user "$VNC_TARGET_USER" --string "ello world" && \

# 5. Send the Enter key
echo "Sending Enter..."
./vnc_test.sh send-key --vnc-host "$VNC_TARGET_HOST" --vnc-user "$VNC_TARGET_USER" --key enter

echo "----------------------------------------"
echo "Keystroke sequence complete."
