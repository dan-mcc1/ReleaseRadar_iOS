import Foundation

// MARK: - Generic response wrappers

struct DetailResponse: Decodable, Sendable {
    let detail: String
}

struct MessageResponse: Decodable, Sendable {
    let message: String
}

struct CountResponse: Decodable, Sendable {
    let count: Int
}

struct URLPayloadResponse: Decodable, Sendable {
    let url: String
}

struct TokenResponse: Decodable, Sendable {
    let token: String
}

struct SessionTokenResponse: Decodable, Sendable {
    let sessionToken: String

    enum CodingKeys: String, CodingKey {
        case sessionToken = "session_token"
    }
}

struct AvailabilityResponse: Decodable, Sendable {
    let available: Bool
}

struct BannedCheckResponse: Decodable, Sendable {
    let banned: Bool
}

struct OKResponse: Decodable, Sendable {
    let ok: Bool
}

// MARK: - User

struct AccountStatus: Decodable, Sendable {
    let isBanned: Bool
    let banReason: String?
    let isSuspended: Bool
    let suspendedUntil: String?
    let suspensionReason: String?
    let isSilenced: Bool
    let silencedUntil: String?
    let hasPendingAppeal: Bool
    let pendingAppealRequestsUnsilence: Bool?

    enum CodingKeys: String, CodingKey {
        case isBanned = "is_banned"
        case banReason = "ban_reason"
        case isSuspended = "is_suspended"
        case suspendedUntil = "suspended_until"
        case suspensionReason = "suspension_reason"
        case isSilenced = "is_silenced"
        case silencedUntil = "silenced_until"
        case hasPendingAppeal = "has_pending_appeal"
        case pendingAppealRequestsUnsilence = "pending_appeal_requests_unsilence"
    }
}

struct CreateUserBody: Encodable {
    let username: String?
}

struct UpdateEmailBody: Encodable {
    let new_email: String
}

struct UpdateUsernameBody: Encodable {
    let new_username: String
}

struct UpdateAvatarBody: Encodable {
    let avatar_key: String?
}

struct UpdateBioBody: Encodable {
    let bio: String?
}

struct UpdateDisplayNameBody: Encodable {
    let display_name: String?
}

// MARK: - Season rating

struct SeasonRating: Decodable, Sendable {
    let id: Int
    let showId: Int
    let seasonNumber: Int
    let rating: Double
    let ratedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, rating
        case showId = "show_id"
        case seasonNumber = "season_number"
        case ratedAt = "rated_at"
    }
}

struct SeasonRatingAggregate: Decodable, Sendable {
    let average: Double?
    let count: Int
}

struct SeasonRatingUpsertBody: Encodable {
    let show_id: Int
    let season_number: Int
    let rating: Double
}

struct SeasonRatingDeleteBody: Encodable {
    let show_id: Int
    let season_number: Int
}

struct AppealBody: Encodable {
    let message: String
    let request_unsilence: Bool
}

// MARK: - Watchlist

struct WatchlistAddBody: Encodable {
    let content_type: String
    let content_id: Int
    let notify: Bool
}

struct WatchlistReorderBody: Encodable {
    let content_type: String
    let content_id: Int
    let before_id: Int?
    let after_id: Int?
}

struct BulkStatusBody: Encodable {
    let items: [ContentRef]
}

struct WatchStatusEntry: Decodable, Sendable {
    let status: String
    let rating: Double?
}

struct NotifyAllUpdate: Encodable {
    let notify: Bool
    let content_type: String?
}

struct NotifyPrefUpdate: Encodable {
    let content_type: String
    let content_id: Int
    let notify: Bool
}

struct NotifyPrefItem: Decodable, Sendable {
    let contentType: String
    let contentId: Int
    let name: String
    let notify: Bool

    enum CodingKeys: String, CodingKey {
        case contentType = "content_type"
        case contentId = "content_id"
        case name, notify
    }
}

struct ProgressBulkBody: Encodable {
    let show_ids: [Int]
}

struct FinishByBody: Encodable {
    let target_date: String
}

struct FinishByResponse: Decodable, Sendable {
    let showId: Int
    let targetDate: String?
    let cleared: Bool?

    enum CodingKeys: String, CodingKey {
        case showId = "show_id"
        case targetDate = "target_date"
        case cleared
    }
}

