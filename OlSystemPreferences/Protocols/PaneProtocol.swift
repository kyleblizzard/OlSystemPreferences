import Cocoa

enum PaneCategory: String, CaseIterable {
    case personal = "Personal"
    case hardware = "Hardware"
    case internetWireless = "Internet & Wireless"
    case system = "System"
}

protocol PaneProtocol: AnyObject {
    var paneIdentifier: String { get }
    var paneTitle: String { get }
    var paneIcon: NSImage { get }
    var paneCategory: PaneCategory { get }
    var preferredPaneSize: NSSize { get }
    var searchKeywords: [String] { get }
    var viewController: NSViewController { get }

    func paneWillAppear()
    func paneWillDisappear()
    func reloadFromSystem()
}

extension PaneProtocol {
    func paneWillAppear() {}
    func paneWillDisappear() {}
}
