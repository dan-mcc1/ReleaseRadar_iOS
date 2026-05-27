import Foundation

// MARK: - Genre

struct Genre: Decodable, Identifiable, Hashable, Sendable {
    let id: Int
    let name: String
}

struct GenreListResponse: Decodable, Sendable {
    /// The current backend returns singular `movie` and `tv` keys
    /// (`{"movie": [...], "tv": [...]}`). Older deploys returned plural
    /// `movies` / `shows` / `all` — keep both so a server upgrade in
    /// either direction doesn't black out the genre list.
    let movie: [Genre]?
    let movies: [Genre]?
    let shows: [Genre]?
    let tv: [Genre]?
    let all: [Genre]?

    var combined: [Genre] {
        let raw = (all ?? []) + (movie ?? []) + (movies ?? []) + (shows ?? []) + (tv ?? [])
        var seen = Set<Int>()
        return raw.filter { seen.insert($0.id).inserted }
    }

    /// Genres TMDb knows for movies. Some movie-only genres (e.g. Horror)
    /// have no TV equivalent — filtering against the right side prevents
    /// the user from selecting a genre that will always return empty.
    var forMovies: [Genre] {
        let raw = (movie ?? []) + (movies ?? [])
        var seen = Set<Int>()
        return raw.filter { seen.insert($0.id).inserted }
    }

    /// Genres TMDb knows for TV.
    var forTV: [Genre] {
        let raw = (tv ?? []) + (shows ?? [])
        var seen = Set<Int>()
        return raw.filter { seen.insert($0.id).inserted }
    }

    /// Filtered list for a specific content type.
    func genres(for type: ContentType) -> [Genre] {
        switch type {
        case .movie: return forMovies
        case .tv: return forTV
        }
    }
}

// MARK: - Multi-category search results

/// Backend `GET /search?query=…` returns `{movies, shows, people, collections}`.
/// Each list arrives in its own TMDB shape — the decoder forces the right
/// contentType on movies/shows so downstream filtering is reliable.
struct SearchAllResults: Decodable, Sendable {
    let movies: [MediaItem]
    let shows: [MediaItem]
    let people: [PersonItem]
    let collections: [SearchedCollection]

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let rawMovies = (try? c.decode([MediaItem].self, forKey: .movies)) ?? []
        let rawShows = (try? c.decode([MediaItem].self, forKey: .shows)) ?? []
        movies = rawMovies.map { $0.withType(.movie) }
        shows = rawShows.map { $0.withType(.tv) }
        people = (try? c.decode([PersonItem].self, forKey: .people)) ?? []
        collections = (try? c.decode([SearchedCollection].self, forKey: .collections)) ?? []
    }

    enum CodingKeys: String, CodingKey {
        case movies, shows, people, collections
    }

    var totalCount: Int {
        movies.count + shows.count + people.count + collections.count
    }
}

struct SearchedCollection: Decodable, Identifiable, Hashable, Sendable {
    let id: Int
    let name: String?
    let overview: String?
    let posterPath: String?
    let backdropPath: String?

    enum CodingKeys: String, CodingKey {
        case id, name, overview
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
    }
}

// MARK: - External scores (OMDB-backed)

/// `GET /reviews/external-scores?imdb_id=…` proxies to OMDB and returns any of
/// these three string-encoded values. All fields are optional.
struct ExternalScores: Decodable, Sendable {
    let imdb: String?            // e.g. "8.5/10"
    let rottenTomatoes: String?  // e.g. "94%"
    let metacritic: String?      // e.g. "88/100"

    enum CodingKeys: String, CodingKey {
        case imdb
        case rottenTomatoes = "rotten_tomatoes"
        case metacritic
    }

    var isEmpty: Bool { imdb == nil && rottenTomatoes == nil && metacritic == nil }
}

// MARK: - Search with genre

struct GenreSearchResponse: Decodable, Sendable {
    let movies: [MediaItem]?
    let shows: [MediaItem]?
    let totalPages: Int?
    let people: [PersonItem]?

    enum CodingKeys: String, CodingKey {
        case movies, shows, people
        case totalPages = "total_pages"
    }
}

struct PersonItem: Decodable, Identifiable, Sendable, Hashable {
    let id: Int
    let name: String?
    let profilePath: String?
    let knownForDepartment: String?

    enum CodingKeys: String, CodingKey {
        case id, name
        case profilePath = "profile_path"
        case knownForDepartment = "known_for_department"
    }
}

// MARK: - Watched episode row

// MARK: - Episode ratings chart
//
// Mirrors GET /tv/{id}/episode_ratings — a 2D grid of every episode's TMDb
// vote average, used by the editorial heat-map on the show detail page.

