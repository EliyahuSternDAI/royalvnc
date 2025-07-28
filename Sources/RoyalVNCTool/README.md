# RoyalVNCTool

`RoyalVNCTool` is a command-line utility that provides a gRPC service for interacting with a VNC server. It allows you to send key events, strings, and other commands to a VNC session programmatically.

## RoyalVNCKit SDK

The `RoyalVNCTool` is built on top of the RoyalVNCKit SDK, which is the core of this repository. RoyalVNCKit is a powerful, cross-platform VNC SDK that provides the foundation for building custom VNC client applications.

### Why RoyalVNCKit?

-   **Apple Remote Desktop Support:** The primary reason for choosing RoyalVNCKit was its support for the Apple Remote Desktop (ARD) authentication and security type. This is a crucial feature for interacting with macOS VNC servers, which often use ARD-specific protocols.
-   **Cross-Platform:** The SDK is also designed to work on macOS, iOS, Linux, Android, and Windows (via .NET bindings).
-   **Extensible:** It provides a flexible API that allows for building custom tools and applications, such as this gRPC service.

## Setup

Before you can build and run `RoyalVNCTool`, you need to set up the development environment. This involves installing `protoc` and `grpcurl`. A setup script is provided to automate this process.

From the root of the repository, run:

```bash
./setup_environment.sh
```

This script will download a local copy of `protoc` and use Homebrew to install `grpcurl`.

## Building

To build the tool, you can use the Swift Package Manager. From the root of the repository, run:

```bash
swift build --product RoyalVNCTool
```

This will build the `RoyalVNCTool` executable for your Mac's native architecture and place it in the `.build/debug` directory.

### Building a Universal Binary for macOS

To create a universal binary that runs on both Intel (`x86_64`) and Apple Silicon (`arm64`) Macs, you need to build for each architecture and then combine them using the `lipo` tool.

1.  **Build for Apple Silicon:**
    ```bash
    swift build --arch arm64 --product RoyalVNCTool
    ```

2.  **Build for Intel:**
    ```bash
    swift build --arch x86_64 --product RoyalVNCTool
    ```

3.  **Create the Universal Binary:**
    ```bash
    lipo -create -output .build/debug/RoyalVNCTool_universal \
        .build/arm64-apple-macosx/debug/RoyalVNCTool \
        .build/x86_64-apple-macosx/debug/RoyalVNCTool
    ```

This will create a single `RoyalVNCTool_universal` executable in the `.build/debug` directory that can be run on any modern Mac.

## Testing

`RoyalVNCTool` can be run as a gRPC server that listens for commands. To start the server, run:

```bash
swift run RoyalVNCTool
```

By default, the server listens on `localhost:8080`. You can then use a gRPC client, like `grpcurl`, to send commands to the server.

For example, to list the available services, you can run:

```bash
grpcurl -plaintext localhost:8080 list
```

To send a key event, you can use the `SendKeyEvent` method:

```bash
grpcurl -plaintext -d '{"keysym": "0x61"}' localhost:8080 VNCService/SendKeyEvent
```

### Testing with Scripts

The repository includes several shell scripts to make testing the gRPC service more convenient.

-   `vnc_test.sh`: A general-purpose script for sending commands to the `RoyalVNCTool` service.
-   `send_hello_world.sh`: An example script that uses `vnc_test.sh` to type "Hello world" into the VNC session.
-   `send_cmd_a.sh`: An example script that sends Command-A to select all text.

These scripts demonstrate how to use `grpcurl` to interact with the gRPC service for common tasks.

## Modifying the gRPC Service

If you need to change the gRPC service definition (e.g., add a new method or change a message type), you will need to edit the `.proto` file and then regenerate the Swift source code.

1.  **Edit the Proto File:** The service definition is located at `Sources/RoyalVNCTool/Protos/vnc.proto`.

2.  **Regenerate Swift Code:** After modifying the `.proto` file, run the following script from the root of the repository to update the generated Swift files:
    ```bash
    ./generate_protos.sh
    ```
    This script uses `protoc` and the `protoc-gen-grpc-swift` plugin to create the necessary `vnc.pb.swift` and `vnc.grpc.swift` files.
    
3. **Implement the Changes:** After regenerating the Swift files, you may need to implement the new methods in the `VNCServiceImpl` class.
    
## Session Management

The `RoyalVNCTool` is capable of managing multiple VNC sessions concurrently. Each session is tracked by a unique session ID (UUID). The core of this functionality is the `VNCSessionManager` class, which handles the lifecycle of each VNC connection.

### Starting a Session

To start a new VNC session, you can use the `StartSession` gRPC method. This method takes the hostname, port, and credentials for the VNC server and returns a unique session ID.

Example using `grpcurl`:

```bash
grpcurl -plaintext -d '{"hostname": "localhost", "port": 5901, "username": "user", "password": "password"}' localhost:8080 VNCService/StartSession
```

### Listing Sessions

You can list all active VNC sessions using the `ListSessions` method. This will return a list of all sessions with their IDs and connection details.

```bash
grpcurl -plaintext -d '{}' localhost:8080 VNCService/ListSessions
```

### Sending Commands to a Session

When sending commands like key events, you must specify the session ID to ensure the command is sent to the correct VNC session.

```bash
grpcurl -plaintext -d '{"sessionID": "YOUR_SESSION_ID", "keysym": "0x61"}' localhost:8080 VNCService/SendKeyEvent
```

### Stopping a Session

To terminate a VNC session, you can use the `StopSession` method, providing the session ID of the session you wish to close.

```bash
grpcurl -plaintext -d '{"sessionID": "YOUR_SESSION_ID"}' localhost:8080 VNCService/StopSession
```

## Command-Line Arguments

`RoyalVNCTool` supports the following command-line arguments:

-   `--debug` (or `-d`): Enables verbose debug logging. This is useful for troubleshooting issues with the VNC connection or the gRPC service.
-   `--socket` (or `-s`): Specifies the network socket for the gRPC server. This can be either a TCP port (e.g., `tcp:8080`) or a path to a Unix domain socket (e.g., `unix:/tmp/vnc.sock`). If not specified, it defaults to TCP port 5959.

## Code Signing

For distribution, the binary must be signed with a valid Apple Developer ID certificate. Without a signature, macOS Gatekeeper will prevent the application from running on other machines. A proper signature also prevents the macOS Application Firewall from prompting the user to allow incoming connections for the gRPC service.

You can sign the built executable using the `codesign` tool:

```bash
codesign --sign "Developer ID Application: Your Name (TEAMID)" --deep --force --verify --verbose .build/debug/RoyalVNCTool
```

Replace `"Developer ID Application: Your Name (TEAMID)"` with your actual Developer ID signature.

## Note on gRPC Service

A previous commit implemented a gRPC service compatible with newer versions of macOS. This service allows for more robust and programmatic control over VNC sessions, making it easier to automate and test VNC interactions. The `RoyalVNCTool` is the server-side implementation of this service.
