import Foundation

/// Indexes pane titles and keywords for searchable preference grid
class SearchManager {

    struct SearchResult {
        let paneIdentifier: String
        let paneTitle: String
        let matchedKeyword: String?
        let relevance: Double
    }

    private var entries: [(identifier: String, title: String, keywords: [String])] = []

    func index(panes: [PaneProtocol]) {
        entries = panes.map { pane in
            (identifier: pane.paneIdentifier,
             title: pane.paneTitle,
             keywords: pane.searchKeywords)
        }
    }

    func search(query: String) -> [SearchResult] {
        guard !query.isEmpty else { return [] }
        let lowered = query.lowercased()

        var results: [SearchResult] = []
        for entry in entries {
            // Title match gets highest relevance
            if entry.title.lowercased().contains(lowered) {
                results.append(SearchResult(
                    paneIdentifier: entry.identifier,
                    paneTitle: entry.title,
                    matchedKeyword: nil,
                    relevance: 1.0
                ))
                continue
            }

            // Keyword match
            for keyword in entry.keywords {
                if keyword.lowercased().contains(lowered) {
                    results.append(SearchResult(
                        paneIdentifier: entry.identifier,
                        paneTitle: entry.title,
                        matchedKeyword: keyword,
                        relevance: 0.5
                    ))
                    break
                }
            }
        }

        return results.sorted { $0.relevance > $1.relevance }
    }
}
