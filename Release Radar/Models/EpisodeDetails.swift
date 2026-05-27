import Foundation

/// Decodes the response from `/tv/{id}/season/{season}/episode/{episode}`.
/// Mirrors the fields the web app's Episode page consumes — overview, still,
/// runtime, vote average, episode type (for the Premiere/Finale badge), and
/// the credits bag (cast + crew + guest stars).
struct EpisodeDetails: Decodable, Identifiable, Sendable {
    let id: Int
    let showId: Int?
    let seasonNumber: Int
    let episodeNumber: Int
    let name: String
    let overview: String?
    let airDate: Date?
    let runtime: Int?
    let stillPath: String?
    let voteAverage: Double?
    let voteCount: Int?
    /// "standard", "finale", "mid_season", etc. Drives the badge label.
    let episodeType: String?
    let cast: [CastMember]
    let crew: [EpisodeCrewMember]
    let guestStars: [CastMember]

    var stillURL: URL? {
        stillPath.flatMap { URL(string: "https://image.tmdb.org/t/p/w1280\($0)") }
    }

    /// "S01" — for breadcrumbs and badges.
    var seasonCode: String { String(format: "S%02d", seasonNumber) }
    var episodeCode: String { String(format: "E%02d", episodeNumber) }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        showId = try? c.decode(Int.self, forKey: .showId)
        seasonNumber = (try? c.decode(Int.self, forKey: .seasonNumber)) ?? 0
        episodeNumber = (try? c.decode(Int.self, forKey: .episodeNumber)) ?? 0
        name = (try? c.decode(String.self, forKey: .name)) ?? ""
        overview = try? c.decode(String.self, forKey: .overview)
        runtime = try? c.decode(Int.self, forKey: .runtime)
        stillPath = try? c.decode(String.self, forKey: .stillPath)
        voteAverage = try? c.decode(Double.self, forKey: .voteAverage)
        voteCount = try? c.decode(Int.self, forKey: .voteCount)
        episodeType = try? c.decode(String.self, forKey: .episodeType)

        if let s = try? c.decode(String.self, forKey: .airDate), !s.isEmpty {
            airDate = MediaItem.tmdbDateFormatter.date(from: s)
        } else {
            airDate = nil
        }

        if let credits = try? c.decode(EpisodeCreditsBag.self, forKey: .credits) {
            cast = credits.cast
            crew = credits.crew
            guestStars = credits.guestStars
        } else {
            cast = []
            crew = []
            guestStars = []
        }
    }

    enum CodingKeys: String, CodingKey {
        case id, name, overview, runtime, credits
        case showId = "show_id"
        case seasonNumber = "season_number"
        case episodeNumber = "episode_number"
        case airDate = "air_date"
        case stillPath = "still_path"
        case voteAverage = "vote_average"
        case voteCount = "vote_count"
        case episodeType = "episode_type"
    }
}

struct EpisodeCrewMember: Decodable, Identifiable, Hashable, Sendable {
    let id: Int
    let name: String
    let job: String
    let profilePath: String?

    enum CodingKeys: String, CodingKey {
        case id, name, job
        case profilePath = "profile_path"
    }
}

private struct EpisodeCreditsBag: Decodable {
    let cast: [CastMember]
    let crew: [EpisodeCrewMember]
    let guestStars: [CastMember]

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        cast = (try? c.decode([CastMember].self, forKey: .cast)) ?? []
        crew = (try? c.decode([EpisodeCrewMember].self, forKey: .crew)) ?? []
        guestStars = (try? c.decode([CastMember].self, forKey: .guestStars)) ?? []
    }

    enum CodingKeys: String, CodingKey {
        case cast, crew
        case guestStars = "guest_stars"
    }
}
