import Foundation
import Observation

@Observable
@MainActor
final class DiscoverViewModel {
    enum ContentFilter: String, CaseIterable, Identifiable {
        case all, movie, tv
        var id: String { rawValue }
        var label: String {
            switch self {
            case .all: "All"
            case .movie: "Movies"
            case .tv: "TV"
            }
        }
    }

    // Row data
    var hero: MediaItem?
    var trending: [MediaItem] = []
    var upcoming: [MediaItem] = []
    var airingToday: [MediaItem] = []
    var nowPlaying: [MediaItem] = []
    var popular: [MediaItem] = []
    var topRated: [MediaItem] = []

    // Per-row loading flags
    var trendingLoading = true
    var upcomingLoading = true
    var airingTodayLoading = true
    var nowPlayingLoading = true
    var popularLoading = true
    var topRatedLoading = true

    // Per-row filters (only rows with mixed content)
    var trendingFilter: ContentFilter = .all
    var upcomingFilter: ContentFilter = .all
    var popularFilter: ContentFilter = .all
    var topRatedFilter: ContentFilter = .all

    // Search overlay (when user types in the search bar)
    var query: String = ""
    var searchResults = SearchAllResults.empty
    var searchTab: SearchTab = .all
    var isSearching = false
    var searchError: String?

    enum SearchTab: String, CaseIterable, Identifiable {
        case all, movies, tv, people, collections
        var id: String { rawValue }
        var label: String {
            switch self {
            case .all: "All"
            case .movies: "Movies"
            case .tv: "TV"
            case .people: "People"
            case .collections: "Collections"
            }
        }
    }

    private var searchTask: Task<Void, Never>?
    private var didLoad = false

    var isQueryActive: Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func searchTabCount(_ tab: SearchTab) -> Int {
        switch tab {
        case .all: searchResults.totalCount
        case .movies: searchResults.movies.count
        case .tv: searchResults.shows.count
        case .people: searchResults.people.count
        case .collections: searchResults.collections.count
        }
    }

    func filtered(_ items: [MediaItem], by filter: ContentFilter) -> [MediaItem] {
        switch filter {
        case .all: return items
        case .movie: return items.filter { $0.contentType == .movie }
        case .tv: return items.filter { $0.contentType == .tv }
        }
    }

    // MARK: - Load

    func loadIfNeeded(client: APIClient) async {
        guard !didLoad else { return }
        didLoad = true
        await load(client: client)
    }

    func load(client: APIClient) async {
        async let trendingTask: Void = loadTrending(client: client)
        async let upcomingTask: Void = loadUpcoming(client: client)
        async let airingTask: Void = loadAiringToday(client: client)
        async let playingTask: Void = loadNowPlaying(client: client)
        async let popularTask: Void = loadPopular(client: client)
        async let topRatedTask: Void = loadTopRated(client: client)
        _ = await (trendingTask, upcomingTask, airingTask, playingTask, popularTask, topRatedTask)
    }

    // Each row loader updates state only on success. If a refresh is
    // cancelled mid-flight or a transient error hits, we keep the rows the
    // user was already looking at instead of collapsing them to empty.

    private func loadTrending(client: APIClient) async {
        trendingLoading = true
        defer { trendingLoading = false }
        do {
            let response = try await client.multiTrending()
            trending = response.interleaved()
            hero = response.movies.first ?? response.shows.first
        } catch {
            // Keep previous data on failure / cancellation.
        }
    }

    private func loadUpcoming(client: APIClient) async {
        upcomingLoading = true
        defer { upcomingLoading = false }
        let now = Date()
        let cal = Calendar.current
        let to = cal.date(byAdding: .month, value: 1, to: now) ?? now
        async let movies = client.upcoming(type: .movie, from: now, to: to)
        async let shows = client.upcoming(type: .tv, from: now, to: to)
        let movieList = try? await movies
        let showList = try? await shows
        // Only commit if at least one half came back successfully.
        guard movieList != nil || showList != nil else { return }
        let combined = (movieList ?? []) + (showList ?? [])
        upcoming = combined.sorted { lhs, rhs in
            (lhs.releaseDate ?? .distantFuture) < (rhs.releaseDate ?? .distantFuture)
        }
    }

    private func loadAiringToday(client: APIClient) async {
        airingTodayLoading = true
        defer { airingTodayLoading = false }
        if let result = try? await client.airingToday() {
            airingToday = result
        }
    }

    private func loadNowPlaying(client: APIClient) async {
        nowPlayingLoading = true
        defer { nowPlayingLoading = false }
        if let result = try? await client.nowPlaying() {
            nowPlaying = result
        }
    }

    private func loadPopular(client: APIClient) async {
        popularLoading = true
        defer { popularLoading = false }
        do {
            popular = try await client.multiPopular().interleaved()
        } catch {
            // Keep previous data on failure / cancellation.
        }
    }

    private func loadTopRated(client: APIClient) async {
        topRatedLoading = true
        defer { topRatedLoading = false }
        do {
            topRated = try await client.multiTopRated().interleaved()
        } catch {
            // Keep previous data on failure / cancellation.
        }
    }

    // MARK: - Search

    func scheduleSearch(client: APIClient) {
        searchTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            searchResults = .empty
            searchError = nil
            return
        }
        searchTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await self?.performSearch(query: trimmed, client: client)
        }
    }

    private func performSearch(query: String, client: APIClient) async {
        isSearching = true
        defer { isSearching = false }
        do {
            searchResults = try await client.searchAll(query: query)
            searchError = nil
        } catch is CancellationError {
            return
        } catch {
            searchError = error.localizedDescription
        }
    }
}

extension SearchAllResults {
    static let empty = SearchAllResults(movies: [], shows: [], people: [], collections: [])

    init(movies: [MediaItem], shows: [MediaItem], people: [PersonItem], collections: [SearchedCollection]) {
        self.movies = movies
        self.shows = shows
        self.people = people
        self.collections = collections
    }
}