struct EpisodeRatingPoint: Decodable, Sendable {
    let episodeNumber: Int
    let name: String?
    let voteAverage: Double?

    enum CodingKeys: String, CodingKey {
        case name
        case episodeNumber = "episode_number"
        case voteAverage = "vote_average"
    }
}

struct SeasonRatings: Decodable, Identifiable, Sendable {
    let seasonNumber: Int
    let episodes: [EpisodeRatingPoint]

    var id: Int { seasonNumber }

    enum CodingKeys: String, CodingKey {
        case episodes
        case seasonNumber = "season_number"
    }
}

/// One row in `GET /watched-episode/{show_id}` — represents an episode the
/// user has marked watched.
struct WatchedEpisode: Decodable, Hashable, Sendable {
    let seasonNumber: Int
    let episodeNumber: Int
    let watchedAt: String?
    let rating: Double?

    enum CodingKeys: String, CodingKey {
        case seasonNumber = "season_number"
        case episodeNumber = "episode_number"
        case watchedAt = "watched_at"
        case rating
    }

    var key: String { "\(seasonNumber)-\(episodeNumber)" }
}

// MARK: - Next unwatched episode (Continue Watching rail)

/// `GET /watched-episode/next/bulk?show_ids=…` — for each show id, returns
/// either `{"finished": true}` or the next unwatched episode's metadata.
struct NextEpisode: Decodable, Sendable, Hashable {
    let finished: Bool
    let seasonNumber: Int?
    let episodeNumber: Int?
    let name: String?
    let stillPath: String?
    let overview: String?
    let airDate: String?

    enum CodingKeys: String, CodingKey {
        case finished, name, overview
        case seasonNumber = "season_number"
        case episodeNumber = "episode_number"
        case stillPath = "still_path"
        case airDate = "air_date"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        finished = (try? c.decode(Bool.self, forKey: .finished)) ?? false
        seasonNumber = try? c.decode(Int.self, forKey: .seasonNumber)
        episodeNumber = try? c.decode(Int.self, forKey: .episodeNumber)
        name = try? c.decode(String.self, forKey: .name)
        stillPath = try? c.decode(String.self, forKey: .stillPath)
        overview = try? c.decode(String.self, forKey: .overview)
        airDate = try? c.decode(String.self, forKey: .airDate)
    }
}

// MARK: - News

struct NewsResponse: Decodable, Sendable {
    let articles: [NewsArticle]
    let totalResults: Int?
    let totalPages: Int?

    enum CodingKeys: String, CodingKey {
        case articles
        case totalResults = "total_results"
        case totalPages = "total_pages"
    }
}

struct NewsArticle: Decodable, Identifiable, Sendable {
    let title: String?
    let description: String?
    let url: String
    let imageUrl: String?
    let publishedAt: String?
    let source: NewsSource?

    var id: String { url }

    enum CodingKeys: String, CodingKey {
        case title, description, url, source
        case imageUrl = "image_url"
        case publishedAt = "published_at"
    }
}

struct NewsSource: Decodable, Sendable {
    let name: String?
}

// MARK: - Collection (TMDB)

struct TMDBCollection: Decodable, Sendable, Identifiable {
    let id: Int
    let name: String
    let overview: String?
    let posterPath: String?
    let backdropPath: String?
    let parts: [MediaItem]?

    enum CodingKeys: String, CodingKey {
        case id, name, overview, parts
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
    }
}

// MARK: - Collections (backend, user-aware)

/// One entry on the Browse Collections page. Includes the curated metadata
/// the backend tracks for filtering and sorting (size, rating, year span).
struct CollectionBrowseEntry: Decodable, Identifiable, Hashable, Sendable {
    let id: Int
    let name: String
    let posterPath: String?
    let backdropPath: String?
    let size: Int
    let avgRating: Double?
    let popularity: Double?
    let minYear: Int?
    let maxYear: Int?

    enum CodingKeys: String, CodingKey {
        case id, name, size, popularity
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case avgRating = "avg_rating"
        case minYear = "min_year"
        case maxYear = "max_year"
    }
}

struct CollectionBrowseResponse: Decodable, Sendable {
    let page: Int
    let pageSize: Int
    let total: Int
    let results: [CollectionBrowseEntry]

    enum CodingKeys: String, CodingKey {
        case page, total, results
        case pageSize = "page_size"
    }
}

struct CollectionGenreEntry: Decodable, Identifiable, Hashable, Sendable {
    let id: Int
    let name: String
    let collectionCount: Int