/// Mirrors GET /watchlist/progress/{show_id} — episode-level binge progress
/// for a single show. Used to render both the Show Info "Progress" card and
/// the small horizontal bar on watchlist poster thumbnails.
struct ShowProgress: Decodable, Sendable {
    let showId: Int
    let showName: String?
    let totalEpisodes: Int
    let watchedEpisodes: Int
    let remainingEpisodes: Int
    let remainingMinutes: Int
    let epsPerWeekRecent: Double?
    let completionEstimate: String?
    let finishByDate: String?
    let epsPerDayNeeded: Double?
    let minsPerDayNeeded: Int?

    enum CodingKeys: String, CodingKey {
        case showId = "show_id"
        case showName = "show_name"
        case totalEpisodes = "total_episodes"
        case watchedEpisodes = "watched_episodes"
        case remainingEpisodes = "remaining_episodes"
        case remainingMinutes = "remaining_minutes"
        case epsPerWeekRecent = "eps_per_week_recent"
        case completionEstimate = "completion_estimate"
        case finishByDate = "finish_by_date"
        case epsPerDayNeeded = "eps_per_day_needed"
        case minsPerDayNeeded = "mins_per_day_needed"
    }

    /// 0…1 progress fraction. Returns 0 when total is unknown.
    var fraction: Double {
        guard totalEpisodes > 0 else { return 0 }
        return Double(watchedEpisodes) / Double(totalEpisodes)
    }

    var isCaughtUp: Bool {
        totalEpisodes > 0 && remainingEpisodes == 0
    }
}

// MARK: - Watched

struct WatchedRateBody: Encodable {
    let content_type: String
    let content_id: Int
    let rating: Double?
}

// MARK: - Watched Episode

struct EpisodeAnnotationBody: Encodable {
    let rating: Double?
    let notes: String?
}

// MARK: - Friends

struct FriendRequestBody: Encodable {
    let addressee_username: String
    let message: String?
}

struct FriendRespondBody: Encodable {
    let friendship_id: Int
    let accept: Bool
}

struct FriendSearchEntry: Decodable, Sendable, Identifiable {
    let id: String
    let username: String
    let profileVisibility: String?

    enum CodingKeys: String, CodingKey {
        case id, username
        case profileVisibility = "profile_visibility"
    }
}

// MARK: - Favorites

struct FavoriteStatusResponse: Decodable, Sendable {
    let favorited: Bool
}

// MARK: - Recommendations

struct RecommendationCreateBody: Encodable {
    let recipient_username: String
    let content_type: String
    let content_id: Int
    let content_title: String
    let content_poster_path: String?
    let message: String?
}

// MARK: - Device tokens + push-notification inbox

/// Body for `POST /notifications/devices/register`. Sent whenever Firebase
/// Messaging hands us a fresh FCM registration token.
struct DeviceRegisterBody: Encodable {
    let token: String
    let platform: String
    let app_version: String?
}

struct DeviceUnregisterBody: Encodable {
    let token: String
}

/// Response from `/notifications/devices/register` and other badge-aware
/// endpoints — the backend always tells us the latest unread count so
/// the client can keep its badge in lockstep without a follow-up call.
struct PushRegisterResponse: Decodable, Sendable {
    let ok: Bool
    let badge: Int
}

struct BadgeResponse: Decodable, Sendable {
    let badge: Int
}

/// One row from `GET /notifications/inbox`. Matches the column set the
/// backend's inbox endpoint serializes.
struct NotificationEntry: Decodable, Identifiable, Sendable {
    let id: Int
    let type: String                // e.g. "season_premiere", "recommendation"
    let title: String
    let body: String?
    let contentType: String?        // "movie" | "tv" | nil
    let contentId: Int?
    let imageUrl: String?
    let seasonNumber: Int?
    let episodeId: Int?
    let videoKey: String?
    let readAt: String?             // ISO8601 — nil = unread
    let createdAt: String

    var isUnread: Bool { readAt == nil }

    enum CodingKeys: String, CodingKey {
        case id, type, title, body
        case contentType = "content_type"
        case contentId = "content_id"
        case imageUrl = "image_url"
        case seasonNumber = "season_number"
        case episodeId = "episode_id"
        case videoKey = "video_key"
        case readAt = "read_at"
        case createdAt = "created_at"
    }
}

struct NotificationsInboxResponse: Decodable, Sendable {
    let items: [NotificationEntry]
    let badge: Int
}

struct MarkInboxReadBody: Encodable {
    let ids: [Int]?  // nil = mark all
}

// MARK: - Reviews

struct ReviewCreateBody: Encodable {
    let content_type: String
    let content_id: Int
    let review_text: String
}

