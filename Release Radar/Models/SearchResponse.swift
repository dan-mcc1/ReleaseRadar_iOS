import Foundation

/// Decodes the assortment of shapes the backend's search endpoints return.
/// Tries `results` array first, then a top-level array, then a paginated wrapper.
struct SearchResponse: Codable, Sendable {
    let results: [MediaItem]

    init(results: [MediaItem]) {
        self.results = results
    }

    init(from decoder: Decoder) throws {
        if let keyed = try? decoder.container(keyedBy: CodingKeys.self),
           let items = try? keyed.decode([MediaItem].self, forKey: .results) {
            results = items
            return
        }
        if let unkeyed = try? decoder.singleValueContainer(),
           let items = try? unkeyed.decode([MediaItem].self) {
            results = items
            return
        }
        results = []
    }

    enum CodingKeys: String, CodingKey {
        case results
    }
}

/// Paginated `{ results, total_pages }` shape — used by trending/upcoming/airing-today/now-playing.
struct TrendingResponse: Decodable, Sendable {
    let results: [MediaItem]
    let totalPages: Int

    enum CodingKeys: String, CodingKey {
        case results
        case totalPages = "total_pages"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        results = (try? c.decode([MediaItem].self, forKey: .results)) ?? []
        totalPages = (try? c.decode(Int.self, forKey: .totalPages)) ?? 1
    }
}

/// `{ movies, shows }` shape — used by /search/multi/{trending,popular,top-rated}.
/// The decoder forces the contentType on each item so downstream filtering is reliable.
struct MultiResponse: Decodable, Sendable {
    let movies: [MediaItem]
    let shows: [MediaItem]

    enum CodingKeys: String, CodingKey {
        case movies, shows
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let rawMovies = (try? c.decode([MediaItem].self, forKey: .movies)) ?? []
        let rawShows = (try? c.decode([MediaItem].self, forKey: .shows)) ?? []
        movies = rawMovies.map { $0.withType(.movie) }
        shows = rawShows.map { $0.withType(.tv) }
    }

    /// Interleaves movies and shows: M, S, M, S, ...
    func interleaved() -> [MediaItem] {
        var result: [MediaItem] = []
        let maxLen = max(movies.count, shows.count)
        for i in 0..<maxLen {
            if i < movies.count { result.append(movies[i]) }
            if i < shows.count { result.append(shows[i]) }
        }
        return result
    }
}
