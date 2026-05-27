import Foundation

/// Endpoints under /tv, /movies, /person, /search (extras), /collections,
/// /box-office, /news. The TMDB-style passthrough endpoints return raw
/// `Data` so callers can decode whatever shape they need at the call site.
extension APIClient {

    // MARK: - /tv

    /// GET /tv/{id}
    func tvShow(id: Int, append: String? = nil) async throws -> Data {
        var query: [URLQueryItem] = []
        if let append { query.append(.init(name: "append", value: append)) }
        return try await getData("/tv/\(id)", query: query)
    }

    /// GET /tv/{id}/full (already typed via `showInfo`, raw variant for callers that
    /// need fields outside the typed model).
    func tvFullRaw(id: Int) async throws -> Data {
        try await getData("/tv/\(id)/full")
    }

    /// GET /tv/{id}/season_calendar
    func tvSeasonCalendar(id: Int, minDate: Date? = nil, maxDate: Date? = nil) async throws -> [EpisodeDTO] {
        let f = MediaItem.tmdbDateFormatter
        var query: [URLQueryItem] = []
        if let minDate { query.append(.init(name: "min_date", value: f.string(from: minDate))) }
        if let maxDate { query.append(.init(name: "max_date", value: f.string(from: maxDate))) }
        return try await get("/tv/\(id)/season_calendar", query: query)
    }

    /// GET /tv/{id}/full_calendar — returns list-of-lists (one per season).
    func tvFullCalendar(id: Int) async throws -> [[EpisodeDTO]] {
        try await get("/tv/\(id)/full_calendar")
    }

    /// GET /tv/{id}/episode_ratings
    func tvEpisodeRatings(id: Int) async throws -> Data {
        try await getData("/tv/\(id)/episode_ratings")
    }

    /// GET /tv/{id}/season/{season_number}/info
    func tvSeasonInfo(id: Int, seasonNumber: Int) async throws -> Data {
        try await getData("/tv/\(id)/season/\(seasonNumber)/info")
    }

    /// GET /tv/{id}/season/{season_number}/info — decoded helper.
    func tvSeasonInfoDecoded(id: Int, seasonNumber: Int) async throws -> SeasonDetails {
        try await get("/tv/\(id)/season/\(seasonNumber)/info")
    }

    // MARK: - /season-rating

    /// GET /season-rating?show_id=X&season_number=Y → current user's
    /// rating for the season, or `nil` when the user hasn't rated yet.
    /// The backend returns a JSON `null` in the unrated case.
    func mySeasonRating(showID: Int, seasonNumber: Int) async throws -> SeasonRating? {
        let data = try await getData("/season-rating", query: [
            .init(name: "show_id", value: "\(showID)"),
            .init(name: "season_number", value: "\(seasonNumber)")
        ])
        // Treat a `null` body or empty body as "not rated yet".
        if data.isEmpty { return nil }
        if let s = String(data: data, encoding: .utf8),
           s.trimmingCharacters(in: .whitespacesAndNewlines) == "null" {
            return nil
        }
        return try decoder.decode(SeasonRating.self, from: data)
    }

    /// GET /season-rating/aggregate → average rating + how many users
    /// have rated this season.
    func seasonRatingAggregate(showID: Int, seasonNumber: Int) async throws -> SeasonRatingAggregate {
        try await get("/season-rating/aggregate", query: [
            .init(name: "show_id", value: "\(showID)"),
            .init(name: "season_number", value: "\(seasonNumber)")
        ])
    }

    /// PUT /season-rating → upsert the current user's rating (1–5).
    @discardableResult
    func upsertSeasonRating(showID: Int, seasonNumber: Int, rating: Double) async throws -> SeasonRating {
        try await sendDecoded(
            "/season-rating",
            method: "PUT",
            body: SeasonRatingUpsertBody(
                show_id: showID,
                season_number: seasonNumber,
                rating: rating
            )
        )
    }

    /// DELETE /season-rating → clear the current user's rating.
    @discardableResult
    func deleteSeasonRating(showID: Int, seasonNumber: Int) async throws -> Data {
        try await send(
            "/season-rating",
            method: "DELETE",
            body: SeasonRatingDeleteBody(
                show_id: showID,
                season_number: seasonNumber
            )
        )
    }

    /// GET /tv/{id}/season/{season_number}/episode/{episode_number}
    func tvEpisodeInfo(id: Int, seasonNumber: Int, episodeNumber: Int) async throws -> Data {
        try await getData("/tv/\(id)/season/\(seasonNumber)/episode/\(episodeNumber)")
    }

    /// GET /tv/{id}/season/{season_number}/episode/{episode_number} — typed.
    func tvEpisodeInfoDecoded(
        id: Int,
        seasonNumber: Int,
        episodeNumber: Int
    ) async throws -> EpisodeDetails {
        try await get("/tv/\(id)/season/\(seasonNumber)/episode/\(episodeNumber)")
    }