    enum CodingKeys: String, CodingKey {
        case id, name
        case collectionCount = "collection_count"
    }
}

struct CollectionGenresResponse: Decodable, Sendable {
    let genres: [CollectionGenreEntry]
}

/// One bucket row on the My Collections page. Favorites omit the progress
/// counters; in-progress and finished entries include them so we can render
/// the inline progress bar without a per-collection round trip.
struct MyCollectionEntry: Decodable, Identifiable, Hashable, Sendable {
    let id: Int
    let name: String
    let posterPath: String?
    let backdropPath: String?
    let releasedParts: Int?
    let watchedParts: Int?

    enum CodingKeys: String, CodingKey {
        case id, name
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case releasedParts = "released_parts"
        case watchedParts = "watched_parts"
    }

    /// 0…1 watch fraction across released films in the collection.
    var progress: Double {
        guard let released = releasedParts, released > 0, let watched = watchedParts else { return 0 }
        return min(1, Double(watched) / Double(released))
    }
}

struct MyCollectionsResponse: Decodable, Sendable {
    let favorites: [MyCollectionEntry]
    let inProgress: [MyCollectionEntry]
    let finished: [MyCollectionEntry]

    enum CodingKeys: String, CodingKey {
        case favorites, finished
        case inProgress = "in_progress"
    }
}

/// `GET /collections/{id}/status` — single-collection progress for the
/// signed-in user. Drives the progress card on the collection detail page.
struct CollectionStatus: Decodable, Sendable {
    let collectionId: Int
    let totalParts: Int
    let releasedParts: Int
    let watchedParts: Int
    let finished: Bool
    let watchedMovieIds: [Int]

    enum CodingKeys: String, CodingKey {
        case finished
        case collectionId = "collection_id"
        case totalParts = "total_parts"
        case releasedParts = "released_parts"
        case watchedParts = "watched_parts"
        case watchedMovieIds = "watched_movie_ids"
    }

    var fraction: Double {
        guard releasedParts > 0 else { return 0 }
        return min(1, Double(watchedParts) / Double(releasedParts))
    }
}

struct CollectionStatsGenre: Decodable, Identifiable, Hashable, Sendable {
    let id: Int
    let name: String
    let count: Int
}

struct CollectionStats: Decodable, Sendable {
    let collectionId: Int
    let count: Int
    let avgRating: Double?
    let highestRating: Double?
    let lowestRating: Double?
    let avgRuntime: Double?
    let totalRuntime: Int?
    let avgBudget: Double?
    let totalBudget: Double?
    let avgRevenue: Double?
    let totalRevenue: Double?
    let minYear: Int?
    let maxYear: Int?
    let genres: [CollectionStatsGenre]

    enum CodingKeys: String, CodingKey {
        case count, genres
        case collectionId = "collection_id"
        case avgRating = "avg_rating"
        case highestRating = "highest_rating"
        case lowestRating = "lowest_rating"
        case avgRuntime = "avg_runtime"
        case totalRuntime = "total_runtime"
        case avgBudget = "avg_budget"
        case totalBudget = "total_budget"
        case avgRevenue = "avg_revenue"
        case totalRevenue = "total_revenue"
        case minYear = "min_year"
        case maxYear = "max_year"
    }
}

struct CollectionRankingEntry: Decodable, Identifiable, Sendable {
    let movieId: Int
    let rank: Int
    var id: Int { movieId }

    enum CodingKeys: String, CodingKey {
        case rank
        case movieId = "movie_id"
    }
}

struct CollectionRankingResponse: Decodable, Sendable {
    let ranking: [CollectionRankingEntry]
}

struct CollectionRankingUpdateBody: Encodable {
    let ordered_movie_ids: [Int]
}

// MARK: - Communities (groups)

/// One row from `GET /communities` / `GET /communities/mine` and the shape
/// returned by single-community endpoints. `viewer_role` is `nil` when the
/// signed-in user isn't a member; `viewer_can_edit_media` rolls together
/// owner/admin/member-with-edit-permission.
struct Community: Decodable, Identifiable, Hashable, Sendable {
    let id: Int
    let slug: String
    let name: String
    let description: String?
    let bannerColor: String?
    let visibility: String
    let isFeatured: Bool
    let memberCount: Int
    let createdAt: String?
    let createdBy: String?
    let viewerRole: String?
    let membersCanEditMedia: Bool
    let viewerCanEditMedia: Bool

    enum CodingKeys: String, CodingKey {
        case id, slug, name, description, visibility
        case bannerColor = "banner_color"
        case isFeatured = "is_featured"
        case memberCount = "member_count"
        case createdAt = "created_at"
        case createdBy = "created_by"
        case viewerRole = "viewer_role"
        case membersCanEditMedia = "members_can_edit_media"
        case viewerCanEditMedia = "viewer_can_edit_media"
    }

