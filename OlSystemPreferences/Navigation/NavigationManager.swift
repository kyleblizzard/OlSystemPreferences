import Foundation

class NavigationManager {
    private var backStack: [String] = []
    private var forwardStack: [String] = []
    private(set) var currentPaneIdentifier: String?

    var canGoBack: Bool { !backStack.isEmpty }
    var canGoForward: Bool { !forwardStack.isEmpty }

    func navigateTo(_ paneIdentifier: String) {
        if let current = currentPaneIdentifier {
            backStack.append(current)
        }
        forwardStack.removeAll()
        currentPaneIdentifier = paneIdentifier
    }

    func goBack() -> String? {
        guard let previous = backStack.popLast() else { return nil }
        if let current = currentPaneIdentifier {
            forwardStack.append(current)
        }
        currentPaneIdentifier = previous
        return previous
    }

    func goForward() -> String? {
        guard let next = forwardStack.popLast() else { return nil }
        if let current = currentPaneIdentifier {
            backStack.append(current)
        }
        currentPaneIdentifier = next
        return next
    }

    func showAll() {
        if let current = currentPaneIdentifier {
            backStack.append(current)
        }
        forwardStack.removeAll()
        currentPaneIdentifier = nil
    }
}
