import Foundation

/// Endpoints under /watchlist, /watched, /watched-episode, /currently-watching,
/// /favorites, /rewatch, /calendar (extras), /shelf, /watch-status.
extension APIClient {

    // MARK: - /watchlist

    /// POST /watchlist/add — adds an item with optional notify preference.
    @discardableResult
    func watchlistAdd(type: ContentType, id: Int, notify: Bool = true) async throws -> Data {
        try await send(
            "/watchlist/add",
            method: "POST",
            body: WatchlistAddBody(content_type: type.rawValue, content_id: id, notify: notify)
        )
    }

    /// DELETE /watchlist/remove
    @discardableResult
    func watchlistRemove(type: ContentType, id: Int) async throws -> Data {
        try await send(
            "/watchlist/remove",
            method: "DELETE",
            body: ContentRef(type: type, id: id)
        )
    }

    /// GET /watchlist — already exposed as `watchlist()` in APIClient.swift.

    /// POST /watchlist/reorder
    @discardableResult
    func watchlistReorder(type: ContentType, id: Int, beforeID: Int? = nil, afterID: Int? = nil) async throws -> Data {
        try await send(
            "/watchlist/reorder",
            method: "POST",
            body: WatchlistReorderBody(
                content_type: type.rawValue,
                content_id: id,
                before_id: beforeID,
                after_id: afterID
            )
        )
    }

    /// GET /watchlist/tv/calendar
    func watchlistTVCalendar(from: Date, to: Date) async throws -> Data {
        let f = MediaItem.tmdbDateFormatter
        return try await getData("/watchlist/tv/calendar", query: [
            .init(name: "from_date", value: f.string(from: from)),
            .init(name: "to_date", value: f.string(from: to))
        ])
    }

    /// GET /watchlist/tv
    func watchlistTV() async throws -> Data {
        try await getData("/watchlist/tv")
    }

    /// GET /watchlist/movie
    func watchlistMovies() async throws -> Data {
        try await getData("/watchlist/movie")
    }

    /// POST /watchlist/status/bulk — returns map of `"<content_type>:<content_id>" -> {status, rating}`.
    /// Backend expects the body to be a raw JSON array (not wrapped in `{items: [...]}`).
    func watchlistStatusBulk(_ items: [(ContentType, Int)]) async throws -> [String: WatchStatusEntry] {
        let refs = items.map { ContentRef(type: $0.0, id: $0.1) }
        return try await sendDecoded(
            "/watchlist/status/bulk",
            method: "POST",
            body: refs
        )
    }

    /// GET /watchlist/movie/{id}/status
    func watchlistMovieStatus(id: Int) async throws -> Data {
        try await getData("/watchlist/movie/\(id)/status")
    }

    /// GET /watchlist/tv/{id}/status
    func watchlistTVStatus(id: Int) async throws -> Data {
        try await getData("/watchlist/tv/\(id)/status")
    }

    /// GET /watchlist/{movie|tv}/{id}/status — typed single-item helper.
    /// One DB lookup instead of the three the bulk endpoint runs.
    func watchStatus(type: ContentType, id: Int) async throws -> WatchStatusEntry {
        try await get("/watchlist/\(type.rawValue)/\(id)/status")
    }

    /// GET /watchlist/notify-prefs
    func watchlistNotifyPrefs() async throws -> [NotifyPrefItem] {
        try await get("/watchlist/notify-prefs")
    }

    /// PATCH /watchlist/notify-all
    @discardableResult
    func watchlistUpdateNotifyAll(notify: Bool, contentType: ContentType? = nil) async throws -> Data {
        try await send(
            "/watchlist/notify-all",
            method: "PATCH",
            body: NotifyAllUpdate(notify: notify, content_type: contentType?.rawValue)
        )
    }

    /// PATCH /watchlist/notify
    @discardableResult
    func watchlistUpdateNotify(type: ContentType, id: Int, notify: Bool) async throws -> Data {
        try await send(
            "/watchlist/notify",
            method: "PATCH",
            body: NotifyPrefUpdate(content_type: type.rawValue, content_id: id, notify: notify)
        )
    }

    /// GET /watchlist/progress/{show_id} — binge plan; shape varies, returned raw.
    func watchlistProgress(showID: Int) async throws -> Data {
        try await getData("/watchlist/progress/\(showID)")
    }

    /// GET /watchlist/progress/{show_id} — typed.
    func watchlistProgressDecoded(showID: Int) async throws -> ShowProgress {
        let data = try await watchlistProgress(showID: showID)
        return try decoder.decode(ShowProgress.self, from: data)
    }

    /// POST /watchlist/progress-bulk
    func watchlistProgressBulk(showIDs: [Int]) async throws -> Data {
        try await send(
            "/watchlist/progress-bulk",
            method: "POST",
            body: ProgressBulkBody(show_ids: showIDs)
        )
    }

