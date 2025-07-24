#!/bin/bash

# Configurable parameters
PROTO_PATH="Sources/RoyalVNCTool/Protos/vnc.proto"
SERVICE="vnc.VNCService/SendKeyEvent"
HOST="localhost:1234"
DELAY=0.01  # Default delay between keypress and keyrelease

# Mapping special keys
declare -A CONTROL_KEYS=(
  ["ENTER"]=13
  ["TAB"]=9
  ["BACKSPACE"]=8
  ["LEFT"]=37
  ["UP"]=38
  ["RIGHT"]=39
  ["DOWN"]=40
)

send_key_event() {
  local keycode=$1
  local pressed=$2
  grpcurl -plaintext -proto "$PROTO_PATH" -d "{\"keycode\":$keycode,\"pressed\":$pressed}" "$HOST" "$SERVICE"
}

send_char() {
  local char=$1
  local ascii_code
  ascii_code=$(printf "%d" "'$char")
  send_key_event "$ascii_code" true
  sleep "$DELAY"
  send_key_event "$ascii_code" false
  sleep "$DELAY"
}

send_control_key() {
  local name=$1
  local code=${CONTROL_KEYS[$name]}
  if [[ -z "$code" ]]; then
    echo "Unknown control key: $name" >&2
    return
  fi
  send_key_event "$code" true
  sleep "$DELAY"
  send_key_event "$code" false
  sleep "$DELAY"
}

# Parse string with support for {ENTER}, {TAB}, etc.
send_string() {
  local input=$1
  while [[ -n "$input" ]]; do
    if [[ "$input" =~ ^\{([A-Z]+)\}(.*) ]]; then
      send_control_key "${BASH_REMATCH[1]}"
      input="${BASH_REMATCH[2]}"
    else
      char="${input:0:1}"
      send_char "$char"
      input="${input:1}"
    fi
  done
}

# Entry point
if [[ $# -eq 0 ]]; then
  echo "Usage: $0 'text to send {ENTER}{LEFT}'"
  exit 1
fi

send_string "$1"

