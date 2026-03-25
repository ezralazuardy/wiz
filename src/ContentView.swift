import AVFoundation
import AppKit
import SwiftUI

// MARK: - Sound Player
class SoundPlayer: ObservableObject {
    var player: AVAudioPlayer?

    func play(_ name: String) {
        guard let url = Bundle.main.url(forResource: name, withExtension: "wav") else {
            print("Sound file '\(name).wav' not found.")
            return
        }

        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.volume = 1
            player?.play()
        } catch {
            print("Error playing sound: \(error.localizedDescription)")
        }
    }
}

// MARK: - Content View with Navigation
struct ContentView: View {
    @StateObject private var deviceManager = DeviceManager.shared
    @StateObject private var soundPlayer = SoundPlayer()
    @State private var selectedDeviceID: UUID?
    @State private var selectedFilter: SidebarView.DeviceFilter = .all
    @State private var showingAddDevice = false
    @State private var showingSettings = false
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    @State private var showingPermissionsOnboarding = false
    @AppStorage("permissionsChecked") private var permissionsChecked = false

    var filteredDevices: [WizDevice] {
        switch selectedFilter {
        case .all:
            return deviceManager.devices
        case .room(let roomID):
            return deviceManager.devices.filter { $0.roomID == roomID }
        }
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(
                deviceManager: deviceManager,
                selectedDeviceID: $selectedDeviceID,
                selectedFilter: $selectedFilter
            )
            .navigationTitle("Philips Wiz")
            .toolbar {
                ToolbarItem {
                    Button(action: { showingSettings = true }) {
                        Label("Settings", systemImage: "gear")
                    }
                    .keyboardShortcut(",", modifiers: [.command])
                }
                ToolbarItem {
                    Button(action: { showingAddDevice = true }) {
                        Label("Add", systemImage: "plus")
                    }
                }
            }
        } detail: {
            if let selectedID = selectedDeviceID,
                let device = deviceManager.devices.first(where: { $0.id == selectedID })
            {
                DeviceDetailView(
                    device: device,
                    deviceManager: deviceManager,
                    soundPlayer: soundPlayer
                )
            } else {
                DeviceListView(
                    devices: filteredDevices,
                    filter: selectedFilter,
                    deviceManager: deviceManager,
                    selectedDeviceID: $selectedDeviceID
                )
            }
        }
        .sheet(isPresented: $showingAddDevice) {
            AddDeviceView(deviceManager: deviceManager)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(deviceManager: deviceManager)
        }
        .sheet(isPresented: $showingPermissionsOnboarding) {
            PermissionsOnboardingView(isPresented: $showingPermissionsOnboarding)
        }
        .onAppear {
            // Check if we need to show permissions onboarding
            if !permissionsChecked {
                showingPermissionsOnboarding = true
            }

            // Setup keyboard shortcut for menu bar toggle (Cmd + /)
            NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                if event.modifierFlags.contains(.command) && event.characters == "/" {
                    // Toggle menu bar
                    let defaults = UserDefaults.standard
                    let currentValue = defaults.bool(forKey: "menuBarEnabled")
                    defaults.set(!currentValue, forKey: "menuBarEnabled")
                    return nil  // Consume the event
                }
                return event
            }
        }
        .task {
            // Delay discovery slightly to allow UI to fully render first
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                deviceManager.startDiscovery()
            }
        }
    }
}

// MARK: - Sidebar View
struct SidebarView: View {
    @ObservedObject var deviceManager: DeviceManager
    @Binding var selectedDeviceID: UUID?
    @Binding var selectedFilter: DeviceFilter
    @State private var deviceToDelete: WizDevice?
    @State private var showingDeleteConfirm = false
    @State private var roomToDelete: Room?
    @State private var showingRoomDeleteConfirm = false

    enum DeviceFilter: Hashable {
        case all
        case room(UUID)
    }

    var filteredDevices: [WizDevice] {
        switch selectedFilter {
        case .all:
            return deviceManager.devices
        case .room(let roomID):
            return deviceManager.devices.filter { $0.roomID == roomID }
        }
    }

