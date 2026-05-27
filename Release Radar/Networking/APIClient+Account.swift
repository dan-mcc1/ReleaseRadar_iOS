import Foundation

/// Endpoints under /user, /billing, /ical, /streaming, /feedback, /import,
/// /export, /admin.
extension APIClient {

    // MARK: - /user

    /// POST /user/create
    func userCreate(username: String? = nil) async throws -> AppUser {
        try await sendDecoded("/user/create", method: "POST", body: CreateUserBody(username: username))
    }

    /// GET /user/me — already exposed as `currentUser()` in APIClient.swift.

    /// POST /user/acknowledge-warning
    func userAcknowledgeWarning() async throws -> DetailResponse {
        try await sendDecoded("/user/acknowledge-warning", method: "POST")
    }

    /// GET /user/account-status
    func userAccountStatus() async throws -> AccountStatus {
        try await get("/user/account-status")
    }

    /// POST /user/appeal
    func userSubmitAppeal(message: String, requestUnsilence: Bool = false) async throws -> DetailResponse {
        try await sendDecoded(
            "/user/appeal",
            method: "POST",
            body: AppealBody(message: message, request_unsilence: requestUnsilence)
        )
    }

    /// PUT /user/update-email
    func userUpdateEmail(newEmail: String) async throws -> AppUser {
        try await sendDecoded(
            "/user/update-email",
            method: "PUT",
            body: UpdateEmailBody(new_email: newEmail)
        )
    }

    /// PUT /user/update-username
    func userUpdateUsername(newUsername: String) async throws -> AppUser {
        try await sendDecoded(
            "/user/update-username",
            method: "PUT",
            body: UpdateUsernameBody(new_username: newUsername)
        )
    }

    /// PUT /user/update-avatar
    func userUpdateAvatar(avatarKey: String?) async throws -> AppUser {
        try await sendDecoded(
            "/user/update-avatar",
            method: "PUT",
            body: UpdateAvatarBody(avatar_key: avatarKey)
        )
    }

    /// PUT /user/update-bio
    func userUpdateBio(bio: String?) async throws -> AppUser {
        try await sendDecoded(
            "/user/update-bio",
            method: "PUT",
            body: UpdateBioBody(bio: bio)
        )
    }

    func userUpdateDisplayName(newDisplayName: String?) async throws -> AppUser {
        try await sendDecoded(
            "/user/update-display-name",
            method: "PUT",
            body: UpdateDisplayNameBody(display_name: newDisplayName)
        )
    }

    /// GET /user/check-username
    func userCheckUsername(_ username: String) async throws -> AvailabilityResponse {
        try await get("/user/check-username", query: [.init(name: "username", value: username)])
    }

    /// GET /user/check-email-banned
    func userCheckEmailBanned(_ email: String) async throws -> BannedCheckResponse {
        try await get("/user/check-email-banned", query: [.init(name: "email", value: email)])
    }

    /// GET /user/stats
    func userStats() async throws -> Data {
        try await getData("/user/stats")
    }

    /// POST /notifications/devices/register — registers (or refreshes) the
    /// user's FCM token so the backend can target their device for push.
    /// Returns the current unread badge count so the client can sync the
    /// in-app + home-screen badge in a single round trip.
    @discardableResult
    func registerDevice(token: String, platform: String = "ios", appVersion: String? = nil) async throws -> PushRegisterResponse {
        try await sendDecoded(
            "/notifications/devices/register",
            method: "POST",
            body: DeviceRegisterBody(token: token, platform: platform, app_version: appVersion)
        )
    }

    /// POST /notifications/devices/unregister — call on sign-out so the
    /// backend stops sending pushes to this device.
    @discardableResult
    func unregisterDevice(token: String) async throws -> Data {
        try await send(
            "/notifications/devices/unregister",
            method: "POST",
            body: DeviceUnregisterBody(token: token)
        )
    }

    /// GET /notifications/badge — server-authoritative unread count for
    /// the signed-in user. Used by `NotificationsModel.refresh(...)`.
    func notificationsBadge() async throws -> BadgeResponse {
        try await get("/notifications/badge")
    }

    /// GET /notifications/inbox — latest inbox rows + badge count in one shot.
    func notificationsInbox(
        limit: Int = 50,
        beforeID: Int? = nil,
        unreadOnly: Bool = false
    ) async throws -> NotificationsInboxResponse {
        var query: [URLQueryItem] = [
            .init(name: "limit", value: "\(limit)"),
            .init(name: "unread_only", value: unreadOnly ? "true" : "false")
        ]
        if let beforeID { query.append(.init(name: "before_id", value: "\(beforeID)")) }
        return try await get("/notifications/inbox", query: query)
    }

