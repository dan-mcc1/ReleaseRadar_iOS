import Foundation

/// Endpoints under /friends, /reviews, /recommendations, /moderation,
/// /events, /notifications.
extension APIClient {

    // MARK: - /friends

    /// GET /friends/search
    func friendsSearch(query: String) async throws -> [FriendSearchEntry] {
        try await get("/friends/search", query: [.init(name: "q", value: query)])
    }

    /// GET /friends/suggestions
    func friendsSuggestions() async throws -> Data {
        try await getData("/friends/suggestions")
    }

    /// GET /friends/suggestions — decoded helper.
    func friendsSuggestionsDecoded() async throws -> [FriendSuggestion] {
        try await get("/friends/suggestions")
    }

    /// POST /friends/request
    @discardableResult
    func friendsSendRequest(addresseeUsername: String, message: String? = nil) async throws -> Data {
        try await send(
            "/friends/request",
            method: "POST",
            body: FriendRequestBody(addressee_username: addresseeUsername, message: message)
        )
    }

    /// PATCH /friends/respond
    @discardableResult
    func friendsRespond(friendshipID: Int, accept: Bool) async throws -> Data {
        try await send(
            "/friends/respond",
            method: "PATCH",
            body: FriendRespondBody(friendship_id: friendshipID, accept: accept)
        )
    }

    /// DELETE /friends/cancel/{friendship_id}
    @discardableResult
    func friendsCancelRequest(friendshipID: Int) async throws -> Data {
        try await send("/friends/cancel/\(friendshipID)", method: "DELETE")
    }

    /// DELETE /friends/remove/{friend_id}
    @discardableResult
    func friendsRemove(friendID: String) async throws -> Data {
        try await send("/friends/remove/\(friendID)", method: "DELETE")
    }

    /// GET /friends
    func friendsList() async throws -> Data {
        try await getData("/friends")
    }

    /// GET /friends/requests/incoming/count
    func friendsIncomingCount() async throws -> CountResponse {
        try await get("/friends/requests/incoming/count")
    }

    /// GET /friends/requests/incoming
    func friendsIncomingRequests() async throws -> Data {
        try await getData("/friends/requests/incoming")
    }

    /// GET /friends/requests/outgoing
    func friendsOutgoingRequests() async throws -> Data {
        try await getData("/friends/requests/outgoing")
    }

    /// GET /friends/followers
    func friendsFollowers() async throws -> Data {
        try await getData("/friends/followers")
    }

    /// GET /friends/my-activity
    func friendsMyActivity() async throws -> Data {
        try await getData("/friends/my-activity")
    }

    /// GET /friends/activity
    func friendsActivity() async throws -> Data {
        try await getData("/friends/activity")
    }

    /// GET /friends/content/{content_type}/{content_id}
    func friendsContentActivity(type: ContentType, id: Int) async throws -> Data {
        try await getData("/friends/content/\(type.rawValue)/\(id)")
    }

    /// GET /friends/feed
    func friendsFeed() async throws -> Data {
        try await getData("/friends/feed")
    }

    // MARK: - /reviews

    /// GET /reviews
    func reviews(type: ContentType, id: Int, sort: String = "newest") async throws -> [ReviewEntry] {
        try await get("/reviews", query: [
            .init(name: "content_type", value: type.rawValue),
            .init(name: "content_id", value: "\(id)"),
            .init(name: "sort", value: sort)
        ])
    }

    /// GET /reviews/aggregate
    func reviewsAggregate(type: ContentType, id: Int) async throws -> ReviewAggregate {
        try await get("/reviews/aggregate", query: [
            .init(name: "content_type", value: type.rawValue),
            .init(name: "content_id", value: "\(id)")
        ])
    }

    /// GET /reviews/external-scores
    func reviewsExternalScores(imdbID: String) async throws -> Data {
        try await getData("/reviews/external-scores", query: [
            .init(name: "imdb_id", value: imdbID)
        ])
    }

