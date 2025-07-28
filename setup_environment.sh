#!/usr/bin/env bash

# This script sets up the necessary development environment for building the project.
# It ensures Homebrew is installed and then uses it to install required tools.

set -e

# --- Initialize Git Submodules ---
echo "Initializing and updating Git submodules..."
git submodule update --init --recursive

# --- Check for Homebrew ---
echo ""
echo "Checking for Homebrew..."
if ! command -v brew &> /dev/null; then
    echo "Error: Homebrew is not installed." >&2
    echo "Homebrew is required to install the necessary dependencies." >&2
    echo "Please install it by running the following command in your terminal:" >&2
    echo >&2
    echo '  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"' >&2
    echo >&2
    exit 1
fi
echo "Homebrew is installed."

# --- Install protobuf (for protoc) ---
echo ""
echo "Checking for protobuf (which provides protoc)..."
if brew list protobuf &>/dev/null; then
    echo "protobuf is already installed via Homebrew."
else
    echo "Attempting to install protobuf via Homebrew..."
    if brew install protobuf; then
        echo "protobuf installed successfully."
    else
        echo "Error: Failed to install protobuf via Homebrew. Please check your Homebrew setup." >&2
        exit 1
    fi
fi

# --- Install grpcurl ---
echo ""
echo "Checking for grpcurl..."
if brew list grpcurl &>/dev/null; then
    echo "grpcurl is already installed via Homebrew."
else
    echo "Attempting to install grpcurl via Homebrew..."
    if brew install grpcurl; then
        echo "grpcurl installed successfully."
    else
        echo "Error: Failed to install grpcurl via Homebrew. Please check your Homebrew setup." >&2
        exit 1
    fi
fi

# --- Build grpc-swift code generator ---
echo ""
echo "Building protoc-gen-grpc-swift from submodule..."
if [ -d "Dependencies/grpc-swift" ]; then
    (
        cd Dependencies/grpc-swift
        swift build -c release --product protoc-gen-grpc-swift
    )

    BIN_PATH=$(cd Dependencies/grpc-swift && swift build -c release --show-bin-path)
    PLUGIN_EXEC="${BIN_PATH}/protoc-gen-grpc-swift"

    if [ -f "$PLUGIN_EXEC" ]; then
        echo "Ensuring protoc-gen-grpc-swift is executable..."
        chmod +x "$PLUGIN_EXEC"
        echo "protoc-gen-grpc-swift built and configured successfully."
    else
        echo "Error: Could not find built protoc-gen-grpc-swift plugin at '$PLUGIN_EXEC'." >&2
        exit 1
    fi
else
    echo "Warning: grpc-swift submodule not found at 'Dependencies/grpc-swift'." >&2
fi

echo ""
echo "Setup complete. You can now build the project."
