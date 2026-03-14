import Cocoa

enum SoundService {
    static var enabled: Bool { UserDefaults.standard.bool(forKey: "ClassicSoundsEnabled") }

    static func playStartup() { play("Glass") }
    static func playClick() { play("Tink") }
    static func playNavigate() { play("Pop") }
    static func playError() { play("Basso") }

    private static func play(_ name: String) {
        guard enabled else { return }
        NSSound(named: NSSound.Name(name))?.play()
    }
}
