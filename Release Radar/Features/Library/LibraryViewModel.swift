import Foundation
import Observation

/// Drives the Library tab. Owns both Watchlist and Watched lists and the
/// segment + media-type filter the user picks.
@Observable
@MainActor
final class LibraryViewModel {
    enum Segment: String, CaseIterable, Identifiable {
        case watchlist, watched
        var id: String { rawValue }
        var title: String {
            switch self {
            case .watchlist: "Watchlist"
            case .watched: "Watched"
            }
        }
    }

    /// Tabs that sit under the Watchlist / Watched segment. Mirrors the
    /// web app's tab set: Watchlist gets Up next + Currently watching on
    /// top of the basic type filters; Watched is limited to type filters.
    enum LibraryFilter: String, CaseIterable, Identifiable {
        case upNext
        case currentlyWatching
        case all
        case shows
        case movies

        var id: String { rawValue }

        var title: String {
            switch self {
            case .upNext: "Up next"
            case .currentlyWatching: "Watching"
            case .all: "All"
            case .shows: "Shows"
            case .movies: "Movies"
            }
        }

        static func filters(for segment: Segment) -> [LibraryFilter] {
            switch segment {
            case .watchlist: return [.all, .shows, .movies, .upNext, .currentlyWatching]
            case .watched:   return [.all, .movies, .shows]
            }
        }
    }

    enum Sort: String, CaseIterable, Identifiable {
        /// Server-returned order. For watchlist this is most recently added.
        case `default`
        /// A → Z by title, case-insensitively.
        case alphabetical
        /// Highest TMDb rating first. Unrated items sort to the end.
        case rating
        /// Shortest remaining runtime first. Movies and shows without
        /// progress data are pushed to the end; caught-up shows sit just
        /// ahead of those.
        case timeLeft

        var id: String { rawValue }
        var title: String {
            switch self {
            case .default: "Default"
            case .alphabetical: "A → Z"
            case .rating: "Highest rated"
            case .timeLeft: "Time left"
            }
        }
    }

    var segment: Segment = .watchlist {
        didSet {
            // If switching segments leaves us on a filter that doesn't
            // belong to the new segment, snap back to All so the grid
            // isn't stuck on a hidden tab.
            let allowed = LibraryFilter.filters(for: segment)
            if !allowed.contains(filter) { filter = .all }
        }
    }
    var filter: LibraryFilter = .all
    var sort: Sort = .default
    /// Free-text query — filters the visible items by title. Empty string
    /// disables the filter.
    var searchQuery: String = ""

    var watchlist: [MediaItem] = []
    var watched: [MediaItem] = []
    /// Items the user has marked "Currently Watching". Tracked separately
    /// so the Watchlist segment can surface them under their own tab and
    /// fold any CW-only items (not also on the watchlist) into All.
    var currentlyWatchingMovies: [MediaItem] = []
    var currentlyWatchingShows: [MediaItem] = []
    var isLoading: Bool = false
    var errorMessage: String?

    /// Binge progress keyed by TV show ID. Populated for watchlist shows so
    /// each poster can render a small horizontal bar showing how far along
    /// the user is in that show.
    var progressByShowID: [Int: ShowProgress] = [:]

    private var didLoad = false

    /// Watchlist ∪ currently-watching (deduped by `(contentType, id)`).
    /// Used as the source for every Watchlist sub-tab.
    var combinedWatchlist: [MediaItem] {
        let watchlistKeys = Set(watchlist.map { Self.key(for: $0) })
        let cwOnly = (currentlyWatchingMovies + currentlyWatchingShows).filter {
            !watchlistKeys.contains(Self.key(for: $0))
        }
        return watchlist + cwOnly
    }

    /// Set of `(contentType, id)` keys currently flagged as "watching".
    /// Powers the Currently-watching tab and badges.
    var currentlyWatchingKeys: Set<String> {
        Set((currentlyWatchingMovies + currentlyWatchingShows).map { Self.key(for: $0) })
    }

    private static func key(for item: MediaItem) -> String {
        "\(item.contentType.rawValue):\(item.id)"
    }