struct ReviewEntry: Decodable, Identifiable, Sendable {
    let id: Int
    let userId: String
    let username: String
    let reviewText: String
    let rating: Double?
    let createdAt: String?
    let updatedAt: String?
    let likeCount: Int
    let userHasLiked: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case username
        case reviewText = "review_text"
        case rating
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case likeCount = "like_count"
        case userHasLiked = "user_has_liked"
    }
}

struct ReviewAggregate: Decodable, Sendable {
    let average: Double?
    let count: Int
}

struct ReviewLikeResponse: Decodable, Sendable {
    let liked: Bool
    let likeCount: Int

    enum CodingKeys: String, CodingKey {
        case liked
        case likeCount = "like_count"
    }
}

// MARK: - Box Office

struct BoxOfficeEntry: Decodable, Identifiable, Sendable {
    let rank: Int
    let id: Int
    let title: String
    let posterPath: String?
    let backdropPath: String?
    let releaseDate: String?
    let revenue: Int?
    let budget: Int?
    let voteAverage: Double?
    let runtime: Int?

    // The backend returns `genres` as `[{id, name}]` (TMDb shape). We don't
    // render genres on this page yet, so we just don't decode the field —
    // declaring it as `[String]?` here previously made every row throw and
    // the whole leaderboard came back empty.

    enum CodingKeys: String, CodingKey {
        case rank, id, title, revenue, budget, runtime
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case releaseDate = "release_date"
        case voteAverage = "vote_average"
    }
}

// MARK: - Shelf

struct ShelfCreateBody: Encodable {
    let name: String
    let description: String?
}

struct ShelfUpdateBody: Encodable {
    let name: String?
    let description: String?
}

struct ShelfNotifyBody: Encodable {
    let notify: Bool
}

struct ShelfEntry: Decodable, Identifiable, Sendable {
    let id: Int
    let name: String
    let description: String?
    let createdAt: String?
    let itemCount: Int?
    /// Up to 4 TMDB poster paths backend-side, used to render the mini
    /// cover stack on the shelves list.
    let previewPosters: [String]?

    enum CodingKeys: String, CodingKey {
        case id, name, description
        case createdAt = "created_at"
        case itemCount = "item_count"
        case previewPosters = "preview_posters"
    }
}

struct ShelfItemEntry: Decodable, Identifiable, Sendable {
    let id: Int
    let shelfId: Int
    let contentType: String
    let contentId: Int

    enum CodingKeys: String, CodingKey {
        case id
        case shelfId = "shelf_id"
        case contentType = "content_type"
        case contentId = "content_id"
    }
}

struct ShelfNotifyResponse: Decodable, Sendable {
    let id: Int
    let notify: Bool
}

// MARK: - Admin

struct AdminReportActionBody: Encodable {
    let action: String
    let admin_notes: String?
    let suspend_days: Int?
}

struct AdminNotesBody: Encodable {
    let admin_notes: String?
}

struct AdminSuspendBody: Encodable {
    let days: Int
    let reason: String?
}

struct AdminTierBody: Encodable {
    let tier: String
}

struct AdminBanBody: Encodable {
    let reason: String?
}

struct AdminApproveAppealBody: Encodable {
    let admin_notes: String?
    let lift_silence: Bool
}

// MARK: - Billing

struct CheckoutSessionBody: Encodable {
    let interval: String
}

struct BillingStatus: Decodable, Sendable {
    let tier: String
    let status: String?
    let source: String?
    let currentPeriodEnd: String?
    let cancelAtPeriodEnd: Bool?

    enum CodingKeys: String, CodingKey {
        case tier, status, source
        case currentPeriodEnd = "current_period_end"
        case cancelAtPeriodEnd = "cancel_at_period_end"
    }
}

struct CancelSubscriptionResponse: Decodable, Sendable {
    let canceled: Bool
    let cancelAtPeriodEnd: Bool?
    let currentPeriodEnd: String?

    enum CodingKeys: String, CodingKey {
        case canceled
        case cancelAtPeriodEnd = "cancel_at_period_end"
        case currentPeriodEnd = "current_period_end"
    }
}

// MARK: - Rewatch

struct RewatchAddBody: Encodable {
    let content_type: String
    let content_id: Int
    let rating: Double?
    let notes: String?
    let would_rewatch: Bool?
}

struct RewatchUpdateBody: Encodable {
    let rating: Double?
    let notes: String?
    let would_rewatch: Bool?
}

struct RewatchListResponse: Decodable, Sendable {
    let rewatches: [RewatchEntry]
    let count: Int
}

