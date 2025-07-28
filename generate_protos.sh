#!/bin/bash

# This script generates Swift files from .proto definitions.

set -e

# --- Configuration ---
PROTO_SOURCE_DIR="Sources/RoyalVNCTool/Protos"
GENERATED_OUTPUT_DIR="Sources/RoyalVNCTool"

# --- Helper Functions ---
find_tool() {
    local tool_name=$1
    
    # 1. Check local project tools directory first
    local local_tool_path="./.tools/protoc/bin/$tool_name"
    if [ -f "$local_tool_path" ]; then
        echo "$local_tool_path"
        return
    fi

    # 2. Check standard Homebrew paths
    if [ -f "/opt/homebrew/bin/$tool_name" ]; then
        echo "/opt/homebrew/bin/$tool_name"
        return
    fi
    
    if [ -f "/usr/local/bin/$tool_name" ]; then
        echo "/usr/local/bin/$tool_name"
        return
    fi

    # 3. Check PATH as a last resort
    if command -v "$tool_name" &> /dev/null; then
        command -v "$tool_name"
        return
    fi
    
    echo "Error: Could not find required tool '$tool_name'." >&2
    echo "Please run the ./setup_environment.sh script or install it manually." >&2
    exit 1
}

find_grpc_plugin() {
    local plugin_name="protoc-gen-grpc-swift"
    
    # 1. Check the submodule build directory for an executable file.
    local submodule_build_path="./Dependencies/grpc-swift/.build"
    if [ -d "$submodule_build_path" ]; then
        # Find an executable file with the correct name, excluding .dSYM paths.
        # Use -perm +111 for macOS compatibility instead of -executable.
        local found_path=$(find "$submodule_build_path" -name "$plugin_name" -type f -perm +111 -not -path "*.dSYM*" | head -n 1)
        if [ -n "$found_path" ]; then
            echo "$found_path"
            return
        fi
    fi

    # 2. Fallback to standard tool search
    find_tool "$plugin_name"
}


# --- Main Script ---
echo "Searching for required tools..."
PROTOC_PATH=$(find_tool "protoc")
PROTOC_GEN_SWIFT_PATH=$(find_tool "protoc-gen-swift")
PROTOC_GEN_GRPC_SWIFT_PATH=$(find_grpc_plugin)

echo "  protoc: $PROTOC_PATH"
echo "  protoc-gen-swift: $PROTOC_GEN_SWIFT_PATH"
echo "  protoc-gen-grpc-swift: $PROTOC_GEN_GRPC_SWIFT_PATH"
echo ""

if [ ! -d "$PROTO_SOURCE_DIR" ]; then
    echo "Error: Proto source directory not found at '$PROTO_SOURCE_DIR'"
    exit 1
fi

# Find all .proto files
proto_files=$(find "$PROTO_SOURCE_DIR" -name "*.proto")

if [ -z "$proto_files" ]; then
    echo "No .proto files found in '$PROTO_SOURCE_DIR'. Nothing to do."
    exit 0
fi

echo "Found .proto files:"
echo "$proto_files"
echo ""

echo "Cleaning up old generated files in '$GENERATED_OUTPUT_DIR'..."
find "$GENERATED_OUTPUT_DIR" -name "vnc.pb.swift" -delete
find "$GENERATED_OUTPUT_DIR" -name "vnc.grpc.swift" -delete
echo "Cleanup complete."
echo ""

# Ensure the output directory exists
mkdir -p "$GENERATED_OUTPUT_DIR"

echo "Generating Swift files..."
for proto_file in $proto_files; do
    echo "  Processing $proto_file..."
    "$PROTOC_PATH" \
        --plugin=protoc-gen-swift="$PROTOC_GEN_SWIFT_PATH" \
        --plugin=protoc-gen-grpc-swift="$PROTOC_GEN_GRPC_SWIFT_PATH" \
        --swift_out="$GENERATED_OUTPUT_DIR" \
        --grpc-swift_out="$GENERATED_OUTPUT_DIR" \
        -I "$PROTO_SOURCE_DIR" \
        "$proto_file"
done

echo ""
echo "Code generation complete."
echo "Generated files are located in: $GENERATED_OUTPUT_DIR"