    /// POST /watchlist/progress-bulk — typed.
    /// Server returns a dictionary keyed by stringified show IDs; this
    /// helper converts the keys back into `Int` for ergonomic lookup.
    func watchlistProgressBulkDecoded(showIDs: [Int]) async throws -> [Int: ShowProgress] {
        guard !showIDs.isEmpty else { return [:] }
        let raw: [String: ShowProgress] = try await sendDecoded(
            "/watchlist/progress-bulk",
            method: "POST",
            body: ProgressBulkBody(show_ids: showIDs)
        )
        var result: [Int: ShowProgress] = [:]
        for (key, value) in raw {
            if let id = Int(key) { result[id] = value }
        }
        return result
    }

    /// POST /watchlist/progress/{show_id}/finish-by
    func watchlistSetFinishBy(showID: Int, targetDate: Date) async throws -> FinishByResponse {
        let f = MediaItem.tmdbDateFormatter
        return try await sendDecoded(
            "/watchlist/progress/\(showID)/finish-by",
            method: "POST",
            body: FinishByBody(target_date: f.string(from: targetDate))
        )
    }

    /// DELETE /watchlist/progress/{show_id}/finish-by
    func watchlistClearFinishBy(showID: Int) async throws -> FinishByResponse {
        try await sendDecoded("/watchlist/progress/\(showID)/finish-by", method: "DELETE")
    }

    // MARK: - /watched

    /// POST /watched/add
    @discardableResult
    func watchedAdd(type: ContentType, id: Int) async throws -> Data {
        try await send("/watched/add", method: "POST", body: ContentRef(type: type, id: id))
    }

    /// PATCH /watched/rate
    @discardableResult
    func watchedRate(type: ContentType, id: Int, rating: Double?) async throws -> Data {
        try await send(
            "/watched/rate",
            method: "PATCH",
            body: WatchedRateBody(content_type: type.rawValue, content_id: id, rating: rating)
        )
    }

    /// DELETE /watched/remove — already exposed via `removeFromWatched(_:)` in APIClient.swift.

    /// GET /watched — already exposed via `watched()` in APIClient.swift.

    /// GET /watched/tv
    func watchedTV() async throws -> Data {
        try await getData("/watched/tv")
    }

    /// GET /watched/movie
    func watchedMovies() async throws -> Data {
        try await getData("/watched/movie")
    }

    // MARK: - /watched-episode

    /// POST /watched-episode/add — query params, not body.
    @discardableResult
    func watchedEpisodeAdd(showID: Int, seasonNumber: Int, episodeNumber: Int) async throws -> Data {
        try await send("/watched-episode/add", method: "POST", query: [
            .init(name: "show_id", value: "\(showID)"),
            .init(name: "season_number", value: "\(seasonNumber)"),
            .init(name: "episode_number", value: "\(episodeNumber)")
        ])
    }

    /// DELETE /watched-episode/remove
    @discardableResult
    func watchedEpisodeRemove(showID: Int, seasonNumber: Int, episodeNumber: Int) async throws -> Data {
        try await send("/watched-episode/remove", method: "DELETE", query: [
            .init(name: "show_id", value: "\(showID)"),
            .init(name: "season_number", value: "\(seasonNumber)"),
            .init(name: "episode_number", value: "\(episodeNumber)")
        ])
    }

    /// GET /watched-episode
    func watchedEpisodes() async throws -> Data {
        try await getData("/watched-episode")
    }

    /// POST /watched-episode/season/add
    @discardableResult
    func watchedEpisodeAddSeason(showID: Int, seasonNumber: Int) async throws -> Data {
        try await send("/watched-episode/season/add", method: "POST", query: [
            .init(name: "show_id", value: "\(showID)"),
            .init(name: "season_number", value: "\(seasonNumber)")
        ])
    }

    /// DELETE /watched-episode/season/remove
    @discardableResult
    func watchedEpisodeRemoveSeason(showID: Int, seasonNumber: Int) async throws -> Data {
        try await send("/watched-episode/season/remove", method: "DELETE", query: [
            .init(name: "show_id", value: "\(showID)"),
            .init(name: "season_number", value: "\(seasonNumber)")
        ])
    }

    /// GET /watched-episode/next/bulk
    func watchedEpisodeNextBulk(showIDs: [Int]) async throws -> Data {
        try await getData("/watched-episode/next/bulk", query: [
            .init(name: "show_ids", value: showIDs.map(String.init).joined(separator: ","))
        ])
    }

