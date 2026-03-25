## Development Setup

1. **Prerequisites**
   - macOS 12.0+.
   - Xcode 15 or newer (Swift 5.9).
   - Command‑line tools (`xcode-select --install`).
   - Ensure `nc` (netcat) is available (it ships with macOS).

2. **Clone the repository**
   ```bash
   git clone https://github.com/ezralazuardy/wiz.git
   cd wiz
   ```

3. **Open in Xcode**
   - Open any Swift file in the `src/` directory, e.g., `src/ContentView.swift`. Xcode will prompt to create a project – accept the defaults.
   - Alternatively, create a new macOS SwiftUI App project and drag the contents of `src/` into the project navigator.

4. **Build & Run**
   - Press **⌘R** to build and launch the app.
   - On first launch, macOS will ask for permission to access the local network – grant it.
   - The app scans for Wiz bulbs on the default subnet (`192.168.1.*`). Adjust `BulbService.connectBulb()` if your network uses a different range.
   - Auto Sync is enabled by default with a 3-second interval.
   - For terminal builds: `./build.sh`, then relaunch with `pkill -f "Wiz"` and `open dist/Wiz.app`.

5. **Testing**
   - The UI can be previewed with SwiftUI previews (`⌥⌘P`).
   - To test network interaction, run the app on the same Wi‑Fi network as a Wiz bulb.

6. **Troubleshooting**
   - If the app cannot find the bulb, verify that UDP traffic is not blocked by a firewall.
   - Ensure `nc` works from Terminal: `echo "test" | nc -u -w 1 192.168.1.X 38899`.
   - If iCloud sync is enabled but no cloud data appears, verify iCloud entitlements/capabilities are configured and app signing is valid.