    /// GET /tv/{id}/episode_ratings — full per-episode vote-average grid
    /// used by the editorial heat-map on the show info page.
    func tvEpisodeRatingsDecoded(showID: Int) async throws -> [SeasonRatings] {
        try await get("/tv/\(showID)/episode_ratings")
    }

    // MARK: - /movies

    /// GET /movies/{id}
    func movie(id: Int, append: String? = nil) async throws -> Data {
        var query: [URLQueryItem] = []
        if let append { query.append(.init(name: "append", value: append)) }
        return try await getData("/movies/\(id)", query: query)
    }

    /// GET /movies/{id}/info (already typed via `movieInfo`, raw variant when the
    /// typed model doesn't surface the fields a feature needs).
    func movieInfoRaw(id: Int) async throws -> Data {
        try await getData("/movies/\(id)/info")
    }

    // MARK: - /person

    /// GET /person/search
    func personSearch(query: String) async throws -> Data {
        try await getData("/person/search", query: [.init(name: "query", value: query)])
    }

    /// GET /person/{id}
    func person(id: Int) async throws -> Data {
        try await getData("/person/\(id)")
    }

    /// GET /person/{id}/info
    func personInfo(id: Int) async throws -> Data {
        try await getData("/person/\(id)/info")
    }

    /// GET /person/{id}/info — decoded helper.
    func personInfoDecoded(id: Int) async throws -> PersonDetails {
        try await get("/person/\(id)/info")
    }

    // MARK: - /search (additions to those already in APIClient.swift)

    /// GET /search — supports genre filtering and pagination.
    func searchAll(query: String? = nil, genreID: Int? = nil, type: String? = nil, page: Int = 1) async throws -> Data {
        var items: [URLQueryItem] = []
        if let query { items.append(.init(name: "query", value: query)) }
        if let genreID { items.append(.init(name: "genre_id", value: "\(genreID)")) }
        if let type { items.append(.init(name: "type", value: type)) }
        items.append(.init(name: "page", value: "\(page)"))
        return try await getData("/search", query: items)
    }

    /// GET /search/genres
    func searchGenres() async throws -> Data {
        try await getData("/search/genres")
    }

    /// GET /search/genres — decoded helper.
    func searchGenresDecoded() async throws -> GenreListResponse {
        try await get("/search/genres")
    }

    /// GET /search?genre_id=&type=&page= — decoded helper.
    func searchByGenre(type: ContentType, genreID: Int, page: Int = 1) async throws -> GenreSearchResponse {
        try await get("/search", query: [
            .init(name: "genre_id", value: "\(genreID)"),
            .init(name: "type", value: type == .tv ? "tv" : "movie"),
            .init(name: "page", value: "\(page)")
        ])
    }

    /// GET /news/ — decoded helper.
    func newsDecoded(category: NewsCategory = .entertainment, page: Int = 1, pageSize: Int = 20, q: String? = nil) async throws -> NewsResponse {
        var items: [URLQueryItem] = [
            .init(name: "category", value: category.rawValue),
            .init(name: "page", value: "\(page)"),
            .init(name: "page_size", value: "\(pageSize)")
        ]
        if let q { items.append(.init(name: "q", value: q)) }
        return try await get("/news/", query: items)
    }

    /// GET /collections/{id} — decoded helper.
    func collectionDecoded(id: Int) async throws -> TMDBCollection {
        try await get("/collections/\(id)")
    }

    // MARK: - /collections

    /// GET /collections/search
    func collectionsSearch(query: String, page: Int = 1) async throws -> Data {
        try await getData("/collections/search", query: [
            .init(name: "query", value: query),
            .init(name: "page", value: "\(page)")
        ])
    }

    /// GET /collections/{id}
    func collectionDetail(id: Int) async throws -> Data {
        try await getData("/collections/\(id)")
    }

    /// GET /collections/mine — buckets the user's collections into
    /// favorites / in-progress / finished. Drives the My Collections page.
    func collectionsMine() async throws -> MyCollectionsResponse {
        try await get("/collections/mine")
    }

    /// GET /collections/browse — paginated browse with optional facet filters.
    /// All parameters are optional; omit them for the popularity-sorted feed.
    func collectionsBrowse(
        minSize: Int? = nil,
        maxSize: Int? = nil,
        minRating: Double? = nil,
        yearFrom: Int? = nil,
        yearTo: Int? = nil,
        genreId: Int? = nil,
        sort: String = "popularity",
        direction: String = "desc",
        page: Int = 1,
        pageSize: Int = 30
    ) async throws -> CollectionBrowseResponse {
        var query: [URLQueryItem] = [
            .init(name: "sort", value: sort),
            .init(name: "direction", value: direction),
            .init(name: "page", value: "\(page)"),
            .init(name: "page_size", value: "\(pageSize)")
        ]
        if let minSize { query.append(.init(name: "min_size", value: "\(minSize)")) }
        if let maxSize { query.append(.init(name: "max_size", value: "\(maxSize)")) }
        if let minRating { query.append(.init(name: "min_rating", value: "\(minRating)")) }
        if let yearFrom { query.append(.init(name: "year_from", value: "\(yearFrom)")) }
        if let yearTo { query.append(.init(name: "year_to", value: "\(yearTo)")) }
        if let genreId { query.append(.init(name: "genre_id", value: "\(genreId)")) }
        return try await get("/collections/browse", query: query)
    }