    var body: some View {
        List {
            // Filter Section
            Section {
                Button(action: {
                    selectedFilter = .all
                    selectedDeviceID = nil
                }) {
                    HStack {
                        Label("All Devices", systemImage: "lightbulb.fill")
                        Spacer()
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .background(
                    selectedFilter == .all && selectedDeviceID == nil
                        ? Color.accentColor.opacity(0.1) : Color.clear
                )
                .cornerRadius(6)
            }

            // Rooms Section
            if !deviceManager.rooms.isEmpty {
                Section("Rooms") {
                    ForEach(deviceManager.rooms) { room in
                        Button(action: {
                            selectedFilter = .room(room.id)
                            selectedDeviceID = nil
                        }) {
                            HStack {
                                Label(room.name, systemImage: room.icon)
                                Spacer()
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .background(
                            selectedFilter == .room(room.id) && selectedDeviceID == nil
                                ? Color.accentColor.opacity(0.1) : Color.clear
                        )
                        .cornerRadius(6)
                        .contextMenu {
                            Button(role: .destructive) {
                                roomToDelete = room
                                showingRoomDeleteConfirm = true
                            } label: {
                                Label("Remove Room", systemImage: "trash")
                            }
                        }
                    }
                }
            }

            // Devices Section
            Section("Devices (\(filteredDevices.count))") {
                if filteredDevices.isEmpty {
                    Text("No devices")
                        .foregroundColor(.secondary)
                        .font(.caption)
                } else {
                    ForEach(filteredDevices) { device in
                        DeviceListItem(
                            device: device,
                            isSelected: selectedDeviceID == device.id,
                            onTap: {
                                selectedDeviceID = device.id
                            },
                            onDelete: {
                                deviceToDelete = device
                                showingDeleteConfirm = true
                            },
                            onMoveToRoom: { roomID in
                                deviceManager.moveDeviceToRoom(device: device, roomID: roomID)
                            },
                            rooms: deviceManager.rooms
                        )
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .alert("Remove Device?", isPresented: $showingDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Remove", role: .destructive) {
                if let device = deviceToDelete {
                    deviceManager.removeDevice(device)
                    if selectedDeviceID == device.id {
                        selectedDeviceID = nil
                    }
                }
            }
        } message: {
            if let device = deviceToDelete {
                Text("Are you sure you want to remove '\(device.name)'")
            }
        }
        .alert("Remove Room?", isPresented: $showingRoomDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Remove", role: .destructive) {
                if let room = roomToDelete {
                    let deviceCount = deviceManager.devices.filter { $0.roomID == room.id }.count
                    if deviceCount == 0 {
                        deviceManager.removeRoom(room)
                        if case .room(let selectedRoomID) = selectedFilter,
                            selectedRoomID == room.id
                        {
                            selectedFilter = .all
                        }
                    }
                }
            }
            .disabled(
                roomToDelete != nil
                    && deviceManager.devices.filter { $0.roomID == roomToDelete?.id }.count > 0)
        } message: {
            if let room = roomToDelete {
                let deviceCount = deviceManager.devices.filter { $0.roomID == room.id }.count
                if deviceCount > 0 {
                    Text(
                        "Room '\(room.name)' has \(deviceCount) device(s). Please remove all devices from this room first."
                    )
                } else {
                    Text("Are you sure you want to remove '\(room.name)'")
                }
            }
        }
    }
}

// MARK: - Device List Item
struct DeviceListItem: View {
    let device: WizDevice
    let isSelected: Bool
    let onTap: () -> Void
    let onDelete: () -> Void
    let onMoveToRoom: (UUID?) -> Void
    let rooms: [Room]

    var body: some View {
        Button(action: onTap) {
            HStack {
                Image(systemName: device.type.icon)
                    .foregroundColor(.primary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(device.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text(device.type.rawValue)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Circle()
                    .fill(device.isConnected ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 15)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
        .cornerRadius(6)
        .contextMenu {
            Button(role: .destructive, action: onDelete) {
                Label("Remove", systemImage: "trash")
            }

            if !rooms.isEmpty {
                Menu("Move to Room") {
                    ForEach(rooms) { room in
                        Button {
                            onMoveToRoom(room.id)
                        } label: {
                            Text(room.name)
                        }
                    }
                    Button {
                        onMoveToRoom(nil)
                    } label: {
                        Text("No Room")
                    }
                }
            }
        }
    }
}

// MARK: - Device Detail View
struct DeviceDetailView: View {
    let device: WizDevice
    @ObservedObject var deviceManager: DeviceManager
    @ObservedObject var soundPlayer: SoundPlayer
    @State private var isLightOn = false
    @State private var isLoadingStatus = true
    @State private var scale: CGFloat = 0.95
    @State private var autoSyncTimer: Timer?
    @State private var consecutiveFailures: Int = 0
    private let failureThreshold: Int = 3
    private let minimumBrightness: Int = 10
    @State private var initialFetchComplete = false
    @State private var showingRemoveConfirm = false
    @State private var showingEditDevice = false
    @State private var brightness: Double = 100
    @State private var isAdjustingBrightness = false
    @State private var isEditingBrightnessSlider = false
    @State private var isToggleInFlight = false
    @Environment(\.colorScheme) var colorScheme
    @AppStorage("appAnimationsEnabled") private var animationsEnabled = true

    var isBrightnessSliderDisabled: Bool {
        return !device.isConnected || isLoadingStatus || isToggleInFlight
    }

    var isToggleButtonDisabled: Bool {
        return !device.isConnected || isLoadingStatus || isToggleInFlight
    }

    @State private var backgroundOpacity: Double = 0

    private var statusGradientColor: Color {
        device.isConnected ? Color.green : Color.red
    }

    private var isRefreshing: Bool {
        isLoadingStatus || isToggleInFlight
    }

    private var statusDotColor: Color {
        if isRefreshing {
            return .blue
        }
        return device.isConnected ? .green : .red
    }

    private var statusText: String {
        if isRefreshing {
            return "Refreshing"
        }
        return device.isConnected ? "Connected" : "Disconnected"
    }

    var body: some View {
        ZStack {
            // Base gradient (blue default)
            LinearGradient(
                gradient: Gradient(colors: [Color.black, Color.blue.opacity(0.7)]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // Animated status gradient overlay
            LinearGradient(
                gradient: Gradient(colors: [Color.black, statusGradientColor.opacity(0.7)]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .opacity(backgroundOpacity)
            .animation(
                animationsEnabled ? .easeInOut(duration: 1.0) : nil, value: backgroundOpacity)

            VStack(spacing: 30) {
                Spacer()

                HStack(spacing: 8) {
                    Image(systemName: device.type.icon)
                    Text(device.type.rawValue)
                }
                .font(.custom("Avenir", size: 16))
                .foregroundColor(.white.opacity(0.8))

                HStack(spacing: 16) {
                    if let room = deviceManager.rooms.first(where: { $0.id == device.roomID }) {
                        HStack(spacing: 4) {
                            Image(systemName: room.icon)
                            Text(room.name)
                        }
                        .font(.custom("Avenir", size: 14))
                        .foregroundColor(.white.opacity(0.6))
                    }

                    Text(device.ipAddress)
                        .font(.custom("Avenir", size: 14))
                        .foregroundColor(.white.opacity(0.7))
                }

                Spacer()

                Button(action: toggleLight) {
                    HStack {
                        Image(systemName: isLightOn ? "lightbulb.fill" : "lightbulb.slash")
                        Text(isLightOn ? "Turn Off" : "Turn On")
                    }
                    .font(.custom("Avenir-Heavy", size: 17))
                    .frame(width: 160, height: 55)
                    .background(isLightOn ? Color.red : Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(28)
                    .scaleEffect(scale)
                    .shadow(
                        color: colorScheme == .dark
                            ? Color.white.opacity(0.6) : Color.black.opacity(0.4),
                        radius: 8, x: 0, y: 0
                    )
                }
                .buttonStyle(.plain)
                .disabled(isToggleButtonDisabled)
                .opacity(isToggleButtonDisabled ? 0.5 : 1.0)

                // Brightness slider for smart bulbs
                if device.type == .smartBulb {
                    VStack(spacing: 8) {
                        HStack {
                            Image(systemName: "sun.min.fill")
                                .foregroundColor(.white)
                            Slider(
                                value: $brightness,
                                in: Double(minimumBrightness)...100,
                                step: 1
                            ) { editing in
                                isEditingBrightnessSlider = editing
                                if !editing {
                                    setDeviceBrightness(Int(brightness.rounded()))
                                }
                            }
                            .disabled(isBrightnessSliderDisabled)
                            .opacity(isBrightnessSliderDisabled ? 0.5 : 1.0)
                            Image(systemName: "sun.max.fill")
                                .foregroundColor(.white)
                        }

                        Text("\(Int(brightness))%")
                            .font(.custom("Avenir", size: 14))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding(.horizontal, 30)
                }

                Spacer()

                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(statusDotColor)
                            .frame(width: 10, height: 10)
                        Text(statusText)
                            .font(.custom("Avenir", size: 14))
                            .foregroundColor(.white)
                    }

                }

                Spacer()
            }
            .padding(.horizontal, 30)
        }
        .navigationTitle(device.name)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    showingEditDevice = true
                } label: {
                    Label("Edit", systemImage: "pencil")
                }

                Button {
                    fetchDeviceStatus(isInitial: false, showRefreshing: true)
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }

                Button(role: .destructive) {
                    showingRemoveConfirm = true
                } label: {
                    Label("Remove", systemImage: "trash")
                }
            }
        }
        .sheet(isPresented: $showingEditDevice) {
            EditDeviceView(
                device: device,
                deviceManager: deviceManager,
                onDismiss: { showingEditDevice = false }
            )
        }
        .alert("Remove Device?", isPresented: $showingRemoveConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Remove", role: .destructive) {
                deviceManager.removeDevice(device)
            }
        } message: {
            Text("Are you sure you want to remove '\(device.name)'?")
        }
        .onAppear {
            brightness = Double(clampedBrightness(device.brightness))
            fetchDeviceStatus(isInitial: true)
            startAutoSyncTimer()
        }
        .onDisappear {
            stopAutoSyncTimer()
        }
        .onChange(of: device.brightness) { _, newBrightness in
            syncSliderFromDeviceBrightness(newBrightness)
        }
        .onReceive(NotificationCenter.default.publisher(for: .deviceBrightnessDidChange)) {
            notification in
            handleExternalBrightnessNotification(notification)
        }
    }

    private func fetchDeviceStatus(isInitial: Bool = false, showRefreshing: Bool = false) {
        let shouldShowRefreshing = isInitial || showRefreshing

        // Show loading state when explicitly requested.
        if shouldShowRefreshing {
            isLoadingStatus = true
        }

        deviceManager.fetchDeviceStatus(device) { status, deviceBrightness, didRespond in
            let currentDevice =
                deviceManager.devices.first(where: { $0.id == device.id }) ?? device
            let previousConnection = currentDevice.isConnected
            var updatedDevice = currentDevice

            // `status` is ON/OFF state, while `didRespond` indicates network reachability.

            if didRespond {
                // Got response - device is connected, regardless of light state
                self.consecutiveFailures = 0
                updatedDevice.isConnected = true

                // Only update ON/OFF UI state if the value is present in payload.
                if let status = status {
                    isLightOn = status
                }

                reconcileBrightnessState(
                    reportedBrightness: deviceBrightness,
                    previousConnection: previousConnection,
                    updatedDevice: &updatedDevice
                )
            } else {
                // No response - device might be disconnected
                // Don't increment counter on initial fetch to prevent false disconnected state
                if !isInitial {
                    self.consecutiveFailures += 1
                    print(
                        "DEBUG: No response from device (\(self.consecutiveFailures)/\(self.failureThreshold))"
                    )

                    // Only mark disconnected after threshold failures, and only after
                    // explicit network reachability verification.
                    if self.consecutiveFailures >= self.failureThreshold {
                        deviceManager.verifyNetworkReachability(device) { isReachable in
                            var verifiedDevice = updatedDevice
                            verifiedDevice.isConnected = isReachable
                            if isReachable {
                                self.consecutiveFailures = 0
                            }
                            finalizeStatusUpdate(
                                verifiedDevice,
                                isInitial: isInitial,
                                clearLoading: shouldShowRefreshing
                            )
                        }
                        return
                    }
                }
            }

            finalizeStatusUpdate(
                updatedDevice,
                isInitial: isInitial,
                clearLoading: shouldShowRefreshing
            )
        }
    }

    private func finalizeStatusUpdate(
        _ updatedDevice: WizDevice, isInitial: Bool, clearLoading: Bool
    ) {
        // Mark initial fetch complete and enable controls
        if isInitial {
            self.initialFetchComplete = true
        }
        if clearLoading {
            self.isLoadingStatus = false
        }

        deviceManager.updateDevice(updatedDevice)

        // Animate background when status is known
        if animationsEnabled {
            withAnimation(.easeInOut(duration: 1.0)) {
                backgroundOpacity = 1.0
            }
        }
    }

    private func startAutoSyncTimer() {
        // Start auto-sync timer for this detail page
        autoSyncTimer?.invalidate()
        autoSyncTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            if self.isLoadingStatus || self.isToggleInFlight {
                return
            }
            self.fetchDeviceStatus(isInitial: false)
        }
    }

    private func stopAutoSyncTimer() {
        autoSyncTimer?.invalidate()
        autoSyncTimer = nil
    }

    private func setDeviceBrightness(_ value: Int, forceWhenOutOfSync: Bool = false) {
        guard !isAdjustingBrightness else { return }
        guard !isToggleInFlight else { return }
        guard let latestDevice = deviceManager.devices.first(where: { $0.id == device.id }) else {
            return
        }
        guard latestDevice.isConnected else { return }
        if !forceWhenOutOfSync && latestDevice.isSyncing { return }

        let clampedValue = clampedBrightness(value)
        isAdjustingBrightness = true
        deviceManager.setDeviceBrightness(latestDevice, brightness: clampedValue) { success in
            DispatchQueue.main.async {
                self.isAdjustingBrightness = false
                if success {
                    if let refreshedDevice = deviceManager.devices.first(where: {
                        $0.id == device.id
                    }) {
                        var updatedDevice = refreshedDevice
                        updatedDevice.brightness = clampedValue
                        deviceManager.updateDevice(updatedDevice)
                    }
                }
            }
        }
    }

    private func reconcileBrightnessState(
        reportedBrightness: Int?,
        previousConnection: Bool,
        updatedDevice: inout WizDevice
    ) {
        guard updatedDevice.type == .smartBulb else { return }

        let sliderBrightness = clampedBrightness(Int(brightness.rounded()))
        let connectionChanged = previousConnection != updatedDevice.isConnected

        // Only update slider from device brightness when connectivity changes.
        if connectionChanged {
            if let reportedBrightness = reportedBrightness {
                let clampedReported = clampedBrightness(reportedBrightness)
                updatedDevice.brightness = clampedReported
                brightness = Double(clampedReported)
            }
            return
        }

        // While connected and stable, prioritize user slider value as source of truth.
        updatedDevice.brightness = sliderBrightness

        guard let reportedBrightness = reportedBrightness else { return }
        let clampedReported = clampedBrightness(reportedBrightness)

        if clampedReported != sliderBrightness {
            setDeviceBrightness(sliderBrightness, forceWhenOutOfSync: true)
        }
    }

    private func syncSliderFromDeviceBrightness(_ newBrightness: Int) {
        guard device.type == .smartBulb else { return }
        guard !isAdjustingBrightness else { return }
        guard !isEditingBrightnessSlider else { return }
        guard !isToggleInFlight else { return }

        let clamped = clampedBrightness(newBrightness)
        if Int(brightness.rounded()) != clamped {
            brightness = Double(clamped)
        }
    }

    private func handleExternalBrightnessNotification(_ notification: Notification) {
        guard device.type == .smartBulb else { return }
        guard let userInfo = notification.userInfo else { return }
        guard let deviceID = userInfo["deviceID"] as? UUID, deviceID == device.id else { return }
        guard let newBrightness = userInfo["brightness"] as? Int else { return }

        syncSliderFromDeviceBrightness(newBrightness)
    }

    private func clampedBrightness(_ value: Int) -> Int {
        max(minimumBrightness, min(100, value))
    }

    private func toggleLight() {
        guard !isToggleInFlight else { return }
        guard let latestDevice = deviceManager.devices.first(where: { $0.id == device.id }),
            latestDevice.isConnected
        else { return }

        // Capture current state and calculate new state
        let currentState = isLightOn
        let newState = !currentState

        print("DEBUG: Toggling light - current: \(currentState), new: \(newState)")
        print("DEBUG: Device IP: \(device.ipAddress)")
        isToggleInFlight = true
        isLoadingStatus = true

        withAnimation(.spring(response: 0.35, dampingFraction: 0.3)) {
            scale = 1.1
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                scale = 0.95
            }
        }

        let service = BulbService()
        service.bulbIP = latestDevice.ipAddress
        let targetBrightness =
            latestDevice.type == .smartBulb ? clampedBrightness(Int(brightness.rounded())) : nil

        service.setPower(isOn: newState, brightness: targetBrightness) { success in
            if success {
                soundPlayer.play(newState ? "on" : "off")
            }

            self.isToggleInFlight = false
            self.fetchDeviceStatus(isInitial: false, showRefreshing: true)
        }
    }
}

// MARK: - Edit Device View
struct EditDeviceView: View {
    let device: WizDevice
    @ObservedObject var deviceManager: DeviceManager
    let onDismiss: () -> Void
    @State private var deviceName: String
    @State private var selectedRoomID: UUID?

    init(device: WizDevice, deviceManager: DeviceManager, onDismiss: @escaping () -> Void) {
        self.device = device
        self.deviceManager = deviceManager
        self.onDismiss = onDismiss
        _deviceName = State(initialValue: device.name)
        _selectedRoomID = State(initialValue: device.roomID)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Edit Device")
                        .font(.title)
                        .fontWeight(.bold)

                    Text(device.ipAddress)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Form content
            VStack(alignment: .leading, spacing: 20) {
                // Device info card
                HStack(spacing: 16) {
                    Image(systemName: device.type.icon)
                        .font(.title)
                        .foregroundColor(.white)
                        .frame(width: 50, height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.accentColor.opacity(0.8))
                        )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(device.type.rawValue)
                            .font(.headline)
                        Text("IP: \(device.ipAddress)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                )

                // Device name input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Device Name")
                        .font(.headline)

                    TextField("e.g., Living Room Light", text: $deviceName)
                        .textFieldStyle(.roundedBorder)
                        .frame(height: 28)
                }

                // Room selection
                if !deviceManager.rooms.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Room (Optional)")
                            .font(.headline)

                        Picker("Select Room", selection: $selectedRoomID) {
                            Text("None")
                                .tag(nil as UUID?)
                            ForEach(deviceManager.rooms) { room in
                                HStack {
                                    Image(systemName: room.icon)
                                    Text(room.name)
                                }
                                .tag(room.id as UUID?)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                    }
                }

                Spacer()

                // Action buttons
                HStack {
                    Button("Cancel") {
                        onDismiss()
                    }
                    .buttonStyle(.bordered)

                    Spacer()

                    Button("Save Changes") {
                        var updatedDevice = device
                        updatedDevice.name = deviceName
                        updatedDevice.roomID = selectedRoomID
                        deviceManager.updateDevice(updatedDevice)
                        onDismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(deviceName.isEmpty)
                }
                .padding(.bottom, 16)
            }
            .padding(.horizontal)
            .padding(.top)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 450, height: 400)
    }
}

// MARK: - Device List View
struct DeviceListView: View {
    let devices: [WizDevice]
    let filter: SidebarView.DeviceFilter
    @ObservedObject var deviceManager: DeviceManager
    @Binding var selectedDeviceID: UUID?

    var title: String {
        switch filter {
        case .all:
            return "All Devices"
        case .room(let roomID):
            if let room = deviceManager.rooms.first(where: { $0.id == roomID }) {
                return room.name
            }
            return "Room"
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(title)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.horizontal)
                    .padding(.top)

                if devices.isEmpty {
                    VStack(spacing: 20) {
                        Spacer()
                        Image(systemName: "lightbulb.slash")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)

                        Text("No Devices")
                            .font(.title2)
                            .fontWeight(.semibold)

                        Text("There is no devices assigned")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, minHeight: 400)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 200))], spacing: 16) {
                        ForEach(devices) { device in
                            DeviceCard(
                                device: device,
                                isSelected: selectedDeviceID == device.id,
                                onTap: {
                                    selectedDeviceID = device.id
                                }
                            )
                        }
                    }
                    .padding(.horizontal)
                }

                Spacer()
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
    }
}

// MARK: - Device Card
struct DeviceCard: View {
    let device: WizDevice
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "lightbulb.fill")
                        .font(.title2)
                        .foregroundColor(.white)

                    Spacer()

                    Circle()
                        .fill(device.isConnected ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(device.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    Text(device.ipAddress)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(height: 100)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                isSelected
                    ? Color.accentColor.opacity(0.2)
                    : Color(NSColor.tertiarySystemFill)
            )
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isSelected ? Color.accentColor : Color.secondary.opacity(0.2),
                        lineWidth: isSelected ? 2 : 1)
            )
            .shadow(
                color: Color.black.opacity(0.1),
                radius: 4,
                x: 0,
                y: 2
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Empty State View
struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "lightbulb.slash")
                .font(.system(size: 60))
                .foregroundColor(.gray)

            Text("No Device Selected")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Select a device from the sidebar or add a new one")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

// MARK: - Settings View
struct SettingsView: View {
    @ObservedObject var deviceManager: DeviceManager
    @Environment(\.dismiss) var dismiss
    @State private var newRoomName = ""
    @State private var selectedIcon = "house"
    @State private var showingResetConfirm = false
    @State private var roomToDelete: Room?
    @State private var showingRoomDeleteConfirm = false

    let iconOptions = [
        "house", "sofa", "bed.double", "cooktop", "shower", "car", "tree", "gamecontroller.fill",
    ]
    @AppStorage("autoSyncEnabled") private var autoSyncEnabled = true
    @AppStorage("appAnimationsEnabled") private var animationsEnabled = true
    @AppStorage("menuBarEnabled") private var menuBarEnabled = false
    @AppStorage("iCloudSyncEnabled") private var iCloudSyncEnabled = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Settings")
                    .font(.title)
                    .fontWeight(.bold)
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()

            Divider()

            // Content
            Form {
                Section("Manage Rooms") {
                    // Add new room
                    VStack(alignment: .leading, spacing: 12) {
                        TextField("New Room Name", text: $newRoomName)

                        Text("Select Icon")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: 12) {
                            ForEach(iconOptions, id: \.self) { icon in
                                Button {
                                    selectedIcon = icon
                                } label: {
                                    Image(systemName: icon)
                                        .font(.title3)
                                        .frame(width: 40, height: 40)
                                        .background(
                                            selectedIcon == icon
                                                ? Color.accentColor.opacity(0.2)
                                                : Color(NSColor.controlBackgroundColor)
                                        )
                                        .foregroundColor(
                                            selectedIcon == icon ? .accentColor : .primary
                                        )
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        Button("Add Room") {
                            if !newRoomName.isEmpty {
                                deviceManager.addRoom(name: newRoomName, icon: selectedIcon)
                                newRoomName = ""
                            }
                        }
                        .disabled(newRoomName.isEmpty)
                    }
                    .padding(.vertical, 8)

                    // Existing rooms with delete button
                    if !deviceManager.rooms.isEmpty {
                        Section("Existing Rooms") {
                            ForEach(deviceManager.rooms) { room in
                                HStack {
                                    Image(systemName: room.icon)
                                        .foregroundColor(.accentColor)
                                        .frame(width: 24)
                                    Text(room.name)
                                    Spacer()
                                    Button(action: {
                                        roomToDelete = room
                                        showingRoomDeleteConfirm = true
                                    }) {
                                        Image(systemName: "trash")
                                            .foregroundColor(.red)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }

                Section("Device Sync") {
                    Toggle("Auto Sync Device Status", isOn: $autoSyncEnabled)
                        .onChange(of: autoSyncEnabled) { _, newValue in
                            if newValue {
                                deviceManager.startAutoSync()
                            } else {
                                deviceManager.stopAutoSync()
                            }
                        }

                    if autoSyncEnabled {
                        Text("Device status will be updated automatically every 3 seconds")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Section("Cloud Sync") {
                    Toggle("Sync Data to iCloud", isOn: $iCloudSyncEnabled)
                        .onChange(of: iCloudSyncEnabled) { _, newValue in
                            deviceManager.setICloudSyncEnabled(newValue)
                        }

                    Text("Sync devices, rooms, and app settings across your Apple devices.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Section("App Settings") {
                    Toggle("App Animations", isOn: $animationsEnabled)

                    if animationsEnabled {
                        Text("Animations are enabled for smooth transitions and effects")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Toggle("Show Menu Icon", isOn: $menuBarEnabled)

                    if menuBarEnabled {
                        Text("App icon will appear in the macOS menu bar for quick access")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Section("Data Management") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(
                            "This will permanently delete all devices, rooms, and settings.\nThis action cannot be undone."
                        )
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)

                        HStack {
                            Spacer()
                            Button(role: .destructive) {
                                showingResetConfirm = true
                            } label: {
                                HStack {
                                    Image(systemName: "arrow.counterclockwise")
                                    Text("Reset All Data")
                                }
                                .foregroundColor(.red)
                            }
                        }
                    }
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 500, height: 550)
        .alert("Reset All Data?", isPresented: $showingResetConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                deviceManager.resetData()
            }
        } message: {
            Text("This will remove all devices and rooms. This action cannot be undone.")
        }
        .alert("Remove Room?", isPresented: $showingRoomDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Remove", role: .destructive) {
                if let room = roomToDelete {
                    let deviceCount = deviceManager.devices.filter { $0.roomID == room.id }.count
                    if deviceCount == 0 {
                        deviceManager.removeRoom(room)
                    }
                }
            }
            .disabled(
                roomToDelete != nil
                    && deviceManager.devices.filter { $0.roomID == roomToDelete?.id }.count > 0)
        } message: {
            if let room = roomToDelete {
                let deviceCount = deviceManager.devices.filter { $0.roomID == room.id }.count
                if deviceCount > 0 {
                    Text(
                        "Room '\(room.name)' has \(deviceCount) device(s). Please remove all devices from this room first."
                    )
                } else {
                    Text("Are you sure you want to remove '\(room.name)'")
                }
            }
        }
    }

    private func deleteRooms(at offsets: IndexSet) {
        for index in offsets {
            let room = deviceManager.rooms[index]
            deviceManager.removeRoom(room)
        }
    }
}

// MARK: - Add Device Steps
enum AddDeviceStep {
    case scanning
    case scanningComplete
    case selectDevice
    case deviceDetails
    case noDevicesFound
}

// MARK: - Add Device View
struct AddDeviceView: View {
    @ObservedObject var deviceManager: DeviceManager
    @Environment(\.dismiss) var dismiss
    @State private var currentStep: AddDeviceStep = .scanning
    @State private var selectedDevice: WizDevice?
    @State private var deviceName = ""
    @State private var selectedRoomID: UUID?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Add Device")
                        .font(.title)
                        .fontWeight(.bold)

                    // Step indicator
                    HStack(spacing: 8) {
                        let isScanningComplete =
                            currentStep == .scanningComplete || currentStep == .selectDevice
                            || currentStep == .deviceDetails || currentStep == .noDevicesFound
                        StepIndicator(
                            number: 1, label: "Scan",
                            isActive: currentStep == .scanning || currentStep == .scanningComplete,
                            isCompleted: isScanningComplete)
                        StepConnector(isCompleted: isScanningComplete)
                        StepIndicator(
                            number: 2, label: "Select", isActive: currentStep == .selectDevice,
                            isCompleted: currentStep == .deviceDetails)
                        StepConnector(isCompleted: currentStep == .deviceDetails)
                        StepIndicator(
                            number: 3, label: "Details", isActive: currentStep == .deviceDetails,
                            isCompleted: false)
                    }
                    .padding(.top, 8)
                }

                Spacer()

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Content based on step
            contentForCurrentStep
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 500, height: 500)
        .onAppear {
            if currentStep == .scanning && !deviceManager.isScanning {
                deviceManager.startDiscovery()
            }
        }
        .onChange(of: deviceManager.isScanning) { _, isScanning in
            if !isScanning && currentStep == .scanning {
                // Scanning just completed - show "Scanning Completed" state
                withAnimation {
                    currentStep = .scanningComplete
                }

                // Wait 2 seconds then decide next step
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    withAnimation {
                        if newDevices.isEmpty {
                            currentStep = .noDevicesFound
                        } else {
                            currentStep = .selectDevice
                        }
                    }
                }
            }
        }
    }

    private var newDevices: [WizDevice] {
        deviceManager.discoveredDevices.filter { discovered in
            !deviceManager.devices.contains(where: { $0.ipAddress == discovered.ipAddress })
        }
    }

    @ViewBuilder
    private var contentForCurrentStep: some View {
        switch currentStep {
        case .scanning:
            ScanningStepView(deviceManager: deviceManager)
        case .scanningComplete:
            ScanningCompletedView()
        case .noDevicesFound:
            NoDevicesFoundView(onRescan: {
                deviceManager.startDiscovery()
                withAnimation {
                    currentStep = .scanning
                }
            })
        case .selectDevice:
            SelectDeviceStepView(
                devices: newDevices,
                onSelect: { device in
                    selectedDevice = device
                    // Pre-fill device name
                    deviceName = "\(device.type.rawValue)"
                    withAnimation {
                        currentStep = .deviceDetails
                    }
                },
                onRescan: {
                    deviceManager.startDiscovery()
                    withAnimation {
                        currentStep = .scanning
                    }
                }
            )
        case .deviceDetails:
            if let device = selectedDevice {
                DeviceDetailsStepView(
                    device: device,
                    deviceName: $deviceName,
                    selectedRoomID: $selectedRoomID,
                    rooms: deviceManager.rooms,
                    onBack: {
                        withAnimation {
                            currentStep = .selectDevice
                            selectedDevice = nil
                        }
                    },
                    onAdd: {
                        deviceManager.addDiscoveredDevice(
                            device,
                            customName: deviceName,
                            roomID: selectedRoomID
                        )
                        // Remove from discovered list
                        deviceManager.discoveredDevices.removeAll {
                            $0.ipAddress == device.ipAddress
                        }

                        // Reset for next device
                        selectedDevice = nil
                        deviceName = ""
                        selectedRoomID = nil

                        // Go back to select step if more devices, else close
                        if newDevices.isEmpty {
                            dismiss()
                        } else {
                            withAnimation {
                                currentStep = .selectDevice
                            }
                        }
                    }
                )
            }
        }
    }
}

// MARK: - Step Indicator Components
struct StepIndicator: View {
    let number: Int
    let label: String
    let isActive: Bool
    let isCompleted: Bool

    var body: some View {
        HStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(backgroundColor)
                    .frame(width: 20, height: 20)

                if isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                } else {
                    Text("\(number)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(foregroundColor)
                }
            }

            Text(label)
                .font(.caption)
                .fontWeight(isActive || isCompleted ? .semibold : .regular)
                .foregroundColor(isActive || isCompleted ? .primary : .secondary)
        }
    }

    private var backgroundColor: Color {
        if isCompleted {
            return .green
        } else if isActive {
            return .accentColor
        } else {
            return Color.secondary.opacity(0.2)
        }
    }

    private var foregroundColor: Color {
        isActive ? .white : .secondary
    }
}

struct StepConnector: View {
    let isCompleted: Bool

    var body: some View {
        Rectangle()
            .fill(isCompleted ? Color.green : Color.secondary.opacity(0.3))
            .frame(width: 20, height: 2)
    }
}

// MARK: - Step 1: Scanning
struct ScanningStepView: View {
    @ObservedObject var deviceManager: DeviceManager

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            VStack(spacing: 16) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(1.5)

                Text("Scanning for Wiz devices...")
                    .font(.headline)

                Text("This may take a few seconds")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding()
    }
}

// MARK: - Scanning Completed View
struct ScanningCompletedView: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.green)

                Text("Scanning Completed")
                    .font(.headline)

                Text("Processing results...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding()
    }
}

// MARK: - No Devices Found View
struct NoDevicesFoundView: View {
    let onRescan: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "magnifyingglass.circle")
                    .font(.system(size: 60))
                    .foregroundColor(.gray)

