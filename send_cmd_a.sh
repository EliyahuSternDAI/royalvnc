#!/bin/bash

# This script sends a Command-A keystroke combination to a VNC server.

# --- Configuration ---
VNC_TARGET_HOST="192.168.64.11"
VNC_TARGET_USER="experiuser1"
LEFT_CMD_KEYSYM="0xffe7" # Left Command/Super key

# --- Helper to check for vnc_test.sh ---
if [ ! -x "./vnc_test.sh" ]; then
    echo "Error: vnc_test.sh not found or not executable." >&2
    echo "Please ensure you are in the correct directory and have run 'chmod +x vnc_test.sh'." >&2
    exit 1
fi

# --- Keystroke Sequence ---

echo "Starting keystroke sequence for '$VNC_TARGET_USER@$VNC_TARGET_HOST'..."
echo "----------------------------------------"

# 1. Hold down the Left Command key
echo "Holding down Left Command..."
./vnc_test.sh send-key --vnc-host "$VNC_TARGET_HOST" --vnc-user "$VNC_TARGET_USER" --key "$LEFT_CMD_KEYSYM" --key-action down && \
sleep 0.1

# 2. Send the "a" character
echo "Sending 'a'..."
./vnc_test.sh send-key --vnc-host "$VNC_TARGET_HOST" --vnc-user "$VNC_TARGET_USER" --key "a" --key-action press-release && \
sleep 0.1

# 3. Release the Left Command key
echo "Releasing Left Command..."
./vnc_test.sh send-key --vnc-host "$VNC_TARGET_HOST" --vnc-user "$VNC_TARGET_USER" --key "$LEFT_CMD_KEYSYM" --key-action up

echo "----------------------------------------"
echo "Keystroke sequence complete."