    /// POST /notifications/inbox/read — mark one, several, or all unread
    /// inbox items as read. Returns the new badge count.
    @discardableResult
    func notificationsMarkInboxRead(ids: [Int]? = nil) async throws -> BadgeResponse {
        try await sendDecoded(
            "/notifications/inbox/read",
            method: "POST",
            body: MarkInboxReadBody(ids: ids)
        )
    }

    /// POST /notifications/inbox/delete — permanently remove inbox rows.
    /// Pass `nil` for `ids` to clear the entire inbox.
    @discardableResult
    func notificationsDeleteInbox(ids: [Int]? = nil) async throws -> BadgeResponse {
        try await sendDecoded(
            "/notifications/inbox/delete",
            method: "POST",
            body: MarkInboxReadBody(ids: ids)
        )
    }

    /// GET /user/watch-time-stats
    func userWatchTimeStats(year: Int? = nil) async throws -> Data {
        var query: [URLQueryItem] = []
        if let year { query.append(.init(name: "year", value: "\(year)")) }
        return try await getData("/user/watch-time-stats", query: query)
    }

    /// GET /user/profile-summary
    func userProfileSummary() async throws -> Data {
        try await getData("/user/profile-summary")
    }

    /// GET /user/profile-summary — decoded helper.
    func userProfileSummaryDecoded() async throws -> ProfileSummary {
        try await get("/user/profile-summary")
    }

    /// GET /user/profile/{username}
    func userPublicProfile(username: String) async throws -> Data {
        try await getData("/user/profile/\(username)")
    }

    /// GET /user/profile/{username} — decoded helper.
    func userPublicProfileDecoded(username: String) async throws -> PublicProfile {
        try await get("/user/profile/\(username)")
    }

    /// GET /user/stats — decoded helper.
    func userStatsDecoded() async throws -> UserStats {
        try await get("/user/stats")
    }

    /// GET /user/watch-time-stats — decoded helper.
    func userWatchTimeStatsDecoded(year: Int? = nil) async throws -> WatchTimeStats {
        var query: [URLQueryItem] = []
        if let year { query.append(.init(name: "year", value: "\(year)")) }
        return try await get("/user/watch-time-stats", query: query)
    }

    /// POST /import/letterboxd — decoded helper.
    func importLetterboxdDecoded(fileURL: URL) async throws -> ImportResponse {
        let data = try await importLetterboxd(fileURL: fileURL)
        return try decoder.decode(ImportResponse.self, from: data)
    }

    /// POST /import/tvtime — TV Time CSV/ZIP upload.
    func importTVTime(fileURL: URL) async throws -> Data {
        try await uploadMultipart(
            path: "/import/tvtime",
            method: "POST",
            fileURL: fileURL,
            fieldName: "file"
        )
    }

    /// POST /import/tvtime — decoded helper.
    func importTVTimeDecoded(fileURL: URL) async throws -> ImportResponse {
        let data = try await importTVTime(fileURL: fileURL)
        return try decoder.decode(ImportResponse.self, from: data)
    }

    /// GET /streaming/optimizer — decoded helper.
    func streamingOptimizerDecoded() async throws -> StreamingOptimizerResponse {
        try await get("/streaming/optimizer")
    }

    /// POST /user/complete-onboarding
    @discardableResult
    func userCompleteOnboarding() async throws -> Data {
        try await send("/user/complete-onboarding", method: "POST")
    }

    /// POST /user/dismiss-letterboxd-prompt
    @discardableResult
    func userDismissLetterboxdPrompt() async throws -> Data {
        try await send("/user/dismiss-letterboxd-prompt", method: "POST")
    }

    /// POST /user/subscription/cancel
    @discardableResult
    func userCancelSubscription() async throws -> Data {
        try await send("/user/subscription/cancel", method: "POST")
    }

    /// DELETE /user/account
    func userDeleteAccount() async throws -> MessageResponse {
        try await sendDecoded("/user/account", method: "DELETE")
    }

    // MARK: - /billing

    /// POST /billing/create-checkout-session
    func billingCreateCheckoutSession(interval: String) async throws -> URLPayloadResponse {
        try await sendDecoded(
            "/billing/create-checkout-session",
            method: "POST",
            body: CheckoutSessionBody(interval: interval)
        )
    }

