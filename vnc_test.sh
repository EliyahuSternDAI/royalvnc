#!/bin/bash

# --- Configuration ---
GRPC_SERVER="localhost:5959"
PROTO_PATH="Sources/RoyalVNCTool/Protos/vnc.proto"
IMPORT_PATH="Sources/RoyalVNCTool/Protos"

# --- Subcommand Functions ---

usage() {
    echo "Usage: $0 <subcommand> [options]"
    echo ""
    echo "Subcommands:"
    echo "  mouse-wheel      Connect/reuse a session and send mouse wheel events."
    echo "  list-sessions    List all active VNC sessions."
    echo "  start-session    Start a new VNC session."
    echo "  stop-session     Stop a specific VNC session."
    echo "  stop-all-sessions Stop all active VNC sessions."
    echo "  move-and-click   Move the mouse to a location and click."
    echo "  send-string      Send a string of text as key events."
    echo "  send-key         Send a special key by name (e.g., 'enter', 'tab')."
    echo "  --key-action <action>  The key action: 'down', 'up', or 'press-release' (default: press-release)."
    exit 1
}

do_list_sessions() {
    echo "Listing active sessions from $GRPC_SERVER..."
    grpcurl -plaintext -import-path "$IMPORT_PATH" -proto "$PROTO_PATH" \
      -d "{}" \
      "$GRPC_SERVER" vnc.VNCService/ListSessions
}

do_start_session() {
    local VNC_HOST=""
    local VNC_PORT=5900
    local VNC_USER=""
    local VNC_PASS=""

    while [[ "$#" -gt 0 ]]; do
        case $1 in
            --vnc-host) VNC_HOST="$2"; shift ;;
            --vnc-port) VNC_PORT="$2"; shift ;;
            --vnc-user) VNC_USER="$2"; shift ;;
            --vnc-pass) VNC_PASS="$2"; shift ;;
            *) echo "Unknown parameter for start-session: $1"; usage ;;
        esac
        shift
    done

    if [[ -z "$VNC_HOST" ]]; then
        echo "Error: --vnc-host is a required parameter for the start-session command."
        exit 1
    fi
    echo "Attempting to start a new session for $VNC_USER@$VNC_HOST:$VNC_PORT..."
    grpcurl -plaintext -import-path "$IMPORT_PATH" -proto "$PROTO_PATH" \
      -d "{\"hostname\": \"$VNC_HOST\", \"port\": $VNC_PORT, \"username\": \"$VNC_USER\", \"password\": \"$VNC_PASS\"}" \
      "$GRPC_SERVER" vnc.VNCService/StartSession
}

do_stop_session() {
    local SESSION_ID=""
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            --session-id) SESSION_ID="$2"; shift ;;
            *) echo "Unknown parameter for stop-session: $1"; usage ;;
        esac
        shift
    done

    if [[ -z "$SESSION_ID" ]]; then
        echo "Error: --session-id is a required parameter for the stop-session command."
        exit 1
    fi
    echo "Stopping session with ID: $SESSION_ID..."
    grpcurl -plaintext -import-path "$IMPORT_PATH" -proto "$PROTO_PATH" \
      -d "{\"sessionID\": \"$SESSION_ID\"}" \
      "$GRPC_SERVER" vnc.VNCService/StopSession
}

do_stop_all_sessions() {
    echo "Stopping all active sessions..."
    list_response=$(grpcurl -plaintext -import-path "$IMPORT_PATH" -proto "$PROTO_PATH" \
      -d "{}" \
      "$GRPC_SERVER" vnc.VNCService/ListSessions)

    session_ids=$(echo "$list_response" | jq -r '.sessions[].sessionID')

    if [ -z "$session_ids" ]; then
        echo "No active sessions found to stop."
        exit 0
    fi

    for id in $session_ids; do
        echo "Stopping session: $id"
        grpcurl -plaintext -import-path "$IMPORT_PATH" -proto "$PROTO_PATH" \
          -d "{\"sessionID\": \"$id\"}" \
          "$GRPC_SERVER" vnc.VNCService/StopSession
    done
    echo "All active sessions have been stopped."
}

