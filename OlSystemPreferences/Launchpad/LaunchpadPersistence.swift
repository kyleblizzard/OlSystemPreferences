import Foundation

// MARK: - Launchpad Arrangement Model

struct LaunchpadArrangement: Codable {
    var entries: [Entry]

    enum Entry: Codable {
        case app(bundleIdentifier: String)
        case folder(name: String, appBundleIdentifiers: [String])
    }
}

// MARK: - Persistence

enum LaunchpadPersistence {
    private static let key = "LaunchpadArrangement"

    static func save(_ arrangement: LaunchpadArrangement) {
        guard let data = try? JSONEncoder().encode(arrangement) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    static func load() -> LaunchpadArrangement? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(LaunchpadArrangement.self, from: data)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