    /// GET /watched-episode/next/bulk — decoded helper.
    /// Backend returns `{"<show_id>": {finished, season_number, …}}` keyed by
    /// stringified show id; this rewrites the keys to `Int`.
    func nextEpisodesBulk(showIDs: [Int]) async throws -> [Int: NextEpisode] {
        guard !showIDs.isEmpty else { return [:] }
        let raw: [String: NextEpisode] = try await get(
            "/watched-episode/next/bulk",
            query: [.init(name: "show_ids", value: showIDs.map(String.init).joined(separator: ","))]
        )
        var result: [Int: NextEpisode] = [:]
        for (key, value) in raw {
            if let id = Int(key) { result[id] = value }
        }
        return result
    }

    /// GET /watched-episode/{show_id}
    func watchedEpisodesForShow(showID: Int) async throws -> Data {
        try await getData("/watched-episode/\(showID)")
    }

    /// GET /watched-episode/{show_id} — decoded helper.
    func watchedEpisodesByShow(showID: Int) async throws -> [WatchedEpisode] {
        try await get("/watched-episode/\(showID)")
    }

    /// GET /watched-episode/{show_id}/next
    func watchedEpisodeNext(showID: Int) async throws -> Data {
        try await getData("/watched-episode/\(showID)/next")
    }

    /// PATCH /watched-episode/annotate — episode location via query, body carries rating/notes.
    @discardableResult
    func watchedEpisodeAnnotate(
        showID: Int,
        seasonNumber: Int,
        episodeNumber: Int,
        rating: Double? = nil,
        notes: String? = nil
    ) async throws -> Data {
        try await send(
            "/watched-episode/annotate",
            method: "PATCH",
            query: [
                .init(name: "show_id", value: "\(showID)"),
                .init(name: "season_number", value: "\(seasonNumber)"),
                .init(name: "episode_number", value: "\(episodeNumber)")
            ],
            body: EpisodeAnnotationBody(rating: rating, notes: notes)
        )
    }

    // MARK: - /currently-watching

    /// GET /currently-watching — typed accessor (`currentlyWatching()`) exists already; this returns raw.
    func currentlyWatchingRaw() async throws -> Data {
        try await getData("/currently-watching")
    }

    /// GET /currently-watching — decoded helper returning the full
    /// `{movies, shows}` payload as a typed `MultiResponse`.
    func currentlyWatchingItems() async throws -> MultiResponse {
        try await get("/currently-watching")
    }

    /// GET /currently-watching/tv
    func currentlyWatchingTV() async throws -> Data {
        try await getData("/currently-watching/tv")
    }

    /// GET /currently-watching/movie
    func currentlyWatchingMovies() async throws -> Data {
        try await getData("/currently-watching/movie")
    }

    /// POST /currently-watching/add
    @discardableResult
    func currentlyWatchingAdd(type: ContentType, id: Int) async throws -> Data {
        try await send(
            "/currently-watching/add",
            method: "POST",
            body: ContentRef(type: type, id: id)
        )
    }

    /// DELETE /currently-watching/remove
    @discardableResult
    func currentlyWatchingRemove(type: ContentType, id: Int) async throws -> Data {
        try await send(
            "/currently-watching/remove",
            method: "DELETE",
            body: ContentRef(type: type, id: id)
        )
    }

    // MARK: - /favorites

    /// GET /favorites
    func favorites() async throws -> Data {
        try await getData("/favorites")
    }

    /// GET /favorites/status
    func favoriteStatus(type: ContentType, id: Int) async throws -> FavoriteStatusResponse {
        try await get("/favorites/status", query: [
            .init(name: "content_type", value: type.rawValue),
            .init(name: "content_id", value: "\(id)")
        ])
    }

    /// POST /favorites/add
    @discardableResult
    func favoriteAdd(type: ContentType, id: Int) async throws -> Data {
        try await send("/favorites/add", method: "POST", body: ContentRef(type: type, id: id))
    }

    /// DELETE /favorites/remove
    @discardableResult
    func favoriteRemove(type: ContentType, id: Int) async throws -> Data {
        try await send("/favorites/remove", method: "DELETE", body: ContentRef(type: type, id: id))
    }

    // MARK: - /rewatch

    /// POST /rewatch/add
    @discardableResult
    func rewatchAdd(
        type: ContentType,
        id: Int,
        rating: Double? = nil,
        notes: String? = nil,
        wouldRewatch: Bool? = nil
    ) async throws -> Data {
        try await send(
            "/rewatch/add",
            method: "POST",
            body: RewatchAddBody(
                content_type: type.rawValue,
                content_id: id,
                rating: rating,
                notes: notes,
                would_rewatch: wouldRewatch
            )
        )
    }

    /// GET /rewatch/
    func rewatches(type: ContentType? = nil) async throws -> [RewatchEntry] {
        var query: [URLQueryItem] = []
        if let type { query.append(.init(name: "content_type", value: type.rawValue)) }
        return try await get("/rewatch/", query: query)
    }

