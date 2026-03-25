import Foundation
import SwiftUI

class DeviceManager: ObservableObject {
    // Shared singleton instance
    static let shared = DeviceManager()

    @Published var devices: [WizDevice] = []
    @Published var rooms: [Room] = []
    @Published var discoveredDevices: [WizDevice] = []
    @Published var isScanning: Bool = false
    @Published var scanStatus: String = ""

    private let devicesKey = "savedWizDevices"
    private let roomsKey = "savedRooms"
    private let autoSyncKey = "autoSyncEnabled"
    private let menuBarKey = "menuBarEnabled"
    private let animationsKey = "appAnimationsEnabled"
    private let permissionsCheckedKey = "permissionsChecked"
    private let iCloudSyncKey = "iCloudSyncEnabled"
    private let baseIP = "192.168.1"
    private let iCloudStore = NSUbiquitousKeyValueStore.default
    private var isApplyingCloudUpdate = false
    private var defaultsObserver: NSObjectProtocol?
    private var iCloudObserver: NSObjectProtocol?

    private var syncedSettingsKeys: [String] {
        [autoSyncKey, menuBarKey, animationsKey, permissionsCheckedKey]
    }

    private var isICloudSyncEnabled: Bool {
        UserDefaults.standard.bool(forKey: iCloudSyncKey)
    }

    // Make init private to enforce singleton pattern
    private init() {
        registerDefaultSettings()
        setupSyncObservers()
        loadData()
        initializeICloudSyncIfNeeded()
        // Add default room if none exist
        if rooms.isEmpty {
            rooms = [Room(name: "Living Room", icon: "sofa")]
            saveData()
        }
    }

    // MARK: - Persistence

    func loadData() {
        if let devicesData = UserDefaults.standard.data(forKey: devicesKey),
            let savedDevices = try? JSONDecoder().decode([WizDevice].self, from: devicesData)
        {
            // Reset isSyncing to false for all loaded devices
            devices = savedDevices.map { device in
                var d = device
                d.isSyncing = false
                return d
            }
        }

        if let roomsData = UserDefaults.standard.data(forKey: roomsKey),
            let savedRooms = try? JSONDecoder().decode([Room].self, from: roomsData)
        {
            rooms = savedRooms
        }
    }

    func saveData(syncToICloud: Bool = true) {
        if let devicesData = try? JSONEncoder().encode(devices) {
            UserDefaults.standard.set(devicesData, forKey: devicesKey)
        }
        if let roomsData = try? JSONEncoder().encode(rooms) {
            UserDefaults.standard.set(roomsData, forKey: roomsKey)
        }
        if syncToICloud {
            syncCurrentStateToICloud(includeData: true, includeSettings: false)
        }
    }

    func resetData() {
        let cloudSyncWasEnabled = isICloudSyncEnabled
        UserDefaults.standard.removeObject(forKey: devicesKey)
        UserDefaults.standard.removeObject(forKey: roomsKey)

        // Reset all permissions and settings
        UserDefaults.standard.removeObject(forKey: autoSyncKey)
        UserDefaults.standard.removeObject(forKey: menuBarKey)
        UserDefaults.standard.removeObject(forKey: animationsKey)
        UserDefaults.standard.removeObject(forKey: permissionsCheckedKey)
        UserDefaults.standard.removeObject(forKey: iCloudSyncKey)

        devices = []
        rooms = [Room(name: "Living Room", icon: "sofa")]
        discoveredDevices = []
        if cloudSyncWasEnabled {
            clearCloudSnapshot()
        }
        saveData()

        // Notify menu bar to refresh
        NotificationCenter.default.post(name: Notification.Name("devicesDidChange"), object: nil)
    }

