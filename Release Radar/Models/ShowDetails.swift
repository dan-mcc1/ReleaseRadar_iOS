import Foundation

/// Decodes the response from `/tv/{id}/full` — TMDB show payload with
/// append_to_response for credits, videos, recommendations, external_ids,
/// watch/providers, and content_ratings.
struct ShowDetails: Decodable, Identifiable, Sendable {
    let id: Int
    let name: String
    let overview: String?
    let posterPath: String?
    let backdropPath: String?
    let logoPath: String?
    let firstAirDate: Date?
    let lastAirDate: Date?
    let voteAverage: Double?
    let voteCount: Int?
    let status: String?
    let inProduction: Bool?
    let numberOfSeasons: Int?
    let numberOfEpisodes: Int?
    let homepage: String?
    let genres: [MediaGenre]
    let seasons: [ShowSeason]
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

    var asMediaItem: MediaItem {
        MediaItem(
            id: id,
            contentType: .tv,
            title: name,
            overview: overview,
            posterPath: posterPath,
            backdropPath: backdropPath,
            releaseDate: firstAirDate,
            voteAverage: voteAverage
        )
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        name = (try? c.decode(String.self, forKey: .name)) ?? ""
        overview = try? c.decode(String.self, forKey: .overview)
        posterPath = try? c.decode(String.self, forKey: .posterPath)
        backdropPath = try? c.decode(String.self, forKey: .backdropPath)
        logoPath = try? c.decode(String.self, forKey: .logoPath)
        voteAverage = try? c.decode(Double.self, forKey: .voteAverage)
        voteCount = try? c.decode(Int.self, forKey: .voteCount)
        status = try? c.decode(String.self, forKey: .status)
        inProduction = try? c.decode(Bool.self, forKey: .inProduction)
        numberOfSeasons = try? c.decode(Int.self, forKey: .numberOfSeasons)
        numberOfEpisodes = try? c.decode(Int.self, forKey: .numberOfEpisodes)
        homepage = try? c.decode(String.self, forKey: .homepage)
        genres = (try? c.decode([MediaGenre].self, forKey: .genres)) ?? []
        seasons = (try? c.decode([ShowSeason].self, forKey: .seasons)) ?? []

        if let s = try? c.decode(String.self, forKey: .firstAirDate), !s.isEmpty {
            firstAirDate = MediaItem.tmdbDateFormatter.date(from: s)
        } else {
            firstAirDate = nil
        }
        if let s = try? c.decode(String.self, forKey: .lastAirDate), !s.isEmpty {
            lastAirDate = MediaItem.tmdbDateFormatter.date(from: s)
        } else {
            lastAirDate = nil
        }

        cast = (try? c.decode(CreditsBag.self, forKey: .credits))?.cast ?? []
        videos = (try? c.decode(ResultsBag<MediaVideo>.self, forKey: .videos))?.results ?? []

        let recs = (try? c.decode(ResultsBag<MediaItem>.self, forKey: .recommendations))?.results ?? []
        recommendations = recs.map { $0.withType(.tv) }

        externalIDs = try? c.decode(MediaExternalIDs.self, forKey: .externalIDs)
        watchProviders = (try? c.decode(WatchProvidersResponse.self, forKey: .watchProviders))?.us

        if let cr = try? c.decode(ContentRatingsResponse.self, forKey: .contentRatings) {
            certification = cr.results.first(where: { $0.iso31661 == "US" })?.rating
        } else {
            certification = nil
        }
    }

    enum CodingKeys: String, CodingKey {
        case id, name, overview, status, homepage, genres, seasons
        case credits, videos, recommendations
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case logoPath = "logo_path"
        case firstAirDate = "first_air_date"
        case lastAirDate = "last_air_date"
        case voteAverage = "vote_average"
        case voteCount = "vote_count"
        case inProduction = "in_production"
        case numberOfSeasons = "number_of_seasons"
        case numberOfEpisodes = "number_of_episodes"
        case externalIDs = "external_ids"
        case watchProviders = "watch/providers"
        case contentRatings = "content_ratings"
    }
}

struct ShowSeason: Decodable, Identifiable, Hashable, Sendable {
    let id: Int
    let name: String
    let seasonNumber: Int
    let episodeCount: Int?
    let overview: String?
    let posterPath: String?
    let airDate: Date?
    /// Air date of the season's final episode. Backend enriches the
    /// `/tv/{id}/full` payload with this — TMDB itself doesn't expose it.
    let endDate: Date?

    var posterURL: URL? {
        posterPath.flatMap { URL(string: "https://image.tmdb.org/t/p/w185\($0)") }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        name = (try? c.decode(String.self, forKey: .name)) ?? ""
        seasonNumber = (try? c.decode(Int.self, forKey: .seasonNumber)) ?? 0
        episodeCount = try? c.decode(Int.self, forKey: .episodeCount)
        overview = try? c.decode(String.self, forKey: .overview)
        posterPath = try? c.decode(String.self, forKey: .posterPath)
        if let s = try? c.decode(String.self, forKey: .airDate), !s.isEmpty {
            airDate = MediaItem.tmdbDateFormatter.date(from: s)
        } else {
            airDate = nil
        }
        if let s = try? c.decode(String.self, forKey: .endDate), !s.isEmpty {
            endDate = MediaItem.tmdbDateFormatter.date(from: s)
        } else {
            endDate = nil
        }
    }

    enum CodingKeys: String, CodingKey {
        case id, name, overview
        case seasonNumber = "season_number"
        case episodeCount = "episode_count"
        case posterPath = "poster_path"
        case airDate = "air_date"
        case endDate = "end_date"
    }
}

private struct ContentRatingsResponse: Decodable {
    struct Entry: Decodable {
        let iso31661: String
        let rating: String?
        enum CodingKeys: String, CodingKey {
            case iso31661 = "iso_3166_1"
            case rating
        }
    }
    let results: [Entry]
}
