## Frequently Asked Questions

**Q:** Why does the app only scan `192.168.1.*`?
**A:** The original implementation assumes a typical home router subnet. Edit `BulbService.connectBulb()` to change the `base` variable for other networks.

**Q:** What if I get a "Bulb not found" message?
**A:** Ensure the bulb is powered on and connected to the same Wi‑Fi network. Verify that macOS firewall allows outgoing UDP traffic.

**Q:** Can I control bulb color or brightness?
**A:** Currently the app only toggles power and sets a warm white preset (`sceneId:11`). Extending functionality would involve sending different `setPilot` parameters.

**Q:** Does the app store the bulb IP for future launches?
**A:** No, the IP is discovered each time the app starts. Persisting the IP could be added as a future improvement.