    var isMember: Bool { viewerRole != nil }
    var isOwnerOrAdmin: Bool { viewerRole == "owner" || viewerRole == "admin" }
    var isPublic: Bool { visibility == "public" }
}

struct CommunityCreateBody: Encodable {
    let name: String
    let description: String?
    let visibility: String
    let banner_color: String?
}

struct CommunityUpdateBody: Encodable {
    let name: String?
    let description: String?
    let visibility: String?
    let banner_color: String?
    let members_can_edit_media: Bool?
}

struct CommunityJoinResponse: Decodable, Sendable {
    let role: String
}

struct CommunityLeaveResponse: Decodable, Sendable {
    let left: Bool
}

/// Tiny user blurb the backend embeds in member / invitation / post / reply
/// payloads. Avatar isn't stored here — drive it from `username` via
/// `AvatarView` which already knows how to do colour-hashed fallbacks.
struct CommunityUserBlurb: Decodable, Hashable, Sendable {
    let id: String
    let username: String
    let displayName: String?

    enum CodingKeys: String, CodingKey {
        case id, username
        case displayName = "display_name"
    }

    var label: String { displayName?.isEmpty == false ? displayName! : username }
}

struct CommunityMember: Decodable, Identifiable, Hashable, Sendable {
    let user: CommunityUserBlurb
    let role: String
    let joinedAt: String?

    var id: String { user.id }

    enum CodingKeys: String, CodingKey {
        case user, role
        case joinedAt = "joined_at"
    }
}

struct CommunityInviteBody: Encodable {
    let username: String
}

struct CommunityInvitationStub: Decodable, Sendable {
    let id: Int
    let communityId: Int
    let userId: String
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case communityId = "community_id"
        case userId = "user_id"
        case createdAt = "created_at"
    }
}

/// One row on the user's pending invitations list. The nested `community`
/// object is enough to render an invitation card without a second fetch.
struct CommunityInvitation: Decodable, Identifiable, Sendable {
    let id: Int
    let createdAt: String?
    let community: CommunityInvitationCommunity
    let invitedBy: CommunityUserBlurb?

    enum CodingKeys: String, CodingKey {
        case id, community
        case createdAt = "created_at"
        case invitedBy = "invited_by"
    }
}

struct CommunityInvitationCommunity: Decodable, Hashable, Sendable {
    let id: Int
    let slug: String
    let name: String
    let description: String?
    let bannerColor: String?
    let visibility: String?
    let memberCount: Int?

    enum CodingKeys: String, CodingKey {
        case id, slug, name, description, visibility
        case bannerColor = "banner_color"
        case memberCount = "member_count"
    }
}

struct CommunityInvitationRespondBody: Encodable {
    let accept: Bool
}

struct CommunityInvitationRespondResponse: Decodable, Sendable {
    let communityId: Int
    let accepted: Bool

    enum CodingKeys: String, CodingKey {
        case accepted
        case communityId = "community_id"
    }
}

struct CommunityMediaMovie: Decodable, Identifiable, Hashable, Sendable {
    let id: Int
    let contentId: Int
    let title: String
    let posterPath: String?
    let addedBy: String?
    let voteAverage: Double?

    enum CodingKeys: String, CodingKey {
        case id, title
        case contentId = "content_id"
        case posterPath = "poster_path"
        case addedBy = "added_by"
        case voteAverage = "vote_average"
    }
}

struct CommunityMediaShow: Decodable, Identifiable, Hashable, Sendable {
    let id: Int
    let contentId: Int
    let name: String
    let posterPath: String?
    let addedBy: String?
    let voteAverage: Double?

    enum CodingKeys: String, CodingKey {
        case id, name
        case contentId = "content_id"
        case posterPath = "poster_path"
        case addedBy = "added_by"
        case voteAverage = "vote_average"
    }
}

struct CommunityMediaResponse: Decodable, Sendable {
    let movies: [CommunityMediaMovie]
    let shows: [CommunityMediaShow]
}

struct CommunityMediaAddBody: Encodable {
    let content_type: String
    let content_id: Int
}

struct CommunityPost: Decodable, Identifiable, Sendable {
    let id: Int
    let communityId: Int
    let title: String?
    let body: String
    let replyCount: Int
    let likeCount: Int
    let viewerLiked: Bool
    let editedAt: String?
    let createdAt: String?
    let user: CommunityUserBlurb?

