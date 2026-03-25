## Frequently Asked Questions

**Q:** Why does the app only scan `192.168.1.*`?
**A:** The original implementation assumes a typical home router subnet. Edit the `baseIP` variable in `DeviceManager` to change the subnet for other networks.

**Q:** What if I get a "Bulb not found" message?
**A:** Ensure the device is powered on and connected to the same Wi-Fi network. Verify that macOS firewall allows outgoing UDP traffic on port 38899.

**Q:** Can I control bulb color or brightness?
**A:** Yes! Smart bulbs support brightness control (10-100%) via a slider in the device detail view. Color control is not yet implemented.

**Q:** Does the app store device information for future launches?
**A:** Yes! Devices and rooms are persisted to UserDefaults and restored on app launch. Device IPs, names, types, room assignments, and brightness levels are all saved.

**Q:** How does device type detection work?
**A:** When scanning, the app calls `getSystemConfig` API on discovered devices and parses the `moduleName` field to determine the device type (Smart Bulb, Smart Plug, Smart Switch, Smart Strip).

**Q:** Can I use this app with non-Wiz devices?
**A:** No, the app is specifically designed for Wiz connected devices that use the Wiz UDP protocol on port 38899.

**Q:** Why is my device showing as "Syncing"?
**A:** Devices show "Syncing" (yellow indicator) when the app is fetching their current status. This usually resolves within a few seconds. If it persists, the device may be offline.

**Q:** Can I delete a room that still has devices?
**A:** No, rooms can only be deleted after all devices have been removed from that room or moved to another room. You'll see a warning if you try to delete a room with devices.

**Q:** What is the Auto Sync feature?
**A:** When enabled, the app automatically refreshes device status every 3 seconds to keep the UI up-to-date with the actual device state. This is enabled by default.

**Q:** Why does menu bar status sometimes show Connected but Off?
**A:** `Connected` indicates network reachability, while `On/Off` indicates power state. The app now separates both concepts, and menu bar power status is refreshed from live pilot responses.

**Q:** Can I sync data to iCloud?
**A:** Yes. Enable **Sync Data to iCloud** in Settings to sync devices, rooms, and app settings across Apple devices signed into the same iCloud account.

**Q:** I enabled iCloud sync but data is not syncing. Why?
**A:** iCloud sync requires iCloud capability/entitlements and valid code signing. Unsigned or locally run builds may not sync through iCloud even if the toggle is enabled.

**Q:** What is the App Animations setting?
**A:** This toggle controls whether UI animations are enabled (default: on). Turn it off for a snappier experience on slower systems.

**Q:** How do I add multiple devices?
**A:** Use the "Add Device" modal from the main window. The app will scan and show discovered devices one by one. You can skip or add each device with a custom name.
