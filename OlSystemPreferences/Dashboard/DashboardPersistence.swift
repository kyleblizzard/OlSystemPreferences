import Foundation

struct DashboardArrangement: Codable {
    var widgets: [WidgetEntry]

    struct WidgetEntry: Codable {
        let type: String
        let instanceId: String
        var x: Double
        var y: Double
        var data: [String: String]?
    }
}

enum DashboardPersistence {
    private static let key = "DashboardArrangement"

    static func save(_ arrangement: DashboardArrangement) {
        if let data = try? JSONEncoder().encode(arrangement) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    static func load() -> DashboardArrangement? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(DashboardArrangement.self, from: data)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
