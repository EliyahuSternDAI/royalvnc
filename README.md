# RoyalVNCKit Fork

This repository is a fork of the original [RoyalVNCKit](https://github.com/royalapps/RoyalVNCKit) SDK. It has been modified to include a gRPC service for programmatic VNC control and to support modern development environments. The original README from the forked repository has been preserved as `README_original_fork.md`.

This project provides `RoyalVNCTool`, a command-line utility that runs a gRPC service for interacting with VNC servers, and `RoyalVNCKitGUIDemo`, a graphical VNC client for testing.

## Getting Started

Follow these steps to set up your local environment, build, and run the tools.

### Prerequisites

Before you begin, ensure your development environment meets the following requirements:

*   **macOS:** Version 11.0 (Big Sur) or newer.
*   **Xcode Command Line Tools:** Required for the Swift compiler and other build tools.
*   **Homebrew:** A package manager for macOS, used to install dependencies.

### 1. Install Prerequisites

If you don't have the tools installed, please install them.

*   **Xcode Command Line Tools:**
    ```bash
    xcode-select --install
    ```

*   **Homebrew:**
    ```bash
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    ```

### 2. Run the Environment Setup Script

This repository includes a script that handles the complete setup process, including initializing submodules and installing all dependencies. From the root of the repository, run:

```bash
./setup_environment.sh
```
This script will:
1.  Initialize and clone the `grpc-swift` submodule.
2.  Install `protoc` and `grpcurl` using Homebrew.
3.  Build the `protoc-gen-grpc-swift` code generator plugin.

## Building and Running

For detailed instructions on building, running, and testing the `RoyalVNCTool`, please refer to the **[README in its source directory](./Sources/RoyalVNCTool/README.md)**. It contains comprehensive information on:

-   Building for different architectures (Intel, Apple Silicon).
-   Running the gRPC service.
-   Testing with provided scripts.
-   Session management.
-   Code signing and entitlements.