struct RewatchEntry: Decodable, Identifiable, Sendable {
    let id: Int
    let contentType: String?
    let contentId: Int?
    let rating: Double?
    let notes: String?
    let wouldRewatch: Bool?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, rating, notes
        case contentType = "content_type"
        case contentId = "content_id"
        case wouldRewatch = "would_rewatch"
        case createdAt = "created_at"
    }
}

// MARK: - Notifications

struct NotificationPreferences: Decodable, Sendable {
    let emailNotifications: Bool?
    let notificationFrequency: String?
    let profileVisibility: String?
    let notifyNewSeasons: Bool?
    let notifyStreamingChanges: Bool?
    let notifyTrailers: Bool?
    let digestHour: Int?
    let digestTimezone: String?
    let pushNotificationsEnabled: Bool?
    let pushNotifyEpisodeAir: Bool?
    let episodeAlertLeadMinutes: Int?

    enum CodingKeys: String, CodingKey {
        case emailNotifications = "email_notifications"
        case notificationFrequency = "notification_frequency"
        case profileVisibility = "profile_visibility"
        case notifyNewSeasons = "notify_new_seasons"
        case notifyStreamingChanges = "notify_streaming_changes"
        case notifyTrailers = "notify_trailers"
        case digestHour = "digest_hour"
        case digestTimezone = "digest_timezone"
        case pushNotificationsEnabled = "push_notifications_enabled"
        case pushNotifyEpisodeAir = "push_notify_episode_air"
        case episodeAlertLeadMinutes = "episode_alert_lead_minutes"
    }
}

struct NotificationPreferencesUpdate: Encodable {
    let email_notifications: Bool?
    let notification_frequency: String?
    let profile_visibility: String?
    let notify_new_seasons: Bool?
    let notify_streaming_changes: Bool?
    let notify_trailers: Bool?
    let digest_hour: Int?
    let digest_timezone: String?
    let push_notifications_enabled: Bool?
    let push_notify_episode_air: Bool?
    let episode_alert_lead_minutes: Int?
}

// MARK: - Moderation

struct ReportBody: Encodable {
    let reported_type: String
    let reported_id: String
    let reason: String
    let message: String?
}

struct BlockEntry: Decodable, Sendable, Identifiable {
    let userId: String
    let username: String?
    let blockedAt: String?

    var id: String { userId }

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case username
        case blockedAt = "blocked_at"
    }
}

// MARK: - Watch status

struct WatchStatusBody: Encodable {
    let content_type: String
    let content_id: Int
    let target: String
    let current: String
    let notify: Bool
}

struct WatchStatusResponse: Decodable, Sendable {
    let status: String
}

// MARK: - Streaming

struct StreamingProvider: Decodable, Identifiable, Sendable {
    let id: Int
    let name: String
    let logoPath: String?

    enum CodingKeys: String, CodingKey {
        case id, name
        case logoPath = "logo_path"
    }
}

// MARK: - Feedback

struct FeedbackCreateBody: Encodable {
    let category: String
    let subject: String
    let description: String
}

struct FeedbackStatusUpdateBody: Encodable {
    let status: String
    let admin_notes: String?
}

struct FeedbackCreateResponse: Decodable, Sendable {
    let id: Int
    let status: String
}

struct FeedbackEntry: Decodable, Identifiable, Sendable {
    let id: Int
    let category: String?
    let subject: String?
    let description: String?
    let status: String?
    let adminNotes: String?
    let createdAt: String?
    let resolvedAt: String?
    let username: String?

    enum CodingKeys: String, CodingKey {
        case id, category, subject, description, status, username
        case adminNotes = "admin_notes"
        case createdAt = "created_at"
        case resolvedAt = "resolved_at"
    }
}

struct FeedbackListResponse: Decodable, Sendable {
    let total: Int
    let items: [FeedbackEntry]
}

// MARK: - Episode

struct EpisodeDTO: Decodable, Identifiable, Sendable {
    let id: Int
    let showId: Int?
    let seasonNumber: Int?
    let episodeNumber: Int?
    let name: String?
    let airDate: String?
    let runtime: Int?
    let stillPath: String?
    let overview: String?
    let voteAverage: Double?
    let episodeType: String?

    enum CodingKeys: String, CodingKey {
        case id, name, runtime, overview
        case showId = "show_id"
        case seasonNumber = "season_number"
        case episodeNumber = "episode_number"
        case airDate = "air_date"
        case stillPath = "still_path"
        case voteAverage = "vote_average"
        case episodeType = "episode_type"
    }
}

// MARK: - News

enum NewsCategory: String, CaseIterable, Sendable {
    case entertainment
    case movies
    case tv
}