    func setICloudSyncEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: iCloudSyncKey)
        guard enabled else { return }

        iCloudStore.synchronize()
        let pulledAnyCloudData = applyCloudSnapshot()
        if !pulledAnyCloudData {
            syncCurrentStateToICloud(includeData: true, includeSettings: true)
        }
    }

    private func registerDefaultSettings() {
        UserDefaults.standard.register(defaults: [
            autoSyncKey: true,
            animationsKey: true,
            menuBarKey: false,
            iCloudSyncKey: false,
        ])
    }

    private func initializeICloudSyncIfNeeded() {
        guard isICloudSyncEnabled else { return }
        iCloudStore.synchronize()
        let pulledAnyCloudData = applyCloudSnapshot()
        if !pulledAnyCloudData {
            syncCurrentStateToICloud(includeData: true, includeSettings: true)
        }
    }

    private func setupSyncObservers() {
        defaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleLocalDefaultsDidChange()
        }

        iCloudObserver = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: iCloudStore,
            queue: .main
        ) { [weak self] _ in
            self?.handleExternalICloudChange()
        }
    }

    private func handleLocalDefaultsDidChange() {
        guard isICloudSyncEnabled else { return }
        guard !isApplyingCloudUpdate else { return }
        syncCurrentStateToICloud(includeData: false, includeSettings: true)
    }

    private func handleExternalICloudChange() {
        guard isICloudSyncEnabled else { return }
        guard !isApplyingCloudUpdate else { return }
        _ = applyCloudSnapshot()
    }

    private func syncCurrentStateToICloud(includeData: Bool, includeSettings: Bool) {
        guard isICloudSyncEnabled else { return }
        guard !isApplyingCloudUpdate else { return }

        if includeData {
            if let devicesData = try? JSONEncoder().encode(devices) {
                iCloudStore.set(devicesData, forKey: devicesKey)
            }
            if let roomsData = try? JSONEncoder().encode(rooms) {
                iCloudStore.set(roomsData, forKey: roomsKey)
            }
        }

        if includeSettings {
            for key in syncedSettingsKeys {
                iCloudStore.set(UserDefaults.standard.bool(forKey: key), forKey: key)
            }
        }

        iCloudStore.synchronize()
    }

    @discardableResult
    private func applyCloudSnapshot() -> Bool {
        var didApplyAnyValue = false
        isApplyingCloudUpdate = true

        if let cloudDevicesData = iCloudStore.data(forKey: devicesKey),
            let cloudDevices = try? JSONDecoder().decode([WizDevice].self, from: cloudDevicesData)
        {
            devices = cloudDevices.map { device in
                var d = device
                d.isSyncing = false
                return d
            }
            didApplyAnyValue = true
        }

        if let cloudRoomsData = iCloudStore.data(forKey: roomsKey),
            let cloudRooms = try? JSONDecoder().decode([Room].self, from: cloudRoomsData)
        {
            rooms = cloudRooms
            didApplyAnyValue = true
        }

        for key in syncedSettingsKeys {
            if let value = iCloudStore.object(forKey: key) as? Bool {
                UserDefaults.standard.set(value, forKey: key)
                didApplyAnyValue = true
            }
        }

        if didApplyAnyValue {
            saveData(syncToICloud: false)
            NotificationCenter.default.post(
                name: Notification.Name("devicesDidChange"), object: nil)
        }

        isApplyingCloudUpdate = false
        return didApplyAnyValue
    }

    private func clearCloudSnapshot() {
        iCloudStore.removeObject(forKey: devicesKey)
        iCloudStore.removeObject(forKey: roomsKey)
        for key in syncedSettingsKeys {
            iCloudStore.removeObject(forKey: key)
        }
        iCloudStore.synchronize()
    }

    // MARK: - Room Management

    func addRoom(name: String, icon: String = "house") {
        let room = Room(name: name, icon: icon)
        rooms.append(room)
        saveData()
    }

    func removeRoom(_ room: Room) {
        // Remove room from devices
        for i in devices.indices {
            if devices[i].roomID == room.id {
                devices[i].roomID = nil
            }
        }
        rooms.removeAll { $0.id == room.id }
        saveData()
    }

    func updateRoom(_ room: Room) {
        if let index = rooms.firstIndex(where: { $0.id == room.id }) {
            rooms[index] = room
            saveData()
        }
    }

    // MARK: - Device Management

    func addDevice(
        name: String, ipAddress: String, type: DeviceType = .smartBulb, roomID: UUID? = nil
    ) {
        let device = WizDevice(name: name, ipAddress: ipAddress, type: type, roomID: roomID)
        devices.append(device)
        saveData()
        // Notify menu bar to refresh
        NotificationCenter.default.post(name: Notification.Name("devicesDidChange"), object: nil)
    }

    func removeDevice(_ device: WizDevice) {
        devices.removeAll { $0.id == device.id }
        saveData()
        // Notify menu bar to refresh
        NotificationCenter.default.post(name: Notification.Name("devicesDidChange"), object: nil)
    }

    func updateDevice(_ device: WizDevice) {
        if let index = devices.firstIndex(where: { $0.id == device.id }) {
            devices[index] = device
            saveData()
            // Notify menu bar to refresh
            NotificationCenter.default.post(
                name: Notification.Name("devicesDidChange"), object: nil)
        }
    }

    func moveDeviceToRoom(device: WizDevice, roomID: UUID?) {
        if let index = devices.firstIndex(where: { $0.id == device.id }) {
            devices[index].roomID = roomID
            saveData()
        }
    }

    // MARK: - Device Status

    func fetchDeviceStatus(_ device: WizDevice, completion: @escaping (Bool?, Int?, Bool) -> Void) {
        DispatchQueue.global().async {
            // Keep response timeout short to make "Refreshing" state snappier.
            let command = #"""
                echo -n "{\"id\":1,\"method\":\"getPilot\",\"params\":{}}" | nc -u -w 1 \#(device.ipAddress) 38899
                """#
            let response = self.runShellCommand(command)

            DispatchQueue.main.async {
                // Parse response to check if light is on and get brightness
                // Response format: {"id":1,"result":{"mac":"...","rssi":-50,"src":"...","state":true,"dimming":100,...}}
                var isOn: Bool?
                var brightness: Int?

                // Check if we got any response at all
                var hasResponse = response.contains("\"result\"") || response.contains("state")

                // Parse JSON first for robust state/brightness extraction.
                if let data = response.data(using: .utf8),
                    let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                    let result = payload["result"] as? [String: Any]
                {
                    hasResponse = true
                    if let state = result["state"] as? Bool {
                        isOn = state
                    }
                    if let dimming = result["dimming"] as? Int {
                        brightness = dimming
                    } else if let dimming = result["dimming"] as? Double {
                        brightness = Int(dimming)
                    }
                }

                if hasResponse {
                    // Fallback parse state from raw response if JSON parsing didn't find it.
                    if isOn == nil
                        && (response.contains("\"state\":true")
                            || response.contains("\"state\": true"))
                    {
                        isOn = true
                    } else if isOn == nil
                        && (response.contains("\"state\":false")
                            || response.contains("\"state\": false"))
                    {
                        isOn = false
                    }

                    // Fallback parse brightness from raw response.
                    if brightness == nil, let range = response.range(of: "\"dimming\":") {
                        let start = range.upperBound
                        let endIndex = response.index(
                            start,
                            offsetBy: min(3, response.distance(from: start, to: response.endIndex)))
                        let dimmingStr = String(response[start..<endIndex])
                        brightness = Int(
                            dimmingStr.trimmingCharacters(in: .whitespacesAndNewlines)
                                .replacingOccurrences(of: "}", with: "").replacingOccurrences(
                                    of: ",", with: ""))
                    }
                }
                // No response means device might be unreachable (must be verified by caller before marking disconnected).

                completion(isOn, brightness, hasResponse)
            }
        }
    }

    func verifyNetworkReachability(_ device: WizDevice, completion: @escaping (Bool) -> Void) {
        DispatchQueue.global(qos: .utility).async {
            // Retry once to reduce false negatives from ICMP packet loss.
            let firstAttempt = self.pingHost(device.ipAddress)
            if firstAttempt {
                DispatchQueue.main.async {
                    completion(true)
                }
                return
            }

            usleep(200_000)  // 200ms pause before retry
            let secondAttempt = self.pingHost(device.ipAddress)
            DispatchQueue.main.async {
                completion(secondAttempt)
            }
        }
    }

    func setDeviceBrightness(
        _ device: WizDevice, brightness: Int, completion: @escaping (Bool) -> Void
    ) {
        DispatchQueue.global().async {
            let clampedBrightness = max(10, min(100, brightness))
            let command = #"""
                echo -n "{\"id\":1,\"method\":\"setPilot\",\"params\":{\"dimming\":\#(clampedBrightness)}}" | nc -u -w 1 \#(device.ipAddress) 38899
                """#
            let response = self.runShellCommand(command)

            DispatchQueue.main.async {
                completion(response.contains("\"success\":true"))
            }
        }
    }

    // MARK: - Device Discovery

    func detectDeviceType(from response: String) -> DeviceType {
        // Parse moduleName from getSystemConfig response
        // Example module names: ESP12_SHRGB1C_01, ESP12_SRGBW_01, ESP12_PLUG_01, ESP12_WALL_01
        if let range = response.range(of: "\"moduleName\":\"") {
            let start = range.upperBound
            if let end = response[start...].firstIndex(of: "\"") {
                let moduleName = String(response[start..<end])

                if moduleName.contains("PLUG") {
                    return .smartPlug
                } else if moduleName.contains("WALL") || moduleName.contains("SWITCH") {
                    return .smartSwitch
                } else if moduleName.contains("STRIP") {
                    return .smartStrip
                } else if moduleName.contains("RGB") || moduleName.contains("DW")
                    || moduleName.contains("TW")
                {
                    return .smartBulb
                }
            }
        }
        return .unknown
    }

    func fetchDeviceInfo(ip: String, completion: @escaping (DeviceType) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let command = #"""
                echo -n "{\"id\":1,\"method\":\"getSystemConfig\",\"params\":{}}" | nc -u -w 1 \#(ip) 38899
                """#
            let response = self.runShellCommand(command)
            let deviceType = self.detectDeviceType(from: response)
            DispatchQueue.main.async {
                completion(deviceType)
            }
        }
    }

    func startDiscovery() {
        isScanning = true
        scanStatus = "Scanning for devices..."
        discoveredDevices.removeAll()

        // Run discovery on background queue to not block UI
        DispatchQueue.global(qos: .userInitiated).async {
            let range = 2..<255
            let group = DispatchGroup()
            var foundIPs: [String] = []

            for i in range {
                let ip = "\(self.baseIP).\(i)"
                group.enter()

                DispatchQueue.global(qos: .userInitiated).async {
                    let testCommand = #"""
                        echo -n "{\"id\":1,\"method\":\"getProp\",\"params\":[\"power\"]}" | nc -u -w 1 \#(ip) 38899
                        """#
                    let response = self.runShellCommand(testCommand)

                    if response.contains("method") {
                        foundIPs.append(ip)
                        // Fetch device info to detect type
                        self.fetchDeviceInfo(ip: ip) { deviceType in
                            DispatchQueue.main.async {
                                let device = WizDevice(
                                    name: "Wiz Device", ipAddress: ip, type: deviceType,
                                    isConnected: true, lastSeen: Date())
                                if !self.discoveredDevices.contains(where: { $0.ipAddress == ip }) {
                                    self.discoveredDevices.append(device)
                                }
                            }
                        }
                    }
                    group.leave()
                }
            }

            group.notify(queue: .main) {
                self.isScanning = false
                if foundIPs.isEmpty {
                    self.scanStatus = "No new devices found"
                } else {
                    let newDevicesCount = self.discoveredDevices.filter { discovered in
                        !self.devices.contains(where: { $0.ipAddress == discovered.ipAddress })
                    }.count
                    self.scanStatus = "Found \(foundIPs.count) device(s), \(newDevicesCount) new"
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    self.scanStatus = ""
                }
            }
        }
    }

    func addDiscoveredDevice(_ device: WizDevice, customName: String, roomID: UUID? = nil) {
        var newDevice = device
        newDevice.name = customName
        newDevice.roomID = roomID
        devices.append(newDevice)
        saveData()
        // Notify menu bar to refresh
        NotificationCenter.default.post(name: Notification.Name("devicesDidChange"), object: nil)
    }

    // MARK: - Auto Sync

    private var autoSyncTimer: Timer?
    private var isAutoSyncEnabled = false

    func startAutoSync(interval: TimeInterval = 3.0) {
        stopAutoSync()  // Stop any existing timer
        isAutoSyncEnabled = true

        // Use a dispatch source timer that works even without a run loop
        autoSyncTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) {
            [weak self] _ in
            self?.syncAllDevices()
        }

        // Keep timer alive even when no run loop is active
        if let timer = autoSyncTimer {
            RunLoop.current.add(timer, forMode: .common)
        }

        // Sync immediately when starting
        syncAllDevices()
    }

    func stopAutoSync() {
        isAutoSyncEnabled = false
        autoSyncTimer?.invalidate()
        autoSyncTimer = nil
    }

    var autoSyncStatus: Bool {
        return isAutoSyncEnabled
    }

    func syncAllDevices() {
        for (index, var device) in devices.enumerated() {
            device.isSyncing = true
            devices[index] = device

            fetchDeviceStatus(device) {
                [weak self] (_: Bool?, brightness: Int?, didRespond: Bool) in
                DispatchQueue.main.async {
                    if let self = self,
                        let deviceIndex = self.devices.firstIndex(where: { $0.id == device.id })
                    {
                        self.devices[deviceIndex].isSyncing = false

                        if didRespond {
                            // ON/OFF is pilot state, not connectivity.
                            self.devices[deviceIndex].isConnected = true
                        } else {
                            self.verifyNetworkReachability(device) { isReachable in
                                if let latestIndex = self.devices.firstIndex(where: {
                                    $0.id == device.id
                                }) {
                                    self.devices[latestIndex].isConnected = isReachable
                                }
                            }
                        }

                        if let brightness = brightness {
                            self.devices[deviceIndex].brightness = brightness
                        }
                    }
                }
            }
        }
    }

    // MARK: - Shell Command

    private func runShellCommand(_ command: String) -> String {
        let process = Process()
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        process.arguments = ["-c", command]
        process.launchPath = "/bin/zsh"

        do {
            try process.run()
        } catch {
            return ""
        }

        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(decoding: data, as: UTF8.self)
    }

    private func pingHost(_ ipAddress: String) -> Bool {
        let process = Process()
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        process.arguments = ["-c", "1", "-W", "1000", ipAddress]
        process.launchPath = "/sbin/ping"

        do {
            try process.run()
        } catch {
            return false
        }

        process.waitUntilExit()
        return process.terminationStatus == 0
    }
}
