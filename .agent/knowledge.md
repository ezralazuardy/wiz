## Project Knowledge

- **Tech Stack**: Swift 5, SwiftUI, macOS (AppKit integration), AVFoundation for sound playback, `nc` (netcat) for UDP communication.
- **Architecture**: MVVM‑like pattern – `BulbService` handles networking and state, `ContentView` presents UI and interacts with the service via `@StateObject`. `WizRemoteApp` sets up the application window.
- **Networking**: Uses UDP broadcast to discover Wiz bulbs on the local subnet (`192.168.1.*`). Commands are sent via `nc -u` to port `38899`.
- **Audio Feedback**: Plays `on.wav`/`off.wav` located in the bundle.
- **Limitations**:
  - Hard‑coded IP range; requires modification for other networks.
  - Relies on `nc` being present on the system.
  - No persistence of bulb IP across launches.
- **Future Enhancements** (potential): dynamic subnet detection, color temperature control, UI theme support.