    /// GET /collections/genres — facet input for the browse filter sheet.
    func collectionsGenres() async throws -> CollectionGenresResponse {
        try await get("/collections/genres")
    }

    /// GET /collections/{id}/status — per-user watch progress.
    func collectionsStatus(id: Int) async throws -> CollectionStatus {
        try await get("/collections/\(id)/status")
    }

    /// GET /collections/{id}/stats — TMDb aggregates across the films.
    func collectionsStats(id: Int) async throws -> CollectionStats {
        try await get("/collections/\(id)/stats")
    }

    /// GET /collections/{id}/ranking — the user's watched-films ranking.
    func collectionsRanking(id: Int) async throws -> CollectionRankingResponse {
        try await get("/collections/\(id)/ranking")
    }

    /// PUT /collections/{id}/ranking — submit a new ranking order.
    @discardableResult
    func collectionsUpdateRanking(id: Int, orderedMovieIds: [Int]) async throws -> CollectionRankingResponse {
        try await sendDecoded(
            "/collections/\(id)/ranking",
            method: "PUT",
            body: CollectionRankingUpdateBody(ordered_movie_ids: orderedMovieIds)
        )
    }

    /// POST /collections/status/bulk — fetch user progress for many
    /// collections at once. Backend returns a string-keyed dict; we rekey it
    /// to `Int` so callers don't have to parse the keys themselves.
    func collectionsBulkStatus(ids: [Int]) async throws -> [Int: CollectionBulkStatus] {
        struct Body: Encodable { let collection_ids: [Int] }
        let raw: [String: CollectionBulkStatus] = try await sendDecoded(
            "/collections/status/bulk",
            method: "POST",
            body: Body(collection_ids: ids)
        )
        var result: [Int: CollectionBulkStatus] = [:]
        for (key, value) in raw {
            if let id = Int(key) { result[id] = value }
        }
        return result
    }

    // MARK: - /favorites for collections
    //
    // `ContentType` only models movie/tv, so the standard favoriteAdd helper
    // can't represent a collection favorite. These two methods send the raw
    // `content_type: "collection"` body the backend expects.

    private struct CollectionFavoriteBody: Encodable {
        let content_type: String
        let content_id: Int
    }

    @discardableResult
    func favoriteAddCollection(id: Int) async throws -> Data {
        try await send(
            "/favorites/add",
            method: "POST",
            body: CollectionFavoriteBody(content_type: "collection", content_id: id)
        )
    }

    @discardableResult
    func favoriteRemoveCollection(id: Int) async throws -> Data {
        try await send(
            "/favorites/remove",
            method: "DELETE",
            body: CollectionFavoriteBody(content_type: "collection", content_id: id)
        )
    }

    /// GET /favorites/status for a collection. Mirrors `favoriteStatus` but
    /// uses `content_type=collection`.
    func favoriteStatusCollection(id: Int) async throws -> FavoriteStatusResponse {
        try await get("/favorites/status", query: [
            .init(name: "content_type", value: "collection"),
            .init(name: "content_id", value: "\(id)")
        ])
    }

    // MARK: - /box-office

    /// GET /box-office/yearly
    func boxOfficeYearly(year: Int, limit: Int = 20) async throws -> [BoxOfficeEntry] {
        try await get("/box-office/yearly", query: [
            .init(name: "year", value: "\(year)"),
            .init(name: "limit", value: "\(limit)")
        ])
    }

    /// GET /box-office/monthly
    func boxOfficeMonthly(year: Int, month: Int, limit: Int = 20) async throws -> [BoxOfficeEntry] {
        try await get("/box-office/monthly", query: [
            .init(name: "year", value: "\(year)"),
            .init(name: "month", value: "\(month)"),
            .init(name: "limit", value: "\(limit)")
        ])
    }

    /// GET /box-office/all-time
    func boxOfficeAllTime(page: Int = 1, limit: Int = 20) async throws -> [BoxOfficeEntry] {
        try await get("/box-office/all-time", query: [
            .init(name: "page", value: "\(page)"),
            .init(name: "limit", value: "\(limit)")
        ])
    }

    // MARK: - /news

    /// GET /news/
    func news(category: NewsCategory = .entertainment, page: Int = 1, pageSize: Int = 20, q: String? = nil) async throws -> Data {
        var items: [URLQueryItem] = [
            .init(name: "category", value: category.rawValue),
            .init(name: "page", value: "\(page)"),
            .init(name: "page_size", value: "\(pageSize)")
        ]
        if let q { items.append(.init(name: "q", value: q)) }
        return try await getData("/news/", query: items)
    }
}