                Text("No New Devices Found")
                    .font(.headline)

                Text(
                    "Make sure your Wiz devices are powered on and connected to the same Wi-Fi network"
                )
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 350)
            }

            Spacer()

            HStack {
                Spacer()

                Button("Rescan") {
                    onRescan()
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal)
            .padding(.bottom, 16)
        }
        .padding()
    }
}

// MARK: - Step 2: Select Device
struct SelectDeviceStepView: View {
    let devices: [WizDevice]
    let onSelect: (WizDevice) -> Void
    let onRescan: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Select a device to add (\(devices.count) found)")
                .font(.headline)
                .padding(.horizontal)

            if devices.isEmpty {
                VStack(spacing: 16) {
                    Spacer()

                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 50))
                        .foregroundColor(.green)

                    Text("All devices have been added")
                        .font(.headline)

                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(devices) { device in
                            DeviceSelectionRow(
                                device: device,
                                onSelect: {
                                    onSelect(device)
                                })
                        }
                    }
                    .padding(.horizontal)
                }
            }

            Spacer()

            HStack {
                Spacer()

                Button("Rescan") {
                    onRescan()
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal)
            .padding(.bottom, 16)
        }
        .padding(.top)
    }
}

struct DeviceSelectionRow: View {
    let device: WizDevice
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {
                // Device icon (white color)
                Image(systemName: device.type.icon)
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.accentColor.opacity(0.8))
                    )

                // Device info
                VStack(alignment: .leading, spacing: 4) {
                    Text(device.type.rawValue)
                        .font(.headline)

                    Text(device.ipAddress)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.subheadline)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Step 3: Device Details
