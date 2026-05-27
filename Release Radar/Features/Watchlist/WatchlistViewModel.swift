import Foundation
import Observation

@Observable
@MainActor
final class WatchlistViewModel {
    var items: [MediaItem] = []
    var isLoading: Bool = false
    var errorMessage: String?

    private var didLoad = false

    func loadIfNeeded(client: APIClient) async {
        guard !didLoad else { return }
        didLoad = true
        await load(client: client)
    }

    func load(client: APIClient) async {
        isLoading = true
        defer { isLoading = false }
        do {
            items = try await client.watchlist()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func remove(_ item: MediaItem, client: APIClient) async {
        let previous = items
        items.removeAll { $0.id == item.id && $0.contentType == item.contentType }
        do {
            try await client.removeFromWatchlist(item)
        } catch {
            items = previous
            errorMessage = error.localizedDescription
        }
    }
}
