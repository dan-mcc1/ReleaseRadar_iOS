import Foundation

/// Mirrors GET /calendar?from_date=&to_date= response.
/// Only the fields the iOS timeline needs are decoded.
struct CalendarResponse: Decodable, Sendable {
    let shows: [ShowWithCalendar]
    let movies: [CalendarMovie]
}

struct ShowWithCalendar: Decodable, Sendable {
    let show: CalendarShow
    let episodes: [CalendarEpisode]
}

struct CalendarShow: Decodable, Sendable {
    let id: Int
    let name: String
    let posterPath: String?
    let backdropPath: String?
    /// `HH:mm` (e.g. "21:00") if the show has a fixed airtime.
    let airTime: String?
    /// IANA zone like "America/New_York".
    let airTimezone: String?

    enum CodingKeys: String, CodingKey {
        case id, name
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case airTime = "air_time"
        case airTimezone = "air_timezone"
    }
}

struct CalendarEpisode: Decodable, Sendable {
    let id: Int
    let showId: Int
    let name: String
    let overview: String?
    let seasonNumber: Int
    let episodeNumber: Int
    let airDate: String?
    let stillPath: String?
    /// TMDB episode_type — "standard", "finale", "mid_season", "premiere".
    /// Drives the Season Premiere / Finale tag rendered on calendar cards.
    let episodeType: String?
    let isWatched: Bool?

    enum CodingKeys: String, CodingKey {
        case id, name, overview
        case showId = "show_id"
        case seasonNumber = "season_number"
        case episodeNumber = "episode_number"
        case airDate = "air_date"
        case stillPath = "still_path"
        case episodeType = "episode_type"
        case isWatched = "is_watched"
    }
}

struct CalendarMovie: Decodable, Sendable {
    let id: Int
    let title: String
    let overview: String?
    let releaseDate: String?
    let posterPath: String?
    let backdropPath: String?
    let isWatched: Bool?

    enum CodingKeys: String, CodingKey {
        case id, title, overview
        case releaseDate = "release_date"
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case isWatched = "is_watched"
    }
}

// MARK: - Unified timeline entry

/// One row in the timeline — either a movie release or a TV episode airing.
struct CalendarEntry: Identifiable, Hashable, Sendable {
    enum Kind: Hashable, Sendable {
        case movie(id: Int)
        case episode(showId: Int, episodeId: Int, season: Int, number: Int)
    }

    let kind: Kind
    let date: Date
    let title: String
    let subtitle: String?
    let overview: String?
    let posterPath: String?
    let backdropPath: String?
    let contentType: ContentType
    let isWatched: Bool
    /// TMDB episode_type for TV entries — `nil` for movies and unknown values.
    let episodeType: String?
    /// Pre-formatted air-time string like `"9:00 PM ET"`. Built once in
    /// `timelineEntries()` from the show's `air_time` + `air_timezone`.
    /// Movies don't carry an airtime, so this stays nil for them.
    let airTime: String?

    var id: String {
        switch kind {
        case .movie(let id): "movie-\(id)"
        case .episode(let showId, let episodeId, _, _): "ep-\(showId)-\(episodeId)"
        }
    }

    var posterURL: URL? {
        guard let path = posterPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w185\(path)")
    }

    /// Builds a `MediaItem` suitable for routing into `MediaDetailView`.
    /// Episodes navigate to the parent show's detail page, since the iOS
    /// app doesn't have a standalone episode page yet.
    var asMediaItem: MediaItem {
        let mediaID: Int
        switch kind {
        case .movie(let id): mediaID = id
        case .episode(let showId, _, _, _): mediaID = showId
        }
        return MediaItem(
            id: mediaID,
            contentType: contentType,
            title: title,
            posterPath: posterPath
        )
    }
}

extension CalendarResponse {
    /// Flattens shows+episodes and movies into one sorted timeline.
    func timelineEntries() -> [CalendarEntry] {
        var entries: [CalendarEntry] = []

        for movie in movies {
            guard let releaseDate = movie.releaseDate,
                  let date = MediaItem.tmdbDateFormatter.date(from: releaseDate)
            else { continue }
            entries.append(CalendarEntry(
                kind: .movie(id: movie.id),
                date: date,
                title: movie.title,
                subtitle: "Movie release",
                overview: movie.overview,
                posterPath: movie.posterPath,
                backdropPath: movie.backdropPath,
                contentType: .movie,
                isWatched: movie.isWatched ?? false,
                episodeType: nil,
                airTime: nil
            ))
        }

        for bundle in shows {
            let formattedAirTime = formatAirTime(bundle.show.airTime, zone: bundle.show.airTimezone)
            for episode in bundle.episodes {
                guard let airDate = episode.airDate,
                      let date = MediaItem.tmdbDateFormatter.date(from: airDate)
                else { continue }
                let code = String(format: "S%02dE%02d", episode.seasonNumber, episode.episodeNumber)
                entries.append(CalendarEntry(
                    kind: .episode(
                        showId: bundle.show.id,
                        episodeId: episode.id,
                        season: episode.seasonNumber,
                        number: episode.episodeNumber
                    ),
                    date: date,
                    title: bundle.show.name,
                    subtitle: "\(code) · \(episode.name)",
                    overview: episode.overview,
                    posterPath: bundle.show.posterPath,
                    backdropPath: bundle.show.backdropPath,
                    contentType: .tv,
                    isWatched: episode.isWatched ?? false,
                    episodeType: episode.episodeType,
                    airTime: formattedAirTime
                ))
            }
        }

        return entries.sorted { $0.date < $1.date }
    }
}

/// Map IANA timezone names to compact display abbreviations. Matches the
/// backend's `_TZ_ABBR` so users see the same labels in emails and the app.
private let airTimezoneAbbr: [String: String] = [
    "America/New_York": "ET",
    "America/Chicago": "CT",
    "America/Denver": "MT",
    "America/Los_Angeles": "PT",
    "America/Phoenix": "MT",
    "Europe/London": "GMT",
    "Europe/Paris": "CET",
    "Europe/Berlin": "CET",
    "Australia/Sydney": "AEST",
    "Australia/Melbourne": "AEST",
    "Asia/Tokyo": "JST",
]

/// Formats a `"HH:mm"` air-time + IANA zone into a compact display string,
/// e.g. `("21:00", "America/New_York")` → `"9:00 PM ET"`. Returns `nil`
/// when the raw time isn't parseable so callers can omit the chip cleanly.
private func formatAirTime(_ raw: String?, zone: String?) -> String? {
    guard let raw, !raw.isEmpty else { return nil }
    let parts = raw.split(separator: ":")
    guard parts.count >= 2,
          let hour = Int(parts[0]),
          let minute = Int(parts[1]),
          (0...23).contains(hour),
          (0...59).contains(minute)
    else { return nil }

    let period = hour >= 12 ? "PM" : "AM"
    let h12 = hour % 12 == 0 ? 12 : hour % 12
    let timeStr = minute == 0 ? "\(h12) \(period)" : String(format: "%d:%02d %@", h12, minute, period)

    if let zone, let abbr = airTimezoneAbbr[zone] {
        return "\(timeStr) \(abbr)"
    }
    return timeStr
}
