//
//  WizApp.swift
//  Wiz
//
//  Created by Aditya Bhadang on 21/05/25.
//

import SwiftUI

// Notification names for cross-module communication
extension Notification.Name {
    static let devicesDidChange = Notification.Name("devicesDidChange")
    static let deviceBrightnessDidChange = Notification.Name("deviceBrightnessDidChange")
}

@main
struct WizApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, ObservableObject {
    var statusItem: NSStatusItem?
    var deviceManager: DeviceManager?
    weak var mainWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        DispatchQueue.main.async {
            if let window = NSApplication.shared.windows.first {
                let size = NSSize(width: 900, height: 650)
                window.setContentSize(size)
                window.center()
                let defaultTitle = "Philips Wiz"
                let title = ProcessInfo.processInfo.environment["APP_TITLE"] ?? defaultTitle
                window.title = title
                window.styleMask.insert(.resizable)
                self.configureMainWindow(window)
            }
        }

        // Use shared DeviceManager instance
        deviceManager = DeviceManager.shared

        // Setup menu bar observer
        setupMenuBarObserver()

        // Setup timer to refresh device status periodically
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            self.refreshMenuBarIfNeeded()
        }

        // Setup background auto-sync that works even when window is closed
        setupBackgroundAutoSync()
    }

    func setupBackgroundAutoSync() {
        // Check if auto-sync should be enabled from UserDefaults
        let defaults = UserDefaults.standard
        let autoSyncEnabled = defaults.bool(forKey: "autoSyncEnabled")

        if autoSyncEnabled {
            DeviceManager.shared.startAutoSync()
        }

        // Listen for auto-sync setting changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(autoSyncSettingChanged),
            name: UserDefaults.didChangeNotification,
            object: nil
        )
    }

    @objc func autoSyncSettingChanged() {
        let defaults = UserDefaults.standard
        let autoSyncEnabled = defaults.bool(forKey: "autoSyncEnabled")

        if autoSyncEnabled && !DeviceManager.shared.autoSyncStatus {
            DeviceManager.shared.startAutoSync()
        } else if !autoSyncEnabled && DeviceManager.shared.autoSyncStatus {
            DeviceManager.shared.stopAutoSync()
        }
    }

    func setupMenuBarObserver() {
        // Check UserDefaults for menuBarEnabled setting
        let defaults = UserDefaults.standard
        let enabled = defaults.bool(forKey: "menuBarEnabled")
        updateMenuBar(enabled: enabled)

        // Observe changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(menuBarSettingChanged),
            name: UserDefaults.didChangeNotification,
            object: nil
        )

        // Observe device changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(devicesDidChange),
            name: Notification.Name("devicesDidChange"),
            object: nil
        )
    }

    @objc func devicesDidChange() {
        refreshMenuBarIfNeeded()
    }

    @objc func menuBarSettingChanged() {
        let defaults = UserDefaults.standard
        let enabled = defaults.bool(forKey: "menuBarEnabled")
        updateMenuBar(enabled: enabled)
    }

    func refreshMenuBarIfNeeded() {
        let defaults = UserDefaults.standard
        let enabled = defaults.bool(forKey: "menuBarEnabled")
        if enabled {
            refreshDeviceStateCache {
                self.updateMenuBar(enabled: enabled)
            }
        }
    }

    func updateMenuBar(enabled: Bool) {
        if enabled {
            if statusItem == nil {
                statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
                if let button = statusItem?.button {
                    button.image = NSImage(
                        systemSymbolName: "cube", accessibilityDescription: "Wiz")
                }
            }

            // Update menu with current devices
            let menu = NSMenu()

            // Add devices section
            if let devices = deviceManager?.devices, !devices.isEmpty {
                for device in devices {
                    // Create device name item (clickable only if connected)
                    let deviceNameItem = NSMenuItem(
                        title: "  \(device.name)",
                        action: device.isConnected ? #selector(deviceItemClicked(_:)) : nil,
                        keyEquivalent: ""
                    )

                    // Set device type icon
                    let iconName = getDeviceIconName(for: device)
                    if let icon = NSImage(systemSymbolName: iconName, accessibilityDescription: nil)
                    {
                        icon.isTemplate = true
                        deviceNameItem.image = icon
                    }

                    // Disable if disconnected
                    deviceNameItem.isEnabled = device.isConnected

                    deviceNameItem.representedObject = device
                    deviceNameItem.target = self
                    menu.addItem(deviceNameItem)

                    // Show connectivity separately from power state.
                    let statusText: String
                    if !device.isConnected {
                        statusText = "Disconnected"
                    } else if let isOn = deviceStateCache[device.id] {
                        statusText = isOn ? "On" : "Off"
                    } else {
                        statusText = "Connected"
                    }
                    let statusItem = NSMenuItem(
                        title: "    Status: \(statusText)",
                        action: nil,
                        keyEquivalent: ""
                    )
                    statusItem.isEnabled = false
                    menu.addItem(statusItem)

                    // Add brightness info and presets for smart bulbs
                    if device.type == .smartBulb && device.isConnected {
                        let brightnessItem = NSMenuItem(
                            title: "    Brightness: \(device.brightness)%",
                            action: nil,
                            keyEquivalent: ""
                        )
                        brightnessItem.isEnabled = false
                        menu.addItem(brightnessItem)

                        // Add brightness presets submenu
                        let brightnessSubmenu = NSMenu()
                        let presetValues = [25, 50, 75, 100]
                        for value in presetValues {
                            let presetItem = NSMenuItem(
                                title: "\(value)%",
                                action: #selector(brightnessPresetClicked(_:)),
                                keyEquivalent: ""
                            )
                            presetItem.representedObject =
                                ["device": device, "brightness": value] as [String: Any]
                            presetItem.target = self
                            brightnessSubmenu.addItem(presetItem)
                        }

                        let setBrightnessItem = NSMenuItem(
                            title: "    Set Brightness",
                            action: nil,
                            keyEquivalent: ""
                        )
                        setBrightnessItem.submenu = brightnessSubmenu
                        menu.addItem(setBrightnessItem)
                    }

                    // Add separator after each device
                    menu.addItem(NSMenuItem.separator())
                }
            }

            menu.addItem(
                NSMenuItem(title: "Open Wiz", action: #selector(openWiz), keyEquivalent: ""))
            menu.addItem(NSMenuItem.separator())
            menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))
            statusItem?.menu = menu
        } else {
            if let item = statusItem {
                NSStatusBar.system.removeStatusItem(item)
                statusItem = nil
            }
        }
    }

    @objc func deviceItemClicked(_ sender: NSMenuItem) {
        guard let device = sender.representedObject as? WizDevice,
            let deviceManager = deviceManager
        else { return }

        print("DEBUG: Menu bar - Toggling device: \(device.name), IP: \(device.ipAddress)")

        // Fetch current status first to ensure accurate toggle
        deviceManager.fetchDeviceStatus(device) { [weak self] status, brightness, didRespond in
            guard let self = self else { return }

            let currentState =
                didRespond
                ? (status ?? self.getLastKnownState(for: device))
                : self.getLastKnownState(for: device)
            let newState = !currentState
            self.setLastKnownState(for: device, state: currentState)

            print("DEBUG: Current state: \(currentState), New state: \(newState)")

            // Update state cache
            self.setLastKnownState(for: device, state: newState)

            // Update device brightness in memory
            if let brightness = brightness {
                var updatedDevice = device
                updatedDevice.brightness = brightness
                DeviceManager.shared.updateDevice(updatedDevice)
            }

            DispatchQueue.global(qos: .userInitiated).async {
                let service = BulbService()
                service.bulbIP = device.ipAddress

                if newState {
                    // Turn ON
                    if device.type == .smartBulb {
                        let brightnessValue = brightness ?? device.brightness
                        print("DEBUG: Menu bar - Turning ON with brightness: \(brightnessValue)")
                        service.lightOn(brightness: brightnessValue)
                    } else {
                        print("DEBUG: Menu bar - Turning ON")
                        service.lightOn()
                    }
                } else {
                    // Turn OFF
                    print("DEBUG: Menu bar - Turning OFF")
                    service.lightOff()
                }

                // Refresh menu after a short delay for UI feedback
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.refreshMenuBarIfNeeded()
                }
            }
        }
    }

    // Simple state cache for menu bar
    private var deviceStateCache: [UUID: Bool] = [:]

    func getLastKnownState(for device: WizDevice) -> Bool {
        // Return cached state or default to false (off)
        return deviceStateCache[device.id] ?? false
    }

    func setLastKnownState(for device: WizDevice, state: Bool) {
        deviceStateCache[device.id] = state
    }

    @objc func brightnessPresetClicked(_ sender: NSMenuItem) {
        guard let data = sender.representedObject as? [String: Any],
            let device = data["device"] as? WizDevice,
            let brightness = data["brightness"] as? Int
        else { return }

        print("DEBUG: Setting brightness to \(brightness)% for \(device.name)")

        DispatchQueue.global(qos: .userInitiated).async {
            let service = BulbService()
            service.bulbIP = device.ipAddress
            service.lightOn(brightness: brightness)

            // Update device brightness
            DispatchQueue.main.async {
                var updatedDevice = device
                updatedDevice.brightness = brightness
                DeviceManager.shared.updateDevice(updatedDevice)

                NotificationCenter.default.post(
                    name: .deviceBrightnessDidChange,
                    object: nil,
                    userInfo: ["deviceID": device.id, "brightness": brightness]
                )
                self.setLastKnownState(for: device, state: true)

                // Refresh menu after a short delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.refreshMenuBarIfNeeded()
                }
            }
        }
    }

    @objc func openWiz() {
        NSApp.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)

        if mainWindow == nil, let window = NSApplication.shared.windows.first {
            configureMainWindow(window)
        }

        // Bring window to front and make it key window
        if let window = mainWindow ?? NSApplication.shared.windows.first {
            if window.isMiniaturized {
                window.deminiaturize(nil)
            }
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
        }
    }

    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    // Handle window close behavior - keep app running when menu bar is enabled
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        let defaults = UserDefaults.standard
        let menuBarEnabled = defaults.bool(forKey: "menuBarEnabled")

        if menuBarEnabled {
            // Hide dock icon when window is closed and menu bar is enabled
            NSApp.setActivationPolicy(.accessory)
        }

        // Return false (don't terminate) if menu bar is enabled
        // Return true (terminate) if menu bar is disabled
        return !menuBarEnabled
    }

    // Show dock icon when app becomes active
    func applicationDidBecomeActive(_ notification: Notification) {
        let defaults = UserDefaults.standard
        let menuBarEnabled = defaults.bool(forKey: "menuBarEnabled")

        if menuBarEnabled {
            // Show dock icon when window is reopened
            NSApp.setActivationPolicy(.regular)
        }
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if isMenuBarEnabled() {
            sender.orderOut(nil)
            NSApp.setActivationPolicy(.accessory)
            return false
        }
        return true
    }

    private func configureMainWindow(_ window: NSWindow) {
        mainWindow = window
        window.delegate = self
        window.isReleasedWhenClosed = false
    }

    private func isMenuBarEnabled() -> Bool {
        UserDefaults.standard.bool(forKey: "menuBarEnabled")
    }

    private func refreshDeviceStateCache(completion: @escaping () -> Void) {
        guard let manager = deviceManager else {
            completion()
            return
        }

        let connectedDevices = manager.devices.filter { $0.isConnected }
        guard !connectedDevices.isEmpty else {
            completion()
            return
        }

        let group = DispatchGroup()
        for device in connectedDevices {
            group.enter()
            manager.fetchDeviceStatus(device) { [weak self] status, _, didRespond in
                if didRespond, let status {
                    self?.setLastKnownState(for: device, state: status)
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            completion()
        }
    }

    // Helper function to get device icon name
    func getDeviceIconName(for device: WizDevice) -> String {
        switch device.type {
        case .smartBulb:
            return "lightbulb.fill"
        case .smartPlug:
            return "powerplug.fill"
        case .smartSwitch:
            return "switch.2"
        case .smartStrip:
            return "poweroutlet.strip.fill"
        default:
            return "questionmark.circle.fill"
        }
    }
}