    enum CodingKeys: String, CodingKey {
        case id, title, body, user
        case communityId = "community_id"
        case replyCount = "reply_count"
        case likeCount = "like_count"
        case viewerLiked = "viewer_liked"
        case editedAt = "edited_at"
        case createdAt = "created_at"
    }
}

struct CommunityReply: Decodable, Identifiable, Sendable {
    let id: Int
    let postId: Int
    let body: String
    let likeCount: Int
    let viewerLiked: Bool
    let editedAt: String?
    let createdAt: String?
    let user: CommunityUserBlurb?

    enum CodingKeys: String, CodingKey {
        case id, body, user
        case postId = "post_id"
        case likeCount = "like_count"
        case viewerLiked = "viewer_liked"
        case editedAt = "edited_at"
        case createdAt = "created_at"
    }
}

struct CommunityPostDetail: Decodable, Sendable {
    let post: CommunityPost
    let replies: [CommunityReply]
}

struct CommunityPostCreateBody: Encodable {
    let title: String?
    let body: String
}

struct CommunityReplyCreateBody: Encodable {
    let body: String
}

struct CommunityLikeResponse: Decodable, Sendable {
    let liked: Bool
    let likeCount: Int

    enum CodingKeys: String, CodingKey {
        case liked
        case likeCount = "like_count"
    }
}

/// One row from `POST /collections/status/bulk`. The backend returns the
/// full dict with `String` keys (stringified collection IDs); the API
/// helper rewraps it into an `[Int: CollectionBulkStatus]` for ergonomic use.
struct CollectionBulkStatus: Decodable, Sendable {
    let totalParts: Int
    let releasedParts: Int
    let watchedParts: Int
    let finished: Bool

    enum CodingKeys: String, CodingKey {
        case finished
        case totalParts = "total_parts"
        case releasedParts = "released_parts"
        case watchedParts = "watched_parts"
    }

    /// 0…1 progress fraction across released films.
    var fraction: Double {
        guard releasedParts > 0 else { return 0 }
        return min(1, Double(watchedParts) / Double(releasedParts))
    }
}

// MARK: - For You

struct ForYouResponse: Decodable, Sendable {
    let movies: [MediaItem]
    let shows: [MediaItem]
    let seedCount: Int?

    enum CodingKeys: String, CodingKey {
        case movies, shows
        case seedCount = "seed_count"
    }
}

// MARK: - Activity

struct ActivityEntry: Decodable, Identifiable, Sendable {
    let id: Int
    let userId: String?
    let username: String?
    let action: String                // backend's `activity_type`
    let contentType: String?
    let contentId: Int?
    let contentTitle: String?
    let contentPosterPath: String?
    let contentOverview: String?
    let rating: Double?
    let seasonNumber: Int?
    let episodeNumber: Int?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, rating, username
        case userId = "user_id"
        case action = "activity_type"
        case contentType = "content_type"
        case contentId = "content_id"
        case contentTitle = "content_title"
        case contentPosterPath = "content_poster_path"
        case contentOverview = "content_overview"
        case seasonNumber = "season_number"
        case episodeNumber = "episode_number"
        case createdAt = "created_at"
    }
}

// MARK: - Recommendation (inbox)

struct RecommendationInboxEntry: Decodable, Identifiable, Sendable {
    let id: Int
    let senderUsername: String?
    let contentType: String
    let contentId: Int
    let contentTitle: String?
    let contentPosterPath: String?
    let message: String?
    let isRead: Bool?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, message
        case senderUsername = "sender_username"
        case contentType = "content_type"
        case contentId = "content_id"
        case contentTitle = "content_title"
        case contentPosterPath = "content_poster_path"
        case isRead = "is_read"
        case createdAt = "created_at"
    }
}

// MARK: - Friends

/// Backend shape: `{"friendship_id": Int, "friend": {"id": String, "username": String}}`.
/// `id` here is the user id (used for navigation / removal), `friendshipId` is the
/// row id used for accept/decline/cancel calls.
struct FriendEntry: Decodable, Identifiable, Hashable, Sendable {
    let friendshipId: Int
    let id: String
    let username: String?
    let avatarKey: String?

    enum CodingKeys: String, CodingKey {
        case friendshipId = "friendship_id"
        case friend
        case avatarKey = "avatar_key"
    }
    enum FriendKeys: String, CodingKey {
        case id, username
        case avatarKey = "avatar_key"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        friendshipId = try c.decode(Int.self, forKey: .friendshipId)
        let nested = try c.nestedContainer(keyedBy: FriendKeys.self, forKey: .friend)
        id = try nested.decode(String.self, forKey: .id)
        username = try? nested.decode(String.self, forKey: .username)
        avatarKey = (try? nested.decode(String.self, forKey: .avatarKey))
            ?? (try? c.decode(String.self, forKey: .avatarKey))
    }
}

