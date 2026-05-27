import Foundation
import Observation

@Observable
@MainActor
final class CalendarViewModel {
    struct DaySection: Identifiable {
        let date: Date
        let entries: [CalendarEntry]
        var id: Date { date }
    }

    enum MediaTypeFilter: String, CaseIterable, Identifiable {
        case all, tv, movie
        var id: String { rawValue }
        var label: String {
            switch self {
            case .all: "All"
            case .tv: "TV"
            case .movie: "Movies"
            }
        }
    }

    enum WatchedFilter: String, CaseIterable, Identifiable {
        case all, watched, unwatched
        var id: String { rawValue }
        var label: String {
            switch self {
            case .all: "All"
            case .watched: "Watched"
            case .unwatched: "Unwatched"
            }
        }
    }

    var days: [DaySection] = []
    var isLoading: Bool = false
    var errorMessage: String?

    // Filter state
    var mediaTypeFilter: MediaTypeFilter = .all
    var watchedFilter: WatchedFilter = .all
    var currentlyWatchingOnly: Bool = false

    private var currentlyWatchingShowIDs: Set<Int> = []
    private var currentlyWatchingMovieIDs: Set<Int> = []

    /// Items shown in the "Continue watching" rail above the timeline.
    var currentlyWatchingItems: [MediaItem] = []

    /// For shows in `currentlyWatchingItems`, the next unwatched episode keyed
    /// by show id. Lets the rail render the episode still + SxxExx + name.
    var nextEpisodesByShow: [Int: NextEpisode] = [:]

    /// Entry IDs locally marked watched in this session — used so the row's
    /// checkmark updates immediately, without waiting for a calendar refetch.
    var locallyWatched: Set<String> = []
    /// Entries locally marked un-watched (toggled off) this session. Overrides
    /// the server-reported `entry.isWatched`.
    var locallyUnwatched: Set<String> = []

    /// Episodes-per-season counts keyed by `"<showID>-<season>"`. Populated
    /// lazily from `/tv/{id}/season/{n}/info` so the calendar can infer
    /// Season Finale tags even when the bulk payload has `episode_type` null.
    var episodeCountByShowSeason: [String: Int] = [:]

    /// Fresh `episode_type` straight from TMDb (via season info), keyed by
    /// `"<showID>-<season>-<episode>"`. Used to surface Mid-Season Finale
    /// tags which can't be inferred from numbers alone.
    var episodeTypeByEpisode: [String: String] = [:]

    /// `(showID, season)` pairs we've already attempted to enrich — avoids
    /// retrying on every re-render.
    private var enrichedSeasons: Set<ShowSeasonKey> = []

    struct ShowSeasonKey: Hashable {
        let showID: Int
        let season: Int
    }

    private var didLoad = false

    /// Initial load covers ±1 year from today — fast to fetch and
    /// quick to render. Additional years are loaded in 1-year chunks
    /// on demand when the user scrolls to either boundary.
    private static let initialMonthsBackward = 12
    private static let initialMonthsForward = 12
    /// Size of each subsequent on-scroll chunk.
    private static let chunkMonths = 12

    /// Inclusive boundaries of the currently-loaded date range. Used
    /// by the View to compute the next chunk's window when the user
    /// scrolls to either end of the timeline.
    private(set) var loadedFrom: Date?
    private(set) var loadedTo: Date?

    private var isFetchingBackward = false
    private var isFetchingForward = false
    /// Timestamp of the last successful backward chunk. Used to
    /// hard-stop cascade — after a fetch completes, the LazyVStack
    /// often pre-renders the new boundary day in its render buffer
    /// and fires its `.onAppear` instantly, which would otherwise
    /// trigger another backward fetch in an infinite loop.
    private var lastBackwardFetchAt: Date?
    private static let backwardCooldown: TimeInterval = 1.5

    var todayAnchorID: Date? {
        let startOfToday = Calendar.current.startOfDay(for: Date())
        return days.first { $0.date >= startOfToday }?.date
    }

