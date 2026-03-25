import Foundation

struct Room: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var name: String
    var icon: String
    
    init(id: UUID = UUID(), name: String, icon: String = "house") {
        self.id = id
        self.name = name
        self.icon = icon
    }
}
