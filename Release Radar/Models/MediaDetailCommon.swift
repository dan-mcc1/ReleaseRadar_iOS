import Foundation

/// Shared sub-types used by `MovieDetails` and `ShowDetails`.
/// All decoders are intentionally defensive — TMDB-shaped responses come from the backend
/// with assorted optional fields and the append-to-response payload varies by endpoint.

struct MediaGenre: Decodable, Identifiable, Hashable, Sendable {
    let id: Int
    let name: String
}

struct CastMember: Decodable, Identifiable, Hashable, Sendable {
    let id: Int
    let name: String
    let character: String?
    let profilePath: String?

    var profileURL: URL? {
        profilePath.flatMap { URL(string: "https://image.tmdb.org/t/p/w185\($0)") }
    }

    enum CodingKeys: String, CodingKey {
        case id, name, character
        case profilePath = "profile_path"
    }
}

struct MediaVideo: Decodable, Identifiable, Hashable, Sendable {
    let key: String
    let site: String
    let type: String
    let name: String

    var id: String { key }

    var youtubeURL: URL? {
        site.lowercased() == "youtube" ? URL(string: "https://www.youtube.com/watch?v=\(key)") : nil
    }
}

struct MediaExternalIDs: Decodable, Hashable, Sendable {
    let imdbID: String?
    let instagramID: String?
    let twitterID: String?
    let facebookID: String?

    enum CodingKeys: String, CodingKey {
        case imdbID = "imdb_id"
        case instagramID = "instagram_id"
        case twitterID = "twitter_id"
        case facebookID = "facebook_id"
    }
}

struct WatchProvider: Decodable, Identifiable, Hashable, Sendable {
    let providerID: Int
    let providerName: String
    let logoPath: String?

    var id: Int { providerID }
    var logoURL: URL? {
        logoPath.flatMap { URL(string: "https://image.tmdb.org/t/p/original\($0)") }
    }

    enum CodingKeys: String, CodingKey {
        case providerID = "provider_id"
        case providerName = "provider_name"
        case logoPath = "logo_path"
    }
}

struct WatchProvidersUS: Decodable, Hashable, Sendable {
    let flatrate: [WatchProvider]
    let rent: [WatchProvider]
    let buy: [WatchProvider]

    var isEmpty: Bool { flatrate.isEmpty && rent.isEmpty && buy.isEmpty }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        flatrate = (try? c.decode([WatchProvider].self, forKey: .flatrate)) ?? []
        rent = (try? c.decode([WatchProvider].self, forKey: .rent)) ?? []
        buy = (try? c.decode([WatchProvider].self, forKey: .buy)) ?? []
    }

    enum CodingKeys: String, CodingKey { case flatrate, rent, buy }
}

/// Wrapper around the `watch/providers` payload: `{ results: { "US": {...}, ... } }`.
struct WatchProvidersResponse: Decodable, Sendable {
    let us: WatchProvidersUS?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let results = (try? c.decode([String: WatchProvidersUS].self, forKey: .results)) ?? [:]
        us = results["US"]
    }

    enum CodingKeys: String, CodingKey { case results }
}
