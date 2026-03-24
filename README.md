# Wiz

A lightweight macOS SwiftUI application to control Wiz smart bulbs locally over your network.

## Overview
The app scans your local network for Wiz bulbs using UDP, then sends commands directly to toggle the light on/off and set a warm white scene. All operations are performed locally – no cloud services are required.

## Features
- Local network discovery of Wiz bulbs
- Turn the bulb **on** (warm white) / **off**
- Visual status indicator (green = connected, red = not found)
- Sound feedback for on/off actions
- Simple, responsive UI built with SwiftUI

## Requirements
- macOS 12.0 or later
- Xcode 15+ (Swift 5.9) to build the project
- Network access to the local Wi‑Fi subnet (e.g., `192.168.1.x`)

## Build & Run

1. Clone the repository:
   ```bash
   git clone https://github.com/ezralazuardy/wiz.git
   cd .
   ```
2. Ensure an `.env` file exists (or copy the example):
   ```bash
   cp .env.example .env   # only needed the first time
   ```
3. Build, package, and launch the app with the provided script:
   ```bash
   bash build.sh
   open dist/Wiz.app
   ```

## Project Structure
- `ContentView.swift` – UI layout, button actions, and sound playback.
- `BulbService.swift` – Handles UDP discovery, command execution via `nc`, and status management.
- `WizRemoteApp.swift` – App entry point and window configuration.
- `on.wav` / `off.wav` – Audio cues for button presses.

## Known Limitations
- IP range is hard‑coded to `192.168.1.*`; modify `BulbService.connectBulb()` for other subnets.
- Requires the `nc` (netcat) utility, which is available by default on macOS.

## License
MIT – see the original repository for details.