/// Friend request rows. Incoming requests carry `from_user`, outgoing carry
/// `to_user`; this type decodes either and exposes the counterparty as
/// `userId` / `username`.
/// `GET /friends/suggestions` — friends-of-friends + popular users that the
/// viewer isn't already connected to.
struct FriendSuggestion: Decodable, Identifiable, Hashable, Sendable {
    let id: String
    let username: String
    let profileVisibility: String?
    let mutualFriends: Int?
    let reason: String?

    enum CodingKeys: String, CodingKey {
        case id, username, reason
        case profileVisibility = "profile_visibility"
        case mutualFriends = "mutual_friends"
    }
}

struct FriendRequest: Decodable, Identifiable, Sendable {
    let id: Int            // friendship_id
    let userId: String     // requester (incoming) or addressee (outgoing)
    let username: String?
    let message: String?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case friendshipId = "friendship_id"
        case fromUser = "from_user"
        case toUser = "to_user"
        case message
        case createdAt = "created_at"
    }
    enum UserKeys: String, CodingKey { case id, username }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .friendshipId)
        let user: KeyedDecodingContainer<UserKeys>
        if let nested = try? c.nestedContainer(keyedBy: UserKeys.self, forKey: .fromUser) {
            user = nested
        } else if let nested = try? c.nestedContainer(keyedBy: UserKeys.self, forKey: .toUser) {
            user = nested
        } else {
            throw DecodingError.dataCorruptedError(
                forKey: .fromUser,
                in: c,
                debugDescription: "Neither from_user nor to_user present"
            )
        }
        userId = try user.decode(String.self, forKey: .id)
        username = try? user.decode(String.self, forKey: .username)
        message = try? c.decode(String.self, forKey: .message)
        createdAt = try? c.decode(String.self, forKey: .createdAt)
    }
}

// MARK: - Profile summary

/// Backend returns nested `{movies, shows}` lists with optional totals — this
/// flattens into a single combined array per section while preserving totals.
struct ProfileMediaList: Decodable, Sendable {
    let movies: [MediaItem]
    let shows: [MediaItem]
    /// Favorited collections — backend returns `id`, `name`, `poster_path`,
    /// `backdrop_path`. Only populated for the Favorites payload; Watchlist
    /// and Watched lists send an empty list.
    let collections: [SearchedCollection]
    let totalMovies: Int?
    let totalShows: Int?

    enum CodingKeys: String, CodingKey {
        case movies, shows, collections
        case totalMovies = "total_movies"
        case totalShows = "total_shows"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let rawMovies = (try? c.decode([MediaItem].self, forKey: .movies)) ?? []
        let rawShows = (try? c.decode([MediaItem].self, forKey: .shows)) ?? []
        movies = rawMovies.map { $0.withType(.movie) }
        shows = rawShows.map { $0.withType(.tv) }
        collections = (try? c.decode([SearchedCollection].self, forKey: .collections)) ?? []
        totalMovies = try? c.decode(Int.self, forKey: .totalMovies)
        totalShows = try? c.decode(Int.self, forKey: .totalShows)
    }

    var combined: [MediaItem] { movies + shows }
    var isEmpty: Bool { movies.isEmpty && shows.isEmpty && collections.isEmpty }
}

struct ProfileSummary: Decodable, Sendable {
    let user: ProfileSummaryUser
    let favorites: ProfileMediaList?
    let watchlist: ProfileMediaList?
    let watched: ProfileMediaList?
    let friends: [FriendEntry]?
    let incomingRequests: [FriendRequest]?
    let outgoingRequests: [FriendRequest]?
    let followers: [FriendEntry]?

    enum CodingKeys: String, CodingKey {
        case user, favorites, watchlist, watched, friends, followers
        case incomingRequests = "incoming_requests"
        case outgoingRequests = "outgoing_requests"
    }
}

struct ProfileSummaryUser: Decodable, Sendable {
    let id: String
    let email: String?
    let username: String?
    let displayName: String?
    let avatarKey: String?
    let bio: String?
    let profileVisibility: String?
    let createdAt: String?
    let subscriptionTier: String?

    enum CodingKeys: String, CodingKey {
        case id, email, username, bio
        case displayName = "display_name"
        case avatarKey = "avatar_key"
        case profileVisibility = "profile_visibility"
        case createdAt = "created_at"
        case subscriptionTier = "subscription_tier"
    }
}

