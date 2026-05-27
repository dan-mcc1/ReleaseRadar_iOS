import Foundation

/// Unified media item used across search results, watchlist, and watched lists.
/// Backend response shapes are not formally documented in the OpenAPI spec, so this
/// type decodes defensively — unknown fields are ignored and many fields are optional.
struct MediaItem: Identifiable, Hashable, Codable, Sendable {
    let id: Int
    let contentType: ContentType
    let title: String
    let overview: String?
    let posterPath: String?
    let backdropPath: String?
    let releaseDate: Date?
    let voteAverage: Double?
    let popularity: Double?

    var posterURL: URL? {
        posterPath.flatMap { Self.tmdbImageURL(path: $0, size: "w342") }
    }

    var backdropURL: URL? {
        backdropPath.flatMap { Self.tmdbImageURL(path: $0, size: "w780") }
    }

    private static func tmdbImageURL(path: String, size: String) -> URL? {
        URL(string: "https://image.tmdb.org/t/p/\(size)\(path)")
    }

    enum CodingKeys: String, CodingKey {
        case id
        case contentType = "content_type"
        case mediaType = "media_type"
        case title
        case name
        case overview
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case releaseDate = "release_date"
        case firstAirDate = "first_air_date"
        case voteAverage = "vote_average"
        case popularity
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)

        if let type = try? container.decode(ContentType.self, forKey: .contentType) {
            contentType = type
        } else if let type = try? container.decode(ContentType.self, forKey: .mediaType) {
            contentType = type
        } else {
            // Fall back to TV when first_air_date is present, else movie
            let hasFirstAir = (try? container.decodeIfPresent(String.self, forKey: .firstAirDate)) != nil
            contentType = hasFirstAir ? .tv : .movie
        }

        let titleValue = try container.decodeIfPresent(String.self, forKey: .title)
        let nameValue = try container.decodeIfPresent(String.self, forKey: .name)
        title = titleValue ?? nameValue ?? ""

        overview = try container.decodeIfPresent(String.self, forKey: .overview)
        posterPath = try container.decodeIfPresent(String.self, forKey: .posterPath)
        backdropPath = try container.decodeIfPresent(String.self, forKey: .backdropPath)
        voteAverage = try container.decodeIfPresent(Double.self, forKey: .voteAverage)
        popularity = try container.decodeIfPresent(Double.self, forKey: .popularity)

        let releaseDateString = try container.decodeIfPresent(String.self, forKey: .releaseDate)
        let firstAirDateString = try container.decodeIfPresent(String.self, forKey: .firstAirDate)
        let dateString = releaseDateString ?? firstAirDateString
        releaseDate = dateString.flatMap(Self.tmdbDateFormatter.date(from:))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(contentType, forKey: .contentType)
        try container.encode(title, forKey: contentType == .movie ? .title : .name)
        try container.encodeIfPresent(overview, forKey: .overview)
        try container.encodeIfPresent(posterPath, forKey: .posterPath)
        try container.encodeIfPresent(backdropPath, forKey: .backdropPath)
        try container.encodeIfPresent(voteAverage, forKey: .voteAverage)
        try container.encodeIfPresent(popularity, forKey: .popularity)
        if let releaseDate {
            let key: CodingKeys = contentType == .movie ? .releaseDate : .firstAirDate
            try container.encode(Self.tmdbDateFormatter.string(from: releaseDate), forKey: key)
        }
    }

    init(
        id: Int,
        contentType: ContentType,
        title: String,
        overview: String? = nil,
        posterPath: String? = nil,
        backdropPath: String? = nil,
        releaseDate: Date? = nil,
        voteAverage: Double? = nil,
        popularity: Double? = nil
    ) {
        self.id = id
        self.contentType = contentType
        self.title = title
        self.overview = overview
        self.posterPath = posterPath
        self.backdropPath = backdropPath
        self.releaseDate = releaseDate
        self.voteAverage = voteAverage
        self.popularity = popularity
    }

    /// Returns a copy with the given content type — used by multi endpoints to
    /// force movie vs. tv classification rather than relying on heuristics.
    func withType(_ type: ContentType) -> MediaItem {
        MediaItem(
            id: id,
            contentType: type,
            title: title,
            overview: overview,
            posterPath: posterPath,
            backdropPath: backdropPath,
            releaseDate: releaseDate,
            voteAverage: voteAverage,
            popularity: popularity
        )
    }

    /// Parses TMDb-style "yyyy-MM-dd" strings as **local** calendar days.
    /// These strings have no time component, so interpreting them in the user's
    /// timezone keeps groupings consistent with what they see on screen (a date
    /// like 2026-05-20 should land in the May 20 bucket regardless of UTC offset).
    static let tmdbDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        return formatter
    }()
}