struct DeviceDetailsStepView: View {
    let device: WizDevice
    @Binding var deviceName: String
    @Binding var selectedRoomID: UUID?
    let rooms: [Room]
    let onBack: () -> Void
    let onAdd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Selected device info
            HStack(spacing: 16) {
                Image(systemName: device.type.icon)
                    .font(.title)
                    .foregroundColor(.white)
                    .frame(width: 50, height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.accentColor.opacity(0.8))
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(device.type.rawValue)
                        .font(.headline)
                    Text(device.ipAddress)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
            )

            // Device name input
            VStack(alignment: .leading, spacing: 8) {
                Text("Device Name")
                    .font(.headline)

                TextField("e.g., Living Room Light", text: $deviceName)
                    .textFieldStyle(.roundedBorder)
                    .frame(height: 28)
            }

            // Room selection
            if !rooms.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Room (Optional)")
                        .font(.headline)

                    Picker("Select Room", selection: $selectedRoomID) {
                        Text("None")
                            .tag(nil as UUID?)
                        ForEach(rooms) { room in
                            HStack {
                                Image(systemName: room.icon)
                                Text(room.name)
                            }
                            .tag(room.id as UUID?)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
            }

            Spacer()

            // Action buttons
            HStack {
                Button("Back") {
                    onBack()
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("Add Device") {
                    if !deviceName.isEmpty {
                        onAdd()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(deviceName.isEmpty)
            }
            .padding(.bottom, 16)
        }
        .padding(.horizontal)
        .padding(.top)
    }
}

// MARK: - Permissions Onboarding View
struct PermissionsOnboardingView: View {
    @Binding var isPresented: Bool
    @AppStorage("permissionsChecked") private var permissionsChecked = false
    @State private var networkPermissionGranted = false
    @State private var localNetworkPermissionGranted = false

    var allPermissionsGranted: Bool {
        networkPermissionGranted && localNetworkPermissionGranted
    }

    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "shield.checkered")
                    .font(.system(size: 50))
                    .foregroundColor(.accentColor)

                Text("Permissions Required")
                    .font(.title)
                    .fontWeight(.bold)

                Text(
                    "Wiz needs the following permissions to discover and control your smart devices."
                )
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)
            }
            .padding(.top, 20)

            // Permissions List
            VStack(alignment: .leading, spacing: 16) {
                // Network Permission
                PermissionRow(
                    icon: "network",
                    title: "Network Access",
                    description: "Required to communicate with your devices over the local network",
                    isGranted: $networkPermissionGranted
                )

                // Local Network Permission
                PermissionRow(
                    icon: "wifi.router",
                    title: "Local Network",
                    description: "Required to discover and control WiZ devices on your network",
                    isGranted: $localNetworkPermissionGranted
                )
            }
            .padding(.horizontal, 30)

            Spacer()

            // Action Buttons
            VStack(spacing: 12) {
                Button(action: {
                    requestPermissions()
                }) {
                    HStack {
                        Image(systemName: "checkmark.shield")
                        Text(
                            allPermissionsGranted ? "All Permissions Granted" : "Grant Permissions")
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(allPermissionsGranted ? Color.green : Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
                .disabled(allPermissionsGranted)

                Button(action: {
                    permissionsChecked = true
                    isPresented = false
                }) {
                    Text("Continue")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            allPermissionsGranted ? Color.accentColor : Color.gray.opacity(0.3)
                        )
                        .foregroundColor(allPermissionsGranted ? .white : .secondary)
                        .cornerRadius(12)
                }
                .buttonStyle(.plain)
                .disabled(!allPermissionsGranted)
            }
            .padding(.horizontal, 30)
            .padding(.bottom, 30)
        }
        .frame(width: 500, height: 500)
        .onAppear {
            checkPermissions()
        }
    }

    private func checkPermissions() {
        // Check network permission by attempting a connection
        let task = URLSession.shared.dataTask(with: URL(string: "http://192.168.1.1")!) { _, _, _ in
            // Just checking if we can create a connection
            DispatchQueue.main.async {
                networkPermissionGranted = true
            }
        }
        task.resume()

        // Local network permission - assume granted for now (will be checked on first device discovery)
        localNetworkPermissionGranted = true
    }

    private func requestPermissions() {
        // Trigger network permission by making a test connection
        let task = URLSession.shared.dataTask(with: URL(string: "http://192.168.1.255:38899")!) {
            _, _, _ in
            DispatchQueue.main.async {
                networkPermissionGranted = true
                localNetworkPermissionGranted = true
            }
        }
        task.resume()
    }
}

// MARK: - Permission Row
struct PermissionRow: View {
    let icon: String
    let title: String
    let description: String
    @Binding var isGranted: Bool

    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(isGranted ? Color.green.opacity(0.2) : Color.gray.opacity(0.2))
                    .frame(width: 44, height: 44)

                Image(systemName: isGranted ? "checkmark" : icon)
                    .font(.title3)
                    .foregroundColor(isGranted ? .green : .gray)
            }

            // Text
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            // Status indicator
            Image(systemName: isGranted ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isGranted ? .green : .gray.opacity(0.3))
                .font(.title3)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
}

#Preview {
    ContentView()
}