    /// Number of upcoming entries (from today onward) in the current calendar month,
    /// after applying the active filters.
    var upcomingThisMonthCount: Int {
        let cal = Calendar.current
        let now = Date()
        let startOfToday = cal.startOfDay(for: now)
        return filteredDays
            .filter { cal.isDate($0.date, equalTo: now, toGranularity: .month) && $0.date >= startOfToday }
            .reduce(0) { $0 + $1.entries.count }
    }

    /// Total number of filtered releases in the calendar month containing
    /// `date`. Used by the header so the count tracks whatever month the
    /// user has tapped into via the week strip.
    func releaseCount(inMonthOf date: Date) -> Int {
        let cal = Calendar.current
        return filteredDays
            .filter { cal.isDate($0.date, equalTo: date, toGranularity: .month) }
            .reduce(0) { $0 + $1.entries.count }
    }

    /// Total episodes in a given season for a given show, if known.
    /// `nil` until `enrichEpisodeData(client:)` has populated the cache
    /// for that show.
    func episodeCount(showID: Int, season: Int) -> Int? {
        episodeCountByShowSeason["\(showID)-\(season)"]
    }

    /// TMDb episode_type for a specific episode, or `nil` if not enriched.
    func episodeType(showID: Int, season: Int, episode: Int) -> String? {
        episodeTypeByEpisode["\(showID)-\(season)-\(episode)"]
    }

    /// Fetches season info for every `(showID, season)` pair that has
    /// calendar entries and caches both the episode count (for inferring
    /// Season Finales) and the per-episode `episode_type` (for catching
    /// Mid-Season Finales — which can only come from TMDb). Each pair is
    /// fetched at most once; refresh requires a full calendar reload.
    func enrichEpisodeData(client: APIClient) async {
        let pairs = Set(days.flatMap { day in
            day.entries.compactMap { entry -> ShowSeasonKey? in
                if case .episode(let showId, _, let season, _) = entry.kind {
                    return ShowSeasonKey(showID: showId, season: season)
                }
                return nil
            }
        })
        let needed = pairs.subtracting(enrichedSeasons)
        guard !needed.isEmpty else { return }

        await withTaskGroup(of: (ShowSeasonKey, SeasonDetails?).self) { group in
            for key in needed {
                group.addTask {
                    let details = try? await client.tvSeasonInfoDecoded(
                        id: key.showID,
                        seasonNumber: key.season
                    )
                    return (key, details)
                }
            }
            for await (key, detailsOpt) in group {
                enrichedSeasons.insert(key)
                guard let details = detailsOpt else { continue }
                episodeCountByShowSeason["\(key.showID)-\(key.season)"] = details.episodes.count
                for ep in details.episodes {
                    if let num = ep.episodeNumber, let type = ep.episodeType, !type.isEmpty {
                        episodeTypeByEpisode["\(key.showID)-\(key.season)-\(num)"] = type
                    }
                }
            }
        }
    }

    func clearFilters() {
        mediaTypeFilter = .all
        watchedFilter = .all
        currentlyWatchingOnly = false
    }

    /// Same sections as `days`, but entries within each day are filtered.
    /// Section count and IDs are stable across filter changes — that keeps the
    /// scroll position unchanged when filters are toggled.
    var filteredDays: [DaySection] {
        days.map { DaySection(date: $0.date, entries: $0.entries.filter(matches)) }
    }

    var anyFilterActive: Bool {
        mediaTypeFilter != .all || watchedFilter != .all || currentlyWatchingOnly
    }

    // MARK: - Filtering

    private func matches(_ entry: CalendarEntry) -> Bool {
        switch mediaTypeFilter {
        case .all: break
        case .tv: if entry.contentType != .tv { return false }
        case .movie: if entry.contentType != .movie { return false }
        }
        switch watchedFilter {
        case .all: break
        case .watched: if !entry.isWatched { return false }
        case .unwatched: if entry.isWatched { return false }
        }
        if currentlyWatchingOnly {
            switch entry.kind {
            case .movie(let id):
                if !currentlyWatchingMovieIDs.contains(id) { return false }
            case .episode(let showId, _, _, _):
                if !currentlyWatchingShowIDs.contains(showId) { return false }
            }
        }
        return true
    }

