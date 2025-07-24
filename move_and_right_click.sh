#!/bin/bash

# Configurable settings
PROTO_PATH="Sources/RoyalVNCTool/Protos/vnc.proto"
SERVICE_MOVE="vnc.VNCService/SendPointerEvent"
SERVICE_CLICK="vnc.VNCService/SendMouseButtonEvent"
HOST="localhost:1234"
Y=500              # Fixed vertical position
X_START=300        # Starting horizontal position
X_END=800          # Ending horizontal position
STEP=50            # How many pixels to move each step
DELAY=0.05         # Delay between moves

# Move mouse to a position
move_mouse() {
  local x=$1
  local y=$2
  grpcurl -plaintext -proto "$PROTO_PATH" -d "{\"x\": $x, \"y\": $y}" "$HOST" "$SERVICE_MOVE"
}

# Perform mouse button event
mouse_click() {
  local button=$1  # 2 for right click
  local x=$2
  local y=$3
  grpcurl -plaintext -proto "$PROTO_PATH" -d "{\"button\": $button, \"x\": $x, \"y\": $y, \"pressed\": true}" "$HOST" "$SERVICE_CLICK"
  sleep 0.1
  grpcurl -plaintext -proto "$PROTO_PATH" -d "{\"button\": $button, \"x\": $x, \"y\": $y, \"pressed\": false}" "$HOST" "$SERVICE_CLICK"
}

# Move mouse from left to right
for ((x=$X_START; x<=$X_END; x+=$STEP)); do
  move_mouse $x $Y
  sleep $DELAY
done

# Move mouse from right to left
for ((x=$X_END; x>=$X_START; x-=$STEP)); do
  move_mouse $x $Y
  sleep $DELAY
done

# Right click at the last position
mouse_click 2 $X_START $Y