    /// GET /rewatch/{content_type}/{content_id}
    func rewatches(type: ContentType, id: Int) async throws -> RewatchListResponse {
        try await get("/rewatch/\(type.rawValue)/\(id)")
    }

    /// PATCH /rewatch/{rewatch_id}
    @discardableResult
    func rewatchUpdate(
        rewatchID: Int,
        rating: Double? = nil,
        notes: String? = nil,
        wouldRewatch: Bool? = nil
    ) async throws -> Data {
        try await send(
            "/rewatch/\(rewatchID)",
            method: "PATCH",
            body: RewatchUpdateBody(rating: rating, notes: notes, would_rewatch: wouldRewatch)
        )
    }

    /// DELETE /rewatch/{rewatch_id}
    @discardableResult
    func rewatchDelete(rewatchID: Int) async throws -> Data {
        try await send("/rewatch/\(rewatchID)", method: "DELETE")
    }

    // MARK: - /calendar — already exposed via `calendar(from:to:)` in APIClient.swift.

    // MARK: - /shelf

    /// POST /shelf
    func shelfCreate(name: String, description: String? = nil) async throws -> ShelfEntry {
        try await sendDecoded(
            "/shelf",
            method: "POST",
            body: ShelfCreateBody(name: name, description: description)
        )
    }

    /// GET /shelf
    func shelves() async throws -> [ShelfEntry] {
        try await get("/shelf")
    }

    /// PATCH /shelf/{shelf_id}
    func shelfUpdate(shelfID: Int, name: String? = nil, description: String? = nil) async throws -> ShelfEntry {
        try await sendDecoded(
            "/shelf/\(shelfID)",
            method: "PATCH",
            body: ShelfUpdateBody(name: name, description: description)
        )
    }

    /// DELETE /shelf/{shelf_id}
    @discardableResult
    func shelfDelete(shelfID: Int) async throws -> Data {
        try await send("/shelf/\(shelfID)", method: "DELETE")
    }

    /// POST /shelf/{shelf_id}/items
    func shelfAddItem(shelfID: Int, type: ContentType, id: Int) async throws -> ShelfItemEntry {
        try await sendDecoded(
            "/shelf/\(shelfID)/items",
            method: "POST",
            body: ContentRef(type: type, id: id)
        )
    }

    /// DELETE /shelf/{shelf_id}/items/{content_type}/{content_id}
    @discardableResult
    func shelfRemoveItem(shelfID: Int, type: ContentType, id: Int) async throws -> Data {
        try await send("/shelf/\(shelfID)/items/\(type.rawValue)/\(id)", method: "DELETE")
    }

    /// GET /shelf/{shelf_id}/items
    func shelfItems(shelfID: Int) async throws -> Data {
        try await getData("/shelf/\(shelfID)/items")
    }

    /// GET /shelf/{shelf_id}/calendar
    func shelfCalendar(shelfID: Int, from: Date? = nil, to: Date? = nil) async throws -> Data {
        let f = MediaItem.tmdbDateFormatter
        var query: [URLQueryItem] = []
        if let from { query.append(.init(name: "from_date", value: f.string(from: from))) }
        if let to { query.append(.init(name: "to_date", value: f.string(from: to))) }
        return try await getData("/shelf/\(shelfID)/calendar", query: query)
    }

    /// PATCH /shelf/{shelf_id}/notify
    func shelfUpdateNotify(shelfID: Int, notify: Bool) async throws -> ShelfNotifyResponse {
        try await sendDecoded(
            "/shelf/\(shelfID)/notify",
            method: "PATCH",
            body: ShelfNotifyBody(notify: notify)
        )
    }

    /// GET /shelf/item-shelves
    /// NOTE: This route is declared *after* `/shelf/{shelf_id}` on the server, so
    /// it currently gets shadowed and is expected to return 422 until the backend
    /// re-orders the routes.
    func shelfItemShelves(type: ContentType, id: Int) async throws -> Data {
        try await getData("/shelf/item-shelves", query: [
            .init(name: "content_type", value: type.rawValue),
            .init(name: "content_id", value: "\(id)")
        ])
    }

    // MARK: - /watch-status

    /// POST /watch-status/set
    func setWatchStatus(
        type: ContentType,
        id: Int,
        target: String,
        current: String = "none",
        notify: Bool = true
    ) async throws -> WatchStatusResponse {
        try await sendDecoded(
            "/watch-status/set",
            method: "POST",
            body: WatchStatusBody(
                content_type: type.rawValue,
                content_id: id,
                target: target,
                current: current,
                notify: notify
            )
        )
    }
}