do_send_key() {
    local VNC_HOST=""
    local VNC_PORT=5900
    local VNC_USER=""
    local VNC_PASS=""
    local KEY_NAME=""
    local KEY_ACTION="press-release"

    while [[ "$#" -gt 0 ]]; do
        case $1 in
            --vnc-host) VNC_HOST="$2"; shift ;;
            --vnc-port) VNC_PORT="$2"; shift ;;
            --vnc-user) VNC_USER="$2"; shift ;;
            --vnc-pass) VNC_PASS="$2"; shift ;;
            --key) KEY_NAME="$2"; shift ;;
            --key-action) KEY_ACTION="$2"; shift ;;
            *) echo "Unknown parameter for send-key: $1"; usage ;;
        esac
        shift
    done

    if [[ -z "$VNC_HOST" ]]; then
        echo "Error: --vnc-host is a required parameter for the send-key command."
        exit 1
    fi
    if [[ -z "$KEY_NAME" ]]; then
        echo "Error: --key is a required parameter for the send-key command."
        exit 1
    fi

    # --- Map key names to keysyms ---
    local keysym=""
    case "$KEY_NAME" in
        "enter")      keysym="0xff0d" ;;
        "backspace")  keysym="0xff08" ;;
        "tab")        keysym="0xff09" ;;
        "escape")     keysym="0xff1b" ;;
        "up")         keysym="0xff52" ;;
        "down")       keysym="0xff54" ;;
        "left")       keysym="0xff51" ;;
        "right")      keysym="0xff53" ;;
        "f1")         keysym="0xffbe" ;;
        "f2")         keysym="0xffbf" ;;
        "f3")         keysym="0xffc0" ;;
        "f4")         keysym="0xffc1" ;;
        "f5")         keysym="0xffc2" ;;
        "f6")         keysym="0xffc3" ;;
        "f7")         keysym="0xffc4" ;;
        "f8")         keysym="0xffc5" ;;
        "f9")         keysym="0xffc6" ;;
        "f10")        keysym="0xffc7" ;;
        "f11")        keysym="0xffc8" ;;
        "f12")        keysym="0xffc9" ;;
        *)
            # Allow passing raw hex values
            if [[ "$KEY_NAME" =~ ^0x[0-9a-fA-F]+$ ]]; then
                keysym=$KEY_NAME
            elif [[ ${#KEY_NAME} -eq 1 ]]; then
                keysym=$(printf "0x%x" "'$KEY_NAME")
            else
                echo "Error: Unknown key name '$KEY_NAME'."
                exit 1
            fi
            ;;
    esac

    # --- Get Session ID (reuse or create) ---
    echo "Checking for existing session for $VNC_USER@$VNC_HOST:$VNC_PORT..."
    list_response=$(grpcurl -plaintext -import-path "$IMPORT_PATH" -proto "$PROTO_PATH" -d "{}" "$GRPC_SERVER" vnc.VNCService/ListSessions)
    session_id=$(echo "$list_response" | jq -r --arg host "$VNC_HOST" --arg port "$VNC_PORT" --arg user "$VNC_USER" '.sessions[] | select(.hostname == $host and .port == ($port|tonumber) and .username == "" or .username == $user) | .sessionID' | head -n 1)

    if [ -z "$session_id" ]; then
        echo "No existing session found. Starting a new one..."
        start_response=$(grpcurl -plaintext -import-path "$IMPORT_PATH" -proto "$PROTO_PATH" -d "{\"hostname\": \"$VNC_HOST\", \"port\": $VNC_PORT, \"username\": \"$VNC_USER\", \"password\": \"$VNC_PASS\"}" "$GRPC_SERVER" vnc.VNCService/StartSession)
        session_id=$(echo "$start_response" | jq -r .sessionID)
        echo "New session started with ID: $session_id"
    else
        echo "Found existing session. Reusing session ID: $session_id"
    fi

    if [ -z "$session_id" ] || [ "$session_id" == "null" ]; then
      echo "Error: Could not obtain a sessionID."
      exit 1
    fi
    echo "----------------------------------------"

    # --- Send Key ---
    echo "Sending key '$KEY_NAME' (keysym: $keysym, action: $KEY_ACTION)..."
    
    # Convert hex to decimal for the JSON payload
    local keysym_dec=$(printf "%d" "$keysym")

    if [ "$KEY_ACTION" == "down" ] || [ "$KEY_ACTION" == "press-release" ]; then
        # Press
        grpcurl -plaintext -import-path "$IMPORT_PATH" -proto "$PROTO_PATH" \
          -d "{\"sessionID\": \"$session_id\", \"keysym\": $keysym_dec, \"isPressed\": true}" \
          "$GRPC_SERVER" vnc.VNCService/SendKeyEvent
    fi
    
    if [ "$KEY_ACTION" == "press-release" ]; then
        sleep 0.05 # Small delay between press and release
    fi

    if [ "$KEY_ACTION" == "up" ] || [ "$KEY_ACTION" == "press-release" ]; then
        # Release
        grpcurl -plaintext -import-path "$IMPORT_PATH" -proto "$PROTO_PATH" \
          -d "{\"sessionID\": \"$session_id\", \"keysym\": $keysym_dec, \"isPressed\": false}" \
          "$GRPC_SERVER" vnc.VNCService/SendKeyEvent
    fi

    echo "Key action '$KEY_ACTION' for '$KEY_NAME' sent."
    echo "----------------------------------------"
    echo "Script finished. Session with ID $session_id is still active."
}

do_send_string() {
    local VNC_HOST=""
    local VNC_PORT=5900
    local VNC_USER=""
    local VNC_PASS=""
    local STRING=""

    while [[ "$#" -gt 0 ]]; do
        case $1 in
            --vnc-host) VNC_HOST="$2"; shift ;;
            --vnc-port) VNC_PORT="$2"; shift ;;
            --vnc-user) VNC_USER="$2"; shift ;;
            --vnc-pass) VNC_PASS="$2"; shift ;;
            --string) STRING="$2"; shift ;;
            *) echo "Unknown parameter for send-string: $1"; usage ;;
        esac
        shift
    done

    if [[ -z "$VNC_HOST" ]]; then
        echo "Error: --vnc-host is a required parameter for the send-string command."
        exit 1
    fi
    if [[ -z "$STRING" ]]; then
        echo "Error: --string is a required parameter for the send-string command."
        exit 1
    fi

    # --- Get Session ID (reuse or create) ---
    echo "Checking for existing session for $VNC_USER@$VNC_HOST:$VNC_PORT..."
    list_response=$(grpcurl -plaintext -import-path "$IMPORT_PATH" -proto "$PROTO_PATH" -d "{}" "$GRPC_SERVER" vnc.VNCService/ListSessions)
    session_id=$(echo "$list_response" | jq -r --arg host "$VNC_HOST" --arg port "$VNC_PORT" --arg user "$VNC_USER" '.sessions[] | select(.hostname == $host and .port == ($port|tonumber) and .username == "" or .username == $user) | .sessionID' | head -n 1)

    if [ -z "$session_id" ]; then
        echo "No existing session found. Starting a new one..."
        start_response=$(grpcurl -plaintext -import-path "$IMPORT_PATH" -proto "$PROTO_PATH" -d "{\"hostname\": \"$VNC_HOST\", \"port\": $VNC_PORT, \"username\": \"$VNC_USER\", \"password\": \"$VNC_PASS\"}" "$GRPC_SERVER" vnc.VNCService/StartSession)
        session_id=$(echo "$start_response" | jq -r .sessionID)
        echo "New session started with ID: $session_id"
    else
        echo "Found existing session. Reusing session ID: $session_id"
    fi

    if [ -z "$session_id" ] || [ "$session_id" == "null" ]; then
      echo "Error: Could not obtain a sessionID."
      exit 1
    fi
    echo "----------------------------------------"

    # --- Send String ---
    echo "Sending string: '$STRING'..."
    for (( i=0; i<${#STRING}; i++ )); do
      char="${STRING:i:1}"

      # Convert character to hex
      hex=$(printf "%x" "'$char")

      # Send key event for the character
      grpcurl -plaintext -import-path "$IMPORT_PATH" -proto "$PROTO_PATH" \
        -d "{\"sessionID\": \"$session_id\", \"keysym\": $((0x$hex)), \"isPressed\": true}" \
        "$GRPC_SERVER" vnc.VNCService/SendKeyEvent
      sleep 0.05

      # Release key event
      grpcurl -plaintext -import-path "$IMPORT_PATH" -proto "$PROTO_PATH" \
        -d "{\"sessionID\": \"$session_id\", \"keysym\": $((0x$hex)), \"isPressed\": false}" \
        "$GRPC_SERVER" vnc.VNCService/SendKeyEvent
    done
    echo "String sent."
    echo "----------------------------------------"
    echo "Script finished. Session with ID $session_id is still active."
}


# --- Main Script Logic ---

if [ "$#" -eq 0 ]; then
    usage
fi

# Handle global options
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --grpc-server)
            GRPC_SERVER="$2"
            shift 2
            ;;
        *)
            break
            ;;
    esac
done

SUBCOMMAND=$1
shift # Consume the subcommand

case $SUBCOMMAND in
    mouse-wheel)
        do_mouse_wheel "$@"
        ;;
    list-sessions)
        do_list_sessions "$@"
        ;;
    start-session)
        do_start_session "$@"
        ;;
    stop-session)
        do_stop_session "$@"
        ;;
    stop-all-sessions)
        do_stop_all_sessions "$@"
        ;;
    move-and-click)
        do_move_and_click "$@"
        ;;
    send-string)
        do_send_string "$@"
        ;;
    send-key)
        do_send_key "$@"
        ;;
    *)
        echo "Error: Unknown subcommand '$SUBCOMMAND'"
        usage
        ;;
esac