    /// POST /billing/create-portal-session
    func billingCreatePortalSession() async throws -> URLPayloadResponse {
        try await sendDecoded("/billing/create-portal-session", method: "POST")
    }

    /// GET /billing/status
    func billingStatus() async throws -> BillingStatus {
        try await get("/billing/status")
    }

    /// POST /billing/cancel
    func billingCancel() async throws -> CancelSubscriptionResponse {
        try await sendDecoded("/billing/cancel", method: "POST")
    }

    // /billing/webhook is Stripe-only; no client-side wrapper.

    // MARK: - /ical

    /// GET /ical/token
    func icalToken() async throws -> TokenResponse {
        try await get("/ical/token")
    }

    /// POST /ical/revoke
    func icalRevoke() async throws -> TokenResponse {
        try await sendDecoded("/ical/revoke", method: "POST")
    }

    /// GET /ical/feed/{token} — public, signed URL. Returns ICS (text/calendar).
    func icalFeedURL(baseURL: URL = APIClient.defaultBaseURL, token: String) -> URL {
        baseURL.appendingPathComponent("/ical/feed/\(token)")
    }

    // MARK: - /streaming

    /// GET /streaming/providers
    func streamingProviders() async throws -> [StreamingProvider] {
        try await get("/streaming/providers")
    }

    /// GET /streaming/services
    func streamingMyServices() async throws -> [StreamingProvider] {
        try await get("/streaming/services")
    }

    /// POST /streaming/services/{provider_id}
    func streamingAddService(providerID: Int) async throws -> OKResponse {
        try await sendDecoded("/streaming/services/\(providerID)", method: "POST")
    }

    /// DELETE /streaming/services/{provider_id}
    func streamingRemoveService(providerID: Int) async throws -> OKResponse {
        try await sendDecoded("/streaming/services/\(providerID)", method: "DELETE")
    }

    /// GET /streaming/optimizer — complex response, returned raw.
    func streamingOptimizer() async throws -> Data {
        try await getData("/streaming/optimizer")
    }

    // MARK: - /feedback

    /// POST /feedback
    func feedbackSubmit(category: String, subject: String, description: String) async throws -> FeedbackCreateResponse {
        try await sendDecoded(
            "/feedback",
            method: "POST",
            body: FeedbackCreateBody(category: category, subject: subject, description: description)
        )
    }

    /// GET /feedback (admin)
    func feedbackList(
        category: String? = nil,
        status: String? = nil,
        limit: Int = 50,
        offset: Int = 0
    ) async throws -> FeedbackListResponse {
        var query: [URLQueryItem] = [
            .init(name: "limit", value: "\(limit)"),
            .init(name: "offset", value: "\(offset)")
        ]
        if let category { query.append(.init(name: "category", value: category)) }
        if let status { query.append(.init(name: "status", value: status)) }
        return try await get("/feedback", query: query)
    }

    /// PATCH /feedback/{feedback_id} (admin)
    func feedbackUpdate(feedbackID: Int, status: String, adminNotes: String? = nil) async throws -> FeedbackCreateResponse {
        try await sendDecoded(
            "/feedback/\(feedbackID)",
            method: "PATCH",
            body: FeedbackStatusUpdateBody(status: status, admin_notes: adminNotes)
        )
    }

    // MARK: - /import

    /// POST /import/letterboxd — multipart upload of a CSV or ZIP file.
    func importLetterboxd(fileURL: URL) async throws -> Data {
        try await uploadMultipart(
            path: "/import/letterboxd",
            method: "POST",
            fileURL: fileURL,
            fieldName: "file"
        )
    }

    /// POST /import/letterboxd with raw bytes (use when the file isn't on disk yet).
    func importLetterboxd(data: Data, filename: String, mimeType: String = "text/csv") async throws -> Data {
        try await uploadMultipart(
            path: "/import/letterboxd",
            method: "POST",
            fileData: data,
            filename: filename,
            mimeType: mimeType,
            fieldName: "file"
        )
    }

    // MARK: - /export

    /// GET /export/zip — returns a ZIP archive of the user's data.
    func exportZip() async throws -> Data {
        try await getData("/export/zip")
    }

    // MARK: - /admin

    /// GET /admin/stats
    func adminStats() async throws -> Data {
        try await getData("/admin/stats")
    }

    /// GET /admin/reports
    func adminReports(status: String = "pending", skip: Int = 0, limit: Int = 50) async throws -> Data {
        try await getData("/admin/reports", query: [
            .init(name: "status", value: status),
            .init(name: "skip", value: "\(skip)"),
            .init(name: "limit", value: "\(limit)")
        ])
    }