    /// GET /reviews/external-scores — decoded helper.
    func reviewsExternalScoresDecoded(imdbID: String) async throws -> ExternalScores {
        try await get("/reviews/external-scores", query: [
            .init(name: "imdb_id", value: imdbID)
        ])
    }

    /// POST /reviews/{review_id}/like
    func reviewToggleLike(reviewID: Int) async throws -> ReviewLikeResponse {
        try await sendDecoded("/reviews/\(reviewID)/like", method: "POST")
    }

    /// POST /reviews
    func reviewCreateOrUpdate(type: ContentType, id: Int, text: String) async throws -> ReviewEntry {
        try await sendDecoded(
            "/reviews",
            method: "POST",
            body: ReviewCreateBody(content_type: type.rawValue, content_id: id, review_text: text)
        )
    }

    /// DELETE /reviews
    @discardableResult
    func reviewDelete(type: ContentType, id: Int) async throws -> Data {
        try await send("/reviews", method: "DELETE", body: ContentRef(type: type, id: id))
    }

    // MARK: - /recommendations

    /// GET /recommendations/for-you
    func recommendationsForYou(mode: String = "recent") async throws -> Data {
        try await getData("/recommendations/for-you", query: [.init(name: "mode", value: mode)])
    }

    /// GET /recommendations/for-you — decoded helper.
    func recommendationsForYouDecoded(mode: String = "recent") async throws -> ForYouResponse {
        try await get("/recommendations/for-you", query: [.init(name: "mode", value: mode)])
    }

    /// GET /recommendations/inbox — decoded helper.
    func recommendationsInboxDecoded() async throws -> [RecommendationInboxEntry] {
        try await get("/recommendations/inbox")
    }

    /// GET /friends/activity — decoded helper.
    func friendsActivityDecoded() async throws -> [ActivityEntry] {
        try await get("/friends/activity")
    }

    /// GET /friends/my-activity — decoded helper.
    func friendsMyActivityDecoded() async throws -> [ActivityEntry] {
        try await get("/friends/my-activity")
    }

    /// GET /friends — decoded helper.
    func friendsListDecoded() async throws -> [FriendEntry] {
        try await get("/friends")
    }

    /// GET /friends/requests/incoming — decoded helper.
    func friendsIncomingRequestsDecoded() async throws -> [FriendRequest] {
        try await get("/friends/requests/incoming")
    }

    /// GET /friends/requests/outgoing — decoded helper.
    func friendsOutgoingRequestsDecoded() async throws -> [FriendRequest] {
        try await get("/friends/requests/outgoing")
    }

    /// GET /friends/followers — decoded helper.
    func friendsFollowersDecoded() async throws -> [FriendEntry] {
        try await get("/friends/followers")
    }

    /// POST /recommendations/send
    @discardableResult
    func recommendationsSend(
        recipientUsername: String,
        type: ContentType,
        id: Int,
        title: String,
        posterPath: String? = nil,
        message: String? = nil
    ) async throws -> Data {
        try await send(
            "/recommendations/send",
            method: "POST",
            body: RecommendationCreateBody(
                recipient_username: recipientUsername,
                content_type: type.rawValue,
                content_id: id,
                content_title: title,
                content_poster_path: posterPath,
                message: message
            )
        )
    }

    /// GET /recommendations/inbox
    func recommendationsInbox() async throws -> Data {
        try await getData("/recommendations/inbox")
    }

    /// GET /recommendations/unread-count
    func recommendationsUnreadCount() async throws -> CountResponse {
        try await get("/recommendations/unread-count")
    }

    /// PATCH /recommendations/{recommendation_id}/read
    @discardableResult
    func recommendationsMarkRead(recommendationID: Int) async throws -> Data {
        try await send("/recommendations/\(recommendationID)/read", method: "PATCH")
    }

