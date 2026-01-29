# Pi Island

A native macOS "Dynamic Island" style interface for the [Pi Coding Agent](https://github.com/badlogic/pi-mono). Provides glanceable status, permission gating, and cost monitoring without leaving your IDE.

## Overview

Pi Island consists of two components:

1. **Native macOS App** (`PiIsland/`) - A Swift/SwiftUI floating window that sits near the notch/menu bar
2. **Pi Extension** (`extension/pi-island.ts`) - Bridges the Pi Agent to the native app via Unix Domain Socket

## Quick Start

### 1. Build and Run the macOS App

```bash
cd PiIsland
swift build
.build/debug/PiIsland
```

### 2. Install the Extension

Copy the extension to your Pi extensions directory:

```bash
cp extension/pi-island.ts ~/.pi/agent/extensions/
```

Or for project-local installation:

```bash
mkdir -p .pi/extensions
cp extension/pi-island.ts .pi/extensions/
```

### 3. Run Pi

```bash
pi
```

The extension will automatically connect to Pi Island when both are running.

## Testing the Connection

To test the socket connection without running Pi:

```bash
# Start Pi Island first
cd PiIsland && .build/debug/PiIsland

# In another terminal, run the test script
node tests/test-bridge.mjs
```

You should see connection logs in the Pi Island console output.

## Architecture

```
+---------------------+       +---------------------------+
| macOS Environment   |       | Pi Agent Process (Node)   |
|                     |       |                           |
| +---------------+   |  IPC  | +---------------------+   |
| | Pi Island App |<=========>| | Pi-Bridge Ext       |   |
| | (Swift/SwiftUI)|  Socket  | | (TypeScript)        |   |
| +---------------+   |       | +---------------------+   |
|       ^             |       |           ^               |
|       |             |       |           |               |
| +---------------+   |       | +---------------------+   |
| | Window Server |   |       | | Core Runtime        |   |
| +---------------+   |       | +---------------------+   |
+---------------------+       +---------------------------+
```

## IPC Protocol (JSON-Lines)

| Direction      | Type        | Payload Example                           | Description              |
|----------------|-------------|-------------------------------------------|--------------------------|
| Agent -> UI    | `HANDSHAKE` | `{ "pid": 1234, "project": "/src" }`      | Session initiation       |
| Agent -> UI    | `STATUS`    | `{ "state": "thinking", "cost": 0.05 }`   | State update             |
| Agent -> UI    | `TOOL_START`| `{ "tool": "bash", "input": {...} }`      | Tool execution started   |
| Agent -> UI    | `TOOL_END`  | `{ "tool": "bash", "isError": false }`    | Tool execution ended     |
| Agent -> UI    | `TOOL_REQ`  | `{ "id": "req_1", "cmd": "rm -rf /" }`    | Permission request       |
| UI -> Agent    | `TOOL_RES`  | `{ "id": "req_1", "allow": false }`       | Permission verdict       |
| UI -> Agent    | `INTERRUPT` | `{}`                                      | Stop current generation  |

## Development

### SwiftUI Best Practices

This project follows SwiftUI best practices using these agent skills:

- **swiftui-expert-skill** - State management (`@Observable`, `@State`), modern APIs, view composition
- **swiftui-view-refactor** - View ordering, MV patterns, subview extraction
- **swiftui-ui-patterns** - Component patterns, sheet handling, navigation
- **swiftui-performance-audit** - Performance optimization, avoiding view invalidation storms
- **swift-concurrency** - Async/await, actors, `@MainActor`, Sendable conformance

Key patterns applied:
- `@Observable` for view models (not `ObservableObject`)
- `@MainActor` for UI-bound classes
- `foregroundStyle()` instead of `foregroundColor()`
- `clipShape(.rect(cornerRadius:))` instead of `cornerRadius()`
- Extracted subviews for composition and performance
- BSD sockets with `DispatchSource` for non-blocking I/O

### Project Structure

```
PiIsland/
  Package.swift              # Swift Package Manager config
  PiIsland/
    PiIslandApp.swift        # App entry point
    SocketServer.swift       # BSD socket server with DispatchSource
    FloatingWindow.swift     # NotchPanel, NotchViewModel, SwiftUI views

extension/
  pi-island.ts               # Pi agent extension

tests/
  test-bridge.mjs            # Socket communication test
```

## Development Status

See [PLAN.md](PLAN.md) for the implementation roadmap.

### Phase 1: The Bridge - COMPLETE
- [x] Swift Socket Server (BSD sockets + DispatchSource)
- [x] TypeScript Connector (test script)
- [x] Pi Extension scaffolding

### Phase 2: The Sentinel - COMPLETE
- [x] Event Streaming (STATUS, TOOL_START, TOOL_END)
- [x] Blocking Mechanism (permission requests)
- [x] Grant Loop (Allow/Deny responses)

### Phase 3: The Interface - IN PROGRESS
- [x] Floating Window (NotchPanel with proper window levels)
- [x] Notch geometry detection (safe area insets)
- [x] State Visualization (idle, thinking, executing, permission)
- [ ] Hover Physics refinement
- [ ] Click-Through edge cases

### Phase 4: Integration & Hardening
- [ ] Robust Reconnection
- [ ] Installer Script
- [ ] Documentation

## License

MIT