    /// POST /admin/reports/{report_id}/accept
    @discardableResult
    func adminAcceptReport(
        reportID: Int,
        action: String,
        adminNotes: String? = nil,
        suspendDays: Int? = nil
    ) async throws -> Data {
        try await send(
            "/admin/reports/\(reportID)/accept",
            method: "POST",
            body: AdminReportActionBody(action: action, admin_notes: adminNotes, suspend_days: suspendDays)
        )
    }

    /// POST /admin/reports/{report_id}/reject
    @discardableResult
    func adminRejectReport(reportID: Int, adminNotes: String? = nil) async throws -> Data {
        try await send(
            "/admin/reports/\(reportID)/reject",
            method: "POST",
            body: AdminNotesBody(admin_notes: adminNotes)
        )
    }

    /// GET /admin/users
    func adminUsers(search: String = "", skip: Int = 0, limit: Int = 50) async throws -> Data {
        try await getData("/admin/users", query: [
            .init(name: "search", value: search),
            .init(name: "skip", value: "\(skip)"),
            .init(name: "limit", value: "\(limit)")
        ])
    }

    /// POST /admin/users/{target_user_id}/unsuspend
    @discardableResult
    func adminUnsuspendUser(userID: String) async throws -> Data {
        try await send("/admin/users/\(userID)/unsuspend", method: "POST")
    }

    /// POST /admin/users/{target_user_id}/suspend
    @discardableResult
    func adminSuspendUser(userID: String, days: Int, reason: String? = nil) async throws -> Data {
        try await send(
            "/admin/users/\(userID)/suspend",
            method: "POST",
            body: AdminSuspendBody(days: days, reason: reason)
        )
    }

    /// POST /admin/users/{target_user_id}/tier
    @discardableResult
    func adminSetUserTier(userID: String, tier: String) async throws -> Data {
        try await send(
            "/admin/users/\(userID)/tier",
            method: "POST",
            body: AdminTierBody(tier: tier)
        )
    }

    /// POST /admin/users/{target_user_id}/ban
    @discardableResult
    func adminBanUser(userID: String, reason: String? = nil) async throws -> Data {
        try await send(
            "/admin/users/\(userID)/ban",
            method: "POST",
            body: AdminBanBody(reason: reason)
        )
    }

    /// GET /admin/banned-emails
    func adminBannedEmails() async throws -> Data {
        try await getData("/admin/banned-emails")
    }

    /// DELETE /admin/banned-emails/{entry_id}
    @discardableResult
    func adminRemoveBannedEmail(entryID: Int) async throws -> Data {
        try await send("/admin/banned-emails/\(entryID)", method: "DELETE")
    }

    /// POST /admin/users/{target_user_id}/unban
    @discardableResult
    func adminUnbanUser(userID: String) async throws -> Data {
        try await send("/admin/users/\(userID)/unban", method: "POST")
    }

    /// POST /admin/users/{target_user_id}/unsilence
    @discardableResult
    func adminUnsilenceUser(userID: String) async throws -> Data {
        try await send("/admin/users/\(userID)/unsilence", method: "POST")
    }

    /// GET /admin/appeals
    func adminAppeals(status: String = "pending", skip: Int = 0, limit: Int = 50) async throws -> Data {
        try await getData("/admin/appeals", query: [
            .init(name: "status", value: status),
            .init(name: "skip", value: "\(skip)"),
            .init(name: "limit", value: "\(limit)")
        ])
    }

    /// POST /admin/appeals/{appeal_id}/approve
    @discardableResult
    func adminApproveAppeal(appealID: Int, adminNotes: String? = nil, liftSilence: Bool = false) async throws -> Data {
        try await send(
            "/admin/appeals/\(appealID)/approve",
            method: "POST",
            body: AdminApproveAppealBody(admin_notes: adminNotes, lift_silence: liftSilence)
        )
    }

    /// POST /admin/appeals/{appeal_id}/reject
    @discardableResult
    func adminRejectAppeal(appealID: Int, adminNotes: String? = nil) async throws -> Data {
        try await send(
            "/admin/appeals/\(appealID)/reject",
            method: "POST",
            body: AdminNotesBody(admin_notes: adminNotes)
        )
    }

    /// DELETE /admin/users/{target_user_id}
    @discardableResult
    func adminDeleteUser(userID: String) async throws -> Data {
        try await send("/admin/users/\(userID)", method: "DELETE")
    }
}