    /// DELETE /recommendations/{recommendation_id}
    func recommendationsDelete(recommendationID: Int) async throws -> DetailResponse {
        try await sendDecoded("/recommendations/\(recommendationID)", method: "DELETE")
    }

    // MARK: - /moderation

    /// POST /moderation/block/{user_id}
    func moderationBlock(userID: String) async throws -> DetailResponse {
        try await sendDecoded("/moderation/block/\(userID)", method: "POST")
    }

    /// DELETE /moderation/block/{user_id}
    @discardableResult
    func moderationUnblock(userID: String) async throws -> Data {
        try await send("/moderation/block/\(userID)", method: "DELETE")
    }

    /// GET /moderation/blocks
    func moderationBlocks() async throws -> [BlockEntry] {
        try await get("/moderation/blocks")
    }

    /// POST /moderation/report
    @discardableResult
    func moderationReport(
        reportedType: String,
        reportedID: String,
        reason: String,
        message: String? = nil
    ) async throws -> Data {
        try await send(
            "/moderation/report",
            method: "POST",
            body: ReportBody(
                reported_type: reportedType,
                reported_id: reportedID,
                reason: reason,
                message: message
            )
        )
    }

    // MARK: - /events

    /// POST /events/token — short-lived (60s) token used to authenticate the SSE stream.
    func eventsToken() async throws -> SessionTokenResponse {
        try await sendDecoded("/events/token", method: "POST")
    }

    /// Builds the URL for the SSE stream — callers handle the stream with
    /// `URLSession.bytes(for:)` or similar, since SSE isn't JSON.
    nonisolated func eventsStreamURL(baseURL: URL = APIClient.defaultBaseURL, token: String) -> URL? {
        var components = URLComponents(url: baseURL.appendingPathComponent("/events/stream"), resolvingAgainstBaseURL: false)
        components?.queryItems = [.init(name: "token", value: token)]
        return components?.url
    }

    // MARK: - /notifications

    /// GET /notifications/preferences
    func notificationPreferences() async throws -> NotificationPreferences {
        try await get("/notifications/preferences")
    }

    /// PATCH /notifications/preferences
    @discardableResult
    func updateNotificationPreferences(
        emailNotifications: Bool? = nil,
        notificationFrequency: String? = nil,
        profileVisibility: String? = nil,
        notifyNewSeasons: Bool? = nil,
        notifyStreamingChanges: Bool? = nil,
        notifyTrailers: Bool? = nil,
        digestHour: Int? = nil,
        digestTimezone: String? = nil,
        pushNotificationsEnabled: Bool? = nil,
        pushNotifyEpisodeAir: Bool? = nil,
        episodeAlertLeadMinutes: Int? = nil
    ) async throws -> Data {
        try await send(
            "/notifications/preferences",
            method: "PATCH",
            body: NotificationPreferencesUpdate(
                email_notifications: emailNotifications,
                notification_frequency: notificationFrequency,
                profile_visibility: profileVisibility,
                notify_new_seasons: notifyNewSeasons,
                notify_streaming_changes: notifyStreamingChanges,
                notify_trailers: notifyTrailers,
                digest_hour: digestHour,
                digest_timezone: digestTimezone,
                push_notifications_enabled: pushNotificationsEnabled,
                push_notify_episode_air: pushNotifyEpisodeAir,
                episode_alert_lead_minutes: episodeAlertLeadMinutes
            )
        )
    }

    /// POST /notifications/send-digest
    func notificationsSendDigest() async throws -> MessageResponse {
        try await sendDecoded("/notifications/send-digest", method: "POST")
    }

    /// GET /notifications/unsubscribe — typically opened from an email link, but
    /// available here for completeness.
    func notificationsUnsubscribe(uid: String, token: String) async throws -> MessageResponse {
        try await get("/notifications/unsubscribe", query: [
            .init(name: "uid", value: uid),
            .init(name: "token", value: token)
        ])
    }
}