    // MARK: - Initial / refresh

    func loadIfNeeded(client: APIClient) async {
        guard !didLoad else { return }
        didLoad = true
        async let calendarTask: Void = load(client: client)
        async let currentlyWatchingTask: Void = loadCurrentlyWatching(client: client)
        _ = await (calendarTask, currentlyWatchingTask)
    }

    func load(client: APIClient) async {
        isLoading = true
        defer { isLoading = false }

        // Initial ±20-year window. Wide enough to cover most users'
        // legacy library + a generous future horizon in one shot;
        // additional history / future is loaded in 20-year chunks on
        // demand when the user scrolls to either boundary.
        let cal = Calendar.current
        let now = Date()
        guard
            let rawFrom = cal.date(byAdding: .month, value: -Self.initialMonthsBackward, to: now),
            let rawTo = cal.date(byAdding: .month, value: Self.initialMonthsForward, to: now)
        else { return }

        let from = cal.startOfDay(for: rawFrom)
        let to = cal.startOfDay(for: rawTo)

        do {
            let sections = try await fetchSections(client: client, from: from, to: to)
            days = sections
            loadedFrom = from
            loadedTo = to
            errorMessage = nil
            await enrichEpisodeData(client: client)
        } catch where Self.isCancellation(error) {
            // A second pull-to-refresh cancelled the first one. Leave
            // existing days in place and stay silent — the new task
            // that replaced us is already running.
        } catch {
            // Hard failure: surface the message but keep existing
            // days visible.
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - On-scroll chunking

    struct BackwardChunk {
        let sections: [DaySection]
        let newLoadedFrom: Date
    }

    struct ForwardChunk {
        let sections: [DaySection]
        let newLoadedTo: Date
    }

    /// Fetch the next 20-year backward block. Returns `nil` if a fetch
    /// is already in flight or the range computation fails. The caller
    /// (View) is responsible for committing the apply + scroll restore
    /// in a single SwiftUI transaction so the LazyVStack never paints
    /// the intermediate shifted state.
    func fetchBackwardChunk(client: APIClient) async -> BackwardChunk? {
        guard !isFetchingBackward, let currentFrom = loadedFrom else { return nil }
        if let last = lastBackwardFetchAt,
           Date().timeIntervalSince(last) < Self.backwardCooldown {
            return nil
        }
        isFetchingBackward = true
        defer {
            isFetchingBackward = false
            lastBackwardFetchAt = Date()
        }

        let cal = Calendar.current
        guard
            let newTo = cal.date(byAdding: .day, value: -1, to: currentFrom),
            let rawNewFrom = cal.date(byAdding: .month, value: -Self.chunkMonths, to: newTo)
        else { return nil }

        let to = cal.startOfDay(for: newTo)
        let from = cal.startOfDay(for: rawNewFrom)

        do {
            let sections = try await fetchSections(client: client, from: from, to: to)
            return BackwardChunk(sections: sections, newLoadedFrom: from)
        } catch where Self.isCancellation(error) {
            return nil
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    /// Commit a backward chunk. Dedupes by date so an overlapping
    /// fetch can't leave duplicate sections in the list.
    func applyBackwardChunk(_ chunk: BackwardChunk) {
        let existing = Set(days.map(\.date))
        let filtered = chunk.sections.filter { !existing.contains($0.date) }
        days = filtered + days
        loadedFrom = chunk.newLoadedFrom
        errorMessage = nil
    }

    func fetchForwardChunk(client: APIClient) async -> ForwardChunk? {
        guard !isFetchingForward, let currentTo = loadedTo else { return nil }
        isFetchingForward = true
        defer { isFetchingForward = false }

        let cal = Calendar.current
        guard
            let newFrom = cal.date(byAdding: .day, value: 1, to: currentTo),
            let rawNewTo = cal.date(byAdding: .month, value: Self.chunkMonths, to: newFrom)
        else { return nil }

        let from = cal.startOfDay(for: newFrom)
        let to = cal.startOfDay(for: rawNewTo)

        do {
            let sections = try await fetchSections(client: client, from: from, to: to)
            return ForwardChunk(sections: sections, newLoadedTo: to)
        } catch where Self.isCancellation(error) {
            return nil
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func applyForwardChunk(_ chunk: ForwardChunk) {
        let existing = Set(days.map(\.date))
        let filtered = chunk.sections.filter { !existing.contains($0.date) }
        days = days + filtered
        loadedTo = chunk.newLoadedTo
        errorMessage = nil
    }

    /// Re-fetch the Continue Watching rail data. Cheap to call — used by the
    /// CalendarView's `.onAppear` so the rail updates after mark-watched
    /// actions taken on other screens (show info, movie info, etc.).
    func refreshCurrentlyWatching(client: APIClient) async {
        await loadCurrentlyWatching(client: client)
    }

    private func loadCurrentlyWatching(client: APIClient) async {
        // Typed helper instead of raw JSON decode — uses the API client's
        // configured decoder so date strategies and any future tweaks stay
        // consistent across endpoints.
        let response: MultiResponse? = try? await client.currentlyWatchingItems()
        let movies = response?.movies ?? []
        let shows = response?.shows ?? []
        currentlyWatchingShowIDs = Set(shows.map(\.id))
        currentlyWatchingMovieIDs = Set(movies.map(\.id))

        let explicit = shows + movies
        if !explicit.isEmpty {
            currentlyWatchingItems = explicit
            await loadNextEpisodes(for: shows, client: client)
            return
        }

        // Fallback: if the user hasn't explicitly flagged anything as
        // "Currently Watching", surface their TV watchlist so the rail is
        // still useful — these are the shows they're actively tracking.
        do {
            let watchlist = try await client.watchlist()
            let watchlistShows = watchlist.filter { $0.contentType == .tv }
            currentlyWatchingItems = watchlistShows
            await loadNextEpisodes(for: watchlistShows, client: client)
        } catch {
            currentlyWatchingItems = []
        }
    }

    private func loadNextEpisodes(for shows: [MediaItem], client: APIClient) async {
        let ids = shows.filter { $0.contentType == .tv }.map(\.id)
        guard !ids.isEmpty else {
            nextEpisodesByShow = [:]
            return
        }
        nextEpisodesByShow = (try? await client.nextEpisodesBulk(showIDs: ids)) ?? [:]
    }

    /// Mark the show's next unwatched episode as watched, then refresh the
    /// next-episode mapping so the rail advances to the following episode.
    func markNextEpisodeWatched(showID: Int, client: APIClient) async {
        guard let next = nextEpisodesByShow[showID],
              let season = next.seasonNumber,
              let number = next.episodeNumber else { return }
        do {
            _ = try await client.watchedEpisodeAdd(
                showID: showID,
                seasonNumber: season,
                episodeNumber: number
            )
            // Re-fetch the next-episode mapping so the rail advances.
            let updated = (try? await client.nextEpisodesBulk(showIDs: [showID])) ?? [:]
            nextEpisodesByShow[showID] = updated[showID]
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Mark a movie from the Continue Watching rail as watched. Uses
    /// `/watch-status/set` so the movie also gets removed from the watchlist.
    func markCurrentlyWatchingMovieWatched(movieID: Int, client: APIClient) async {
        do {
            let current = (try? await client.watchStatus(type: .movie, id: movieID))?.status ?? "none"
            _ = try await client.setWatchStatus(
                type: .movie,
                id: movieID,
                target: WatchStatus.watched.rawValue,
                current: current
            )
            // Drop the movie from the rail since it's now watched.
            currentlyWatchingItems.removeAll { $0.contentType == .movie && $0.id == movieID }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Mark watched

    func isWatched(_ entry: CalendarEntry) -> Bool {
        if locallyUnwatched.contains(entry.id) { return false }
        return entry.isWatched || locallyWatched.contains(entry.id)
    }

    /// Toggle a calendar entry's watched state. Movies hit `/watched/add` or
    /// `/watched/remove`; episodes hit the matching `/watched-episode/*`
    /// endpoint with show + season + episode number.
    func toggleWatched(_ entry: CalendarEntry, client: APIClient) async {
        if isWatched(entry) {
            await unmarkWatched(entry, client: client)
        } else {
            await markWatched(entry, client: client)
        }
    }

    func markWatched(_ entry: CalendarEntry, client: APIClient) async {
        // Optimistic — flip immediately, roll back on failure.
        locallyUnwatched.remove(entry.id)
        locallyWatched.insert(entry.id)
        do {
            switch entry.kind {
            case .movie(let id):
                // Use /watch-status/set so the movie is removed from the
                // watchlist / currently-watching list as part of the
                // transition — `/watched/add` alone leaves it in both lists
                // and the status endpoint then prioritizes "Want To Watch".
                let current = (try? await client.watchStatus(type: .movie, id: id))?.status ?? "none"
                _ = try await client.setWatchStatus(
                    type: .movie,
                    id: id,
                    target: WatchStatus.watched.rawValue,
                    current: current
                )
            case .episode(let showId, _, let season, let number):
                _ = try await client.watchedEpisodeAdd(
                    showID: showId,
                    seasonNumber: season,
                    episodeNumber: number
                )
            }
        } catch {
            locallyWatched.remove(entry.id)
            errorMessage = error.localizedDescription
        }
    }

    func unmarkWatched(_ entry: CalendarEntry, client: APIClient) async {
        locallyWatched.remove(entry.id)
        locallyUnwatched.insert(entry.id)
        do {
            switch entry.kind {
            case .movie(let id):
                // The user is "un-watching" something that's on their calendar
                // (i.e. something they care about). Put it back on the
                // watchlist rather than removing it entirely — calendar items
                // exist because they were tracked in the first place.
                let current = (try? await client.watchStatus(type: .movie, id: id))?.status ?? WatchStatus.watched.rawValue
                _ = try await client.setWatchStatus(
                    type: .movie,
                    id: id,
                    target: WatchStatus.wantToWatch.rawValue,
                    current: current
                )
            case .episode(let showId, _, let season, let number):
                _ = try await client.watchedEpisodeRemove(
                    showID: showId,
                    seasonNumber: season,
                    episodeNumber: number
                )
            }
        } catch {
            // Roll back: restore previous watched state.
            locallyUnwatched.remove(entry.id)
            if !entry.isWatched {
                locallyWatched.insert(entry.id)
            }
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Network

    private func fetchSections(client: APIClient, from: Date, to: Date) async throws -> [DaySection] {
        // Throws on any underlying failure (including cancellation) so the
        // caller can distinguish "fetch failed" from "fetch returned no
        // entries" and avoid clobbering `days` with an empty array on a
        // cancelled refresh.
        let response = try await client.calendar(from: from, to: to)
        let entries = response.timelineEntries()
            .filter { $0.date >= from && $0.date <= to }
        let buckets = Dictionary(grouping: entries) { Calendar.current.startOfDay(for: $0.date) }

        var sections: [DaySection] = []
        var current = from
        while current <= to {
            let dayEntries = (buckets[current] ?? []).sorted { $0.title < $1.title }
            sections.append(DaySection(date: current, entries: dayEntries))
            guard let next = Calendar.current.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
        }
        return sections
    }

    /// Treat both Swift's structured-concurrency cancellation and
    /// URLSession's network-level cancellation as the same thing — a
    /// new request superseded this one, so we should swallow the error
    /// instead of surfacing it to the user.
    private static func isCancellation(_ error: Error) -> Bool {
        if error is CancellationError { return true }
        if let urlError = error as? URLError, urlError.code == .cancelled { return true }
        return false
    }
}