// MARK: - Public profile

struct PublicProfile: Decodable, Sendable {
    let id: String
    let username: String?
    let displayName: String?
    let bio: String?
    let avatarKey: String?
    let isFriend: Bool?
    let profileVisibility: String?
    let pendingRequestId: Int?
    let incomingRequestId: Int?
    let isFollowing: Bool?
    let followingId: Int?
    let isFollowedByThem: Bool?
    let blockedByViewer: Bool?
    let favorites: ProfileMediaList?
    let watchlist: ProfileMediaList?
    let watched: ProfileMediaList?
    let friends: [FriendEntry]?

    enum CodingKeys: String, CodingKey {
        case id, username, bio, favorites, watchlist, watched, friends
        case displayName = "display_name"
        case avatarKey = "avatar_key"
        case isFriend = "is_friend"
        case profileVisibility = "profile_visibility"
        case pendingRequestId = "pending_request_id"
        case incomingRequestId = "incoming_request_id"
        case isFollowing = "is_following"
        case followingId = "following_id"
        case isFollowedByThem = "is_followed_by_them"
        case blockedByViewer = "blocked_by_viewer"
    }
}

// MARK: - Stats

/// Backend returns nested `counts`, `ratings`, `top_genres`, `streak`.
struct UserStats: Decodable, Sendable {
    let counts: Counts
    let ratings: Ratings
    let topGenres: [GenreCount]
    let streak: Streak

    enum CodingKeys: String, CodingKey {
        case counts, ratings, streak
        case topGenres = "top_genres"
    }

    struct Counts: Decodable, Sendable {
        let moviesWatched: Int
        let showsWatched: Int
        let episodesWatched: Int
        let moviesWatchlist: Int
        let showsWatchlist: Int

        enum CodingKeys: String, CodingKey {
            case moviesWatched = "movies_watched"
            case showsWatched = "shows_watched"
            case episodesWatched = "episodes_watched"
            case moviesWatchlist = "movies_watchlist"
            case showsWatchlist = "shows_watchlist"
        }

        var totalWatched: Int { moviesWatched + showsWatched }
        var totalWatchlist: Int { moviesWatchlist + showsWatchlist }
    }

    struct Ratings: Decodable, Sendable {
        let movieAvg: Double?
        let showAvg: Double?
        let distribution: [RatingBucket]?

        enum CodingKeys: String, CodingKey {
            case movieAvg = "movie_avg"
            case showAvg = "show_avg"
            case distribution
        }
    }

    struct RatingBucket: Decodable, Sendable {
        let rating: Int
        let count: Int
    }

    struct GenreCount: Decodable, Sendable, Identifiable {
        let name: String
        let count: Int
        var id: String { name }
    }

    struct Streak: Decodable, Sendable {
        let current: Int
        let longest: Int
        let todayLogged: Bool?

        enum CodingKeys: String, CodingKey {
            case current, longest
            case todayLogged = "today_logged"
        }
    }
}

struct WatchTimeStats: Decodable, Sendable {
    let totalMinutes: Int?
    let movieMinutes: Int?
    let episodeMinutes: Int?
    let moviesCount: Int?
    let episodesCount: Int?
    let topGenres: [StatsBucket]?
    let topPlatforms: [PlatformBucket]?
    let longestBinge: LongestBinge?
    let humorFact: String?
    let availableYears: [Int]?

    enum CodingKeys: String, CodingKey {
        case totalMinutes = "total_minutes"
        case movieMinutes = "movie_minutes"
        case episodeMinutes = "episode_minutes"
        case moviesCount = "movies_count"
        case episodesCount = "episodes_count"
        case topGenres = "top_genres"
        case topPlatforms = "top_platforms"
        case longestBinge = "longest_binge"
        case humorFact = "humor_fact"
        case availableYears = "available_years"
    }
}

struct LongestBinge: Decodable, Sendable {
    let date: String?
    let minutes: Int?
}

struct StatsBucket: Decodable, Sendable, Identifiable {
    let name: String
    let minutes: Int?
    let count: Int?
    var id: String { name }
}

struct PlatformBucket: Decodable, Sendable, Identifiable {
    let name: String
    let logoPath: String?
    let minutes: Int?
    let count: Int?
    var id: String { name }

    enum CodingKeys: String, CodingKey {
        case name, minutes, count
        case logoPath = "logo_path"
    }
}

// MARK: - Box office (extends APIModels.BoxOfficeEntry — already defined)

// MARK: - Recommendation outgoing helpers (already in APIModels)

// MARK: - Letterboxd import

