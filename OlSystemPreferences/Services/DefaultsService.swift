import Foundation

/// Typed wrapper around UserDefaults and CFPreferences for reading/writing system preferences
class DefaultsService {

    static let shared = DefaultsService()

    // MARK: - Read

    func bool(forKey key: String, domain: String? = nil) -> Bool? {
        if let domain = domain {
            let value = CFPreferencesCopyValue(key as CFString, domain as CFString, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
            return value as? Bool
        }
        return UserDefaults.standard.object(forKey: key) as? Bool
    }

    func integer(forKey key: String, domain: String? = nil) -> Int? {
        if let domain = domain {
            let value = CFPreferencesCopyValue(key as CFString, domain as CFString, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
            return value as? Int
        }
        return UserDefaults.standard.object(forKey: key) as? Int
    }

    func float(forKey key: String, domain: String? = nil) -> Float? {
        if let domain = domain {
            let value = CFPreferencesCopyValue(key as CFString, domain as CFString, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
            return value as? Float
        }
        return UserDefaults.standard.object(forKey: key) as? Float
    }

    func double(forKey key: String, domain: String? = nil) -> Double? {
        if let domain = domain {
            let value = CFPreferencesCopyValue(key as CFString, domain as CFString, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
            return value as? Double
        }
        return UserDefaults.standard.object(forKey: key) as? Double
    }

    func string(forKey key: String, domain: String? = nil) -> String? {
        if let domain = domain {
            let value = CFPreferencesCopyValue(key as CFString, domain as CFString, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
            return value as? String
        }
        return UserDefaults.standard.string(forKey: key)
    }

    func any(forKey key: String, domain: String? = nil) -> Any? {
        if let domain = domain {
            return CFPreferencesCopyValue(key as CFString, domain as CFString, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        }
        return UserDefaults.standard.object(forKey: key)
    }

    // MARK: - Write

    func set(_ value: Any?, forKey key: String, domain: String? = nil) {
        if let domain = domain {
            CFPreferencesSetValue(
                key as CFString,
                value as CFPropertyList?,
                domain as CFString,
                kCFPreferencesCurrentUser,
                kCFPreferencesAnyHost
            )
            CFPreferencesSynchronize(domain as CFString, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        } else {
            UserDefaults.standard.set(value, forKey: key)
            UserDefaults.standard.synchronize()
        }
    }

    func setBool(_ value: Bool, forKey key: String, domain: String? = nil) {
        set(value as NSNumber, forKey: key, domain: domain)
    }

    func setInteger(_ value: Int, forKey key: String, domain: String? = nil) {
        set(value as NSNumber, forKey: key, domain: domain)
    }

    func setFloat(_ value: Float, forKey key: String, domain: String? = nil) {
        set(value as NSNumber, forKey: key, domain: domain)
    }

    func setDouble(_ value: Double, forKey key: String, domain: String? = nil) {
        set(value as NSNumber, forKey: key, domain: domain)
    }

    func setString(_ value: String, forKey key: String, domain: String? = nil) {
        set(value as NSString, forKey: key, domain: domain)
    }

    // MARK: - Shell-based operations (for domains that need it)

    @discardableResult
    func shellDefaults(write domain: String, key: String, type: String, value: String) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        process.arguments = ["write", domain, key, "-\(type)", value]
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    func restartProcess(named name: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        process.arguments = [name]
        try? process.run()
        process.waitUntilExit()
    }
}
