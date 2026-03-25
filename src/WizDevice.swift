import Foundation

enum DeviceType: String, Codable, CaseIterable {
    case smartBulb = "Smart Bulb"
    case smartPlug = "Smart Plug"
    case smartSwitch = "Smart Switch"
    case smartStrip = "Smart Strip"
    case unknown = "Unknown"
    
    var icon: String {
        switch self {
        case .smartBulb:
            return "lightbulb.fill"
        case .smartPlug:
            return "powerplug.fill"
        case .smartSwitch:
            return "switch.2"
        case .smartStrip:
            return "poweroutlet.strip.fill"
        case .unknown:
            return "questionmark.circle.fill"
        }
    }
}

struct WizDevice: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var ipAddress: String
    var type: DeviceType
    var isConnected: Bool
    var isSyncing: Bool
    var lastSeen: Date?
    var roomID: UUID?
    var brightness: Int // 0-100
    
    init(id: UUID = UUID(), name: String, ipAddress: String, type: DeviceType = .smartBulb, isConnected: Bool = false, isSyncing: Bool = false, lastSeen: Date? = nil, roomID: UUID? = nil, brightness: Int = 100) {
        self.id = id
        self.name = name
        self.ipAddress = ipAddress
        self.type = type
        self.isConnected = isConnected
        self.isSyncing = isSyncing
        self.lastSeen = lastSeen
        self.roomID = roomID
        self.brightness = brightness
    }
}