    var items: [MediaItem] {
        let cwKeys = currentlyWatchingKeys
        let source: [MediaItem]
        switch segment {
        case .watchlist: source = combinedWatchlist
        case .watched:   source = watched
        }

        var filtered: [MediaItem]
        switch filter {
        case .upNext:
            filtered = source.filter { item in
                guard item.contentType == .tv,
                      let p = progressByShowID[item.id] else { return false }
                return p.watchedEpisodes > 0 && p.remainingEpisodes > 0
            }
        case .currentlyWatching:
            filtered = source.filter { cwKeys.contains(Self.key(for: $0)) }
        case .all:
            filtered = source
        case .movies:
            filtered = source.filter { $0.contentType == .movie }
        case .shows:
            filtered = source.filter { $0.contentType == .tv }
        }
        let q = searchQuery.trimmingCharacters(in: .whitespaces)
        if !q.isEmpty {
            filtered = filtered.filter {
                $0.title.localizedCaseInsensitiveContains(q)
            }
        }
        switch sort {
        case .default:
            return filtered
        case .alphabetical:
            return filtered.sorted {
                $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }
        case .rating:
            return filtered.sorted { ($0.voteAverage ?? 0) > ($1.voteAverage ?? 0) }
        case .timeLeft:
            return filtered.sorted { minutesLeft(for: $0) < minutesLeft(for: $1) }
        }
    }

    /// Count for a given filter under the current segment — drives the
    /// small number next to each tab label. Search query is intentionally
    /// ignored so the counts reflect what the user could see, not what
    /// they happen to be typing.
    func count(for filter: LibraryFilter) -> Int {
        let cwKeys = currentlyWatchingKeys
        let source: [MediaItem]
        switch segment {
        case .watchlist: source = combinedWatchlist
        case .watched:   source = watched
        }
        switch filter {
        case .upNext:
            return source.filter { item in
                guard item.contentType == .tv,
                      let p = progressByShowID[item.id] else { return false }
                return p.watchedEpisodes > 0 && p.remainingEpisodes > 0
            }.count
        case .currentlyWatching:
            return source.filter { cwKeys.contains(Self.key(for: $0)) }.count
        case .all:
            return source.count
        case .movies:
            return source.filter { $0.contentType == .movie }.count
        case .shows:
            return source.filter { $0.contentType == .tv }.count
        }
    }

    /// Sort key for the "Time left" ordering. Movies / unknown progress sit
    /// at the very end; caught-up shows sit just before them; shows with
    /// remaining runtime sort by ascending minutes.
    private func minutesLeft(for item: MediaItem) -> Int {
        guard item.contentType == .tv, let p = progressByShowID[item.id] else {
            return Int.max
        }
        if p.isCaughtUp { return Int.max - 1 }
        return p.remainingMinutes
    }

    var totalCount: Int {
        switch segment {
        case .watchlist: return combinedWatchlist.count
        case .watched:   return watched.count
        }
    }

    func loadIfNeeded(client: APIClient) async {
        guard !didLoad else { return }
        didLoad = true
        await load(client: client)
    }

    func load(client: APIClient) async {
        isLoading = true
        defer { isLoading = false }
        do {
            async let watchlistTask = client.watchlist()
            async let watchedTask = client.watched()
            async let cwTask = client.currentlyWatchingItems()
            let (w, v, cw) = try await (watchlistTask, watchedTask, cwTask)
            watchlist = w
            watched = v
            currentlyWatchingMovies = cw.movies.map { $0.withType(.movie) }
            currentlyWatchingShows = cw.shows.map { $0.withType(.tv) }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        await loadProgress(client: client)
    }

    /// Bulk-fetch binge progress for every TV show across watchlist + watched.
    /// Best-effort — failures are silently dropped since the progress bars
    /// on posters are an enhancement, not core functionality.
    private func loadProgress(client: APIClient) async {
        let showIDs = Set(
            (watchlist + watched + currentlyWatchingShows)
                .filter { $0.contentType == .tv }
                .map(\.id)
        )
        guard !showIDs.isEmpty else {
            progressByShowID = [:]
            return
        }
        if let map = try? await client.watchlistProgressBulkDecoded(showIDs: Array(showIDs)) {
            progressByShowID = map
        }
    }

    func remove(_ item: MediaItem, client: APIClient) async {
        switch segment {
        case .watchlist:
            let previous = watchlist
            watchlist.removeAll { $0.id == item.id && $0.contentType == item.contentType }
            do {
                try await client.removeFromWatchlist(item)
            } catch {
                watchlist = previous
                errorMessage = error.localizedDescription
            }
        case .watched:
            let previous = watched
            watched.removeAll { $0.id == item.id && $0.contentType == item.contentType }
            do {
                try await client.removeFromWatched(item)
            } catch {
                watched = previous
                errorMessage = error.localizedDescription
            }
        }
    }
}
