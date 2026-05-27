import Foundation

/// Decodes the response from `/movies/{id}/info` — a TMDB movie payload with
/// `append_to_response` for credits, videos, recommendations, external_ids,
/// watch/providers, and release_dates.
struct MovieDetails: Decodable, Identifiable, Sendable {
    let id: Int
    let title: String
    let overview: String?
    let posterPath: String?
    let backdropPath: String?
    let logoPath: String?
    let releaseDate: Date?
    let voteAverage: Double?
    let voteCount: Int?
    let runtime: Int?
    let status: String?
    let budget: Int64?
    let revenue: Int64?
    let homepage: String?
    let genres: [MediaGenre]
    let cast: [CastMember]
    let videos: [MediaVideo]
    let recommendations: [MediaItem]
    let externalIDs: MediaExternalIDs?
    let watchProviders: WatchProvidersUS?
    let certification: String?

    var posterURL: URL? {
        posterPath.flatMap { URL(string: "https://image.tmdb.org/t/p/w342\($0)") }
    }
    var backdropURL: URL? {
        backdropPath.flatMap { URL(string: "https://image.tmdb.org/t/p/w1280\($0)") }
    }
    var logoURL: URL? {
        logoPath.flatMap { URL(string: "https://image.tmdb.org/t/p/w500\($0)") }
    }

    /// Lightweight `MediaItem` for action buttons (watchlist add/remove).
    var asMediaItem: MediaItem {
        MediaItem(
            id: id,
            contentType: .movie,
            title: title,
            overview: overview,
            posterPath: posterPath,
            backdropPath: backdropPath,
            releaseDate: releaseDate,
            voteAverage: voteAverage
        )
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        title = (try? c.decode(String.self, forKey: .title)) ?? ""
        overview = try? c.decode(String.self, forKey: .overview)
        posterPath = try? c.decode(String.self, forKey: .posterPath)
        backdropPath = try? c.decode(String.self, forKey: .backdropPath)
        logoPath = try? c.decode(String.self, forKey: .logoPath)
        voteAverage = try? c.decode(Double.self, forKey: .voteAverage)
        voteCount = try? c.decode(Int.self, forKey: .voteCount)
        runtime = try? c.decode(Int.self, forKey: .runtime)
        status = try? c.decode(String.self, forKey: .status)
        budget = try? c.decode(Int64.self, forKey: .budget)
        revenue = try? c.decode(Int64.self, forKey: .revenue)
        homepage = try? c.decode(String.self, forKey: .homepage)
        genres = (try? c.decode([MediaGenre].self, forKey: .genres)) ?? []

        if let s = try? c.decode(String.self, forKey: .releaseDate), !s.isEmpty {
            releaseDate = MediaItem.tmdbDateFormatter.date(from: s)
        } else {
            releaseDate = nil
        }

        cast = (try? c.decode(CreditsBag.self, forKey: .credits))?.cast ?? []
        videos = (try? c.decode(ResultsBag<MediaVideo>.self, forKey: .videos))?.results ?? []

        let recs = (try? c.decode(ResultsBag<MediaItem>.self, forKey: .recommendations))?.results ?? []
        recommendations = recs.map { $0.withType(.movie) }

        externalIDs = try? c.decode(MediaExternalIDs.self, forKey: .externalIDs)
        watchProviders = (try? c.decode(WatchProvidersResponse.self, forKey: .watchProviders))?.us

        if let rd = try? c.decode(ReleaseDatesResponse.self, forKey: .releaseDates) {
            certification = rd.usCertification
        } else {
            certification = nil
        }
    }

    enum CodingKeys: String, CodingKey {
        case id, title, overview, runtime, status, budget, revenue, homepage, genres
        case credits, videos, recommendations
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case logoPath = "logo_path"
        case releaseDate = "release_date"
        case voteAverage = "vote_average"
        case voteCount = "vote_count"
        case externalIDs = "external_ids"
        case watchProviders = "watch/providers"
        case releaseDates = "release_dates"
    }
}

// MARK: - Decoding helpers

struct CreditsBag: Decodable, Sendable { let cast: [CastMember] }

struct ResultsBag<T: Decodable>: Decodable {
    let results: [T]
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        results = (try? c.decode([T].self, forKey: .results)) ?? []
    }
    enum CodingKeys: String, CodingKey { case results }
}

private struct ReleaseDatesResponse: Decodable {
    struct Country: Decodable {
        let iso31661: String
        let releaseDates: [Entry]
        enum CodingKeys: String, CodingKey {
            case iso31661 = "iso_3166_1"
            case releaseDates = "release_dates"
        }
    }
    struct Entry: Decodable {
        let certification: String?
        let type: Int?
    }
    let results: [Country]

    /// Prefer release type 3 (theatrical) then 2 (limited), else first non-empty.
    var usCertification: String? {
        guard let us = results.first(where: { $0.iso31661 == "US" }) else { return nil }
        let scored = us.releaseDates
            .filter { $0.certification?.isEmpty == false }
            .sorted { score($0.type) < score($1.type) }
        return scored.first?.certification
    }

    private func score(_ type: Int?) -> Int {
        switch type {
        case 3: 0
        case 2: 1
        default: 2
        }
    }
}
