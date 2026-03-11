import Foundation

/// Service for reading and writing Dock preferences
class DockService {

    static let shared = DockService()
    private let domain = "com.apple.dock"
    private let defaults = DefaultsService.shared

    // MARK: - Properties

    var tileSize: Int {
        get { defaults.integer(forKey: "tilesize", domain: domain) ?? 48 }
        set {
            defaults.setInteger(newValue, forKey: "tilesize", domain: domain)
            applyChanges()
        }
    }

    var magnification: Bool {
        get { defaults.bool(forKey: "magnification", domain: domain) ?? false }
        set {
            defaults.setBool(newValue, forKey: "magnification", domain: domain)
            applyChanges()
        }
    }

    var largeSize: Int {
        get { defaults.integer(forKey: "largesize", domain: domain) ?? 64 }
        set {
            defaults.setInteger(newValue, forKey: "largesize", domain: domain)
            applyChanges()
        }
    }

    var orientation: String {
        get { defaults.string(forKey: "orientation", domain: domain) ?? "bottom" }
        set {
            defaults.setString(newValue, forKey: "orientation", domain: domain)
            applyChanges()
        }
    }

    var minimizeEffect: String {
        get { defaults.string(forKey: "mineffect", domain: domain) ?? "genie" }
        set {
            defaults.setString(newValue, forKey: "mineffect", domain: domain)
            applyChanges()
        }
    }

    var minimizeToApplication: Bool {
        get { defaults.bool(forKey: "minimize-to-application", domain: domain) ?? false }
        set {
            defaults.setBool(newValue, forKey: "minimize-to-application", domain: domain)
            applyChanges()
        }
    }

    var launchAnimation: Bool {
        get { defaults.bool(forKey: "launchanim", domain: domain) ?? true }
        set {
            defaults.setBool(newValue, forKey: "launchanim", domain: domain)
            applyChanges()
        }
    }

    var autohide: Bool {
        get { defaults.bool(forKey: "autohide", domain: domain) ?? false }
        set {
            defaults.setBool(newValue, forKey: "autohide", domain: domain)
            applyChanges()
        }
    }

    var showRecents: Bool {
        get { defaults.bool(forKey: "show-recents", domain: domain) ?? true }
        set {
            defaults.setBool(newValue, forKey: "show-recents", domain: domain)
            applyChanges()
        }
    }

    var showProcessIndicators: Bool {
        get { defaults.bool(forKey: "show-process-indicators", domain: domain) ?? true }
        set {
            defaults.setBool(newValue, forKey: "show-process-indicators", domain: domain)
            applyChanges()
        }
    }

    // MARK: - Apply

    private var applyWorkItem: DispatchWorkItem?

    /// Debounced Dock restart to avoid rapid restarts during slider changes
    func applyChanges() {
        applyWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            self?.restartDock()
        }
        applyWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: item)
    }

    func restartDock() {
        defaults.restartProcess(named: "Dock")
    }
}