struct ImportSummary: Decodable, Sendable {
    let total: Int
    let imported: Int
    let watchlisted: Int
    let skipped: Int
    let failed: Int
}

struct ImportResultRow: Decodable, Identifiable, Sendable {
    let row: Int
    let title: String?
    let tmdbId: Int?
    let mediaType: String?
    let status: String
    let reason: String?
    let rating: Double?
    let watchedAt: String?

    var id: Int { row }

    enum CodingKeys: String, CodingKey {
        case row, title, status, reason, rating
        case tmdbId = "tmdb_id"
        case mediaType = "media_type"
        case watchedAt = "watched_at"
    }
}

struct ImportResponse: Decodable, Sendable {
    let summary: ImportSummary
    let results: [ImportResultRow]
}

// MARK: - Streaming optimizer (lightweight subset)

struct StreamingOptimizerResponse: Decodable, Sendable {
    let totalItems: Int?
    let itemsWithStreaming: Int?
    let myServicesCoverage: Int?
    let coverageByProvider: [StreamingCoverage]?
    let suggestedCombo: [StreamingCoverage]?

    enum CodingKeys: String, CodingKey {
        case totalItems = "total_items"
        case itemsWithStreaming = "items_with_streaming"
        case myServicesCoverage = "my_services_coverage"
        case coverageByProvider = "coverage_by_provider"
        case suggestedCombo = "suggested_combo"
    }
}

struct StreamingCoverage: Decodable, Identifiable, Sendable {
    let id: Int
    let name: String
    let logoPath: String?
    let count: Int?
    let youHave: Bool?
    let addsCount: Int?

    enum CodingKeys: String, CodingKey {
        case id, name, count
        case logoPath = "logo_path"
        case youHave = "you_have"
        case addsCount = "adds_count"
    }
}

// MARK: - Subscription tier

enum SubscriptionTier: String, Codable, Sendable {
    case free, premium, admin

    var isPremium: Bool { self == .premium || self == .admin }
}

// MARK: - Watch status enum

enum WatchStatus: String, CaseIterable, Sendable {
    case none = "none"
    case wantToWatch = "Want To Watch"
    case currentlyWatching = "Currently Watching"
    case watched = "Watched"

    var label: String {
        switch self {
        case .none: "—"
        case .wantToWatch: "Watchlist"
        case .currentlyWatching: "Watching"
        case .watched: "Watched"
        }
    }

    var icon: String {
        switch self {
        case .none: "plus.circle.fill"
        case .wantToWatch: "bookmark.fill"
        case .currentlyWatching: "play.circle.fill"
        case .watched: "checkmark.circle.fill"
        }
    }

    var buttonLabel: String {
        switch self {
        case .none: "Add to Watchlist"
        case .wantToWatch: "On Watchlist"
        case .currentlyWatching: "Currently Watching"
        case .watched: "Watched"
        }
    }
}

// MARK: - Season details (for the seasons-dropdown on the show page)

struct SeasonDetails: Decodable, Sendable {
    let id: Int?
    let name: String?
    let overview: String?
    let seasonNumber: Int?
    let posterPath: String?
    let airDate: String?
    let episodes: [EpisodeDTO]

    enum CodingKeys: String, CodingKey {
        case id, name, overview, episodes
        case seasonNumber = "season_number"
        case posterPath = "poster_path"
        case airDate = "air_date"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try? c.decode(Int.self, forKey: .id)
        name = try? c.decode(String.self, forKey: .name)
        overview = try? c.decode(String.self, forKey: .overview)
        seasonNumber = try? c.decode(Int.self, forKey: .seasonNumber)
        posterPath = try? c.decode(String.self, forKey: .posterPath)
        airDate = try? c.decode(String.self, forKey: .airDate)
        episodes = (try? c.decode([EpisodeDTO].self, forKey: .episodes)) ?? []
    }
}

// MARK: - Person details (for the cast → person navigation)

struct PersonDetails: Decodable, Identifiable, Sendable {
    let id: Int
    let name: String?
    let biography: String?
    let birthday: String?
    let placeOfBirth: String?
    let profilePath: String?
    let knownForDepartment: String?
    let movieCredits: PersonCredits?
    let tvCredits: PersonCredits?

    enum CodingKeys: String, CodingKey {
        case id, name, biography, birthday
        case placeOfBirth = "place_of_birth"
        case profilePath = "profile_path"
        case knownForDepartment = "known_for_department"
        case movieCredits = "movie_credits"
        case tvCredits = "tv_credits"
    }
}

struct PersonCredits: Decodable, Sendable {
    let cast: [MediaItem]?
    let crew: [MediaItem]?
}
