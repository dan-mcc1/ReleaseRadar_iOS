import SwiftUI
import NukeUI

struct ActivityFeedView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(NotificationsModel.self) private var notifications
    @State private var viewModel = ActivityFeedViewModel()

    var body: some View {
        @Bindable var vm = viewModel
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    FilterChip(
                        label: "Friends",
                        count: viewModel.friendsActivity.count,
                        isActive: vm.tab == .friends,
                        action: { vm.tab = .friends }
                    )
                    FilterChip(
                        label: "You",
                        count: viewModel.myActivity.count,
                        isActive: vm.tab == .me,
                        action: { vm.tab = .me }
                    )
                    FilterChip(
                        label: "Inbox",
                        count: viewModel.unreadCount,
                        isActive: vm.tab == .inbox,
                        action: { vm.tab = .inbox }
                    )
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 20)

                if viewModel.isLoading {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, 32)
                } else if let error = viewModel.errorMessage {
                    InlineErrorBanner(message: error) { Task { await viewModel.load(client: env.apiClient) } }
                        .padding(.horizontal, 16)
                } else {
                    switch vm.tab {
                    case .friends: feedList(viewModel.friendsActivity)
                    case .me: feedList(viewModel.myActivity)
                    case .inbox: inboxList
                    }
                }
            }
            .padding(.vertical, 16)
        }
        .task {
            await viewModel.load(client: env.apiClient)
            await notifications.refresh(client: env.apiClient)
        }
        .refreshable {
            await viewModel.load(client: env.apiClient)
            await notifications.refresh(client: env.apiClient)
        }
        // Incoming push (recommendation, friend request, etc.) → pull the
        // inbox + activity feeds again so the "Inbox (N)" segment count
        // updates in place instead of waiting for the user to swipe down.
        .onReceive(NotificationCenter.default.publisher(for: .pushDidRequestRefresh)) { _ in
            Task { await viewModel.load(client: env.apiClient) }
        }
    }

    @ViewBuilder
    private func feedList(_ entries: [ActivityEntry]) -> some View {
        if entries.isEmpty {
            ContentUnavailableView("Nothing yet", systemImage: "person.2", description: Text("Activity from people you follow will show here."))
        } else {
            LazyVStack(spacing: 10) {
                ForEach(entries) { entry in
                    activityCard(entry)
                        .padding(.horizontal, 16)
                }
            }
        }
    }

    /// Editorial activity card: avatar / user-action / mono ago timestamp
    /// on top, poster + serif title + episode code on the bottom row, with
    /// a rating chip in the top-right when present and MiniWatchButtons
    /// pinned to the right of the content row.
    private func activityCard(_ entry: ActivityEntry) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // ── User row ────────────────────────────────────────────────
            HStack(alignment: .center, spacing: 10) {
                avatarView(for: entry)

                VStack(alignment: .leading, spacing: 2) {
                    usernameLine(for: entry)
                    if let ago = TimeAgo.format(entry.createdAt) {
                        Text("\(ago.uppercased()) AGO")
                            .font(BrandFont.mono(10, weight: .medium))
                            .tracking(0.6)
                            .foregroundStyle(BrandTheme.textDim)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if let rating = entry.rating {
                    HStack(spacing: 3) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(Color(hex: 0xFBBF24))
                        Text(String(format: "%.1f", rating))
                            .font(BrandFont.mono(12, weight: .semibold))
                            .foregroundStyle(BrandTheme.text)
                    }
                }
            }

            // ── Content row ─────────────────────────────────────────────
            HStack(alignment: .top, spacing: 12) {
                contentLink(for: entry) {
                    HStack(alignment: .top, spacing: 12) {
                        LazyImage(url: TMDBImage.poster(entry.contentPosterPath, size: "w185")) { state in
                            if let image = state.image { image.resizable().scaledToFill() }
                            else { BrandTheme.surface2 }
                        }
                        .frame(width: 64, height: 96)
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.contentTitle ?? "—")
                                .font(BrandFont.serif(17))
                                .foregroundStyle(BrandTheme.text)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                            if let s = entry.seasonNumber, let e = entry.episodeNumber {
                                Text("S\(s) · E\(e)")
                                    .font(BrandFont.mono(10.5, weight: .medium))
                                    .tracking(0.7)
                                    .foregroundStyle(BrandTheme.textMuted)
                            }
                            if let overview = entry.contentOverview, !overview.isEmpty {
                                Text(overview)
                                    .font(BrandFont.sans(12))
                                    .foregroundStyle(BrandTheme.textMuted)
                                    .lineLimit(3)
                                    .multilineTextAlignment(.leading)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                if let typeRaw = entry.contentType,
                   let type = ContentType(rawValue: typeRaw),
                   let id = entry.contentId {
                    MiniWatchButtons(type: type, id: id)
                }
            }
        }
        .padding(14)
        .background(BrandTheme.surface, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(BrandTheme.border, lineWidth: 1))
    }

    @ViewBuilder
    private func avatarView(for entry: ActivityEntry) -> some View {
        if let username = entry.username, !isSelf(username) {
            NavigationLink {
                FriendProfileView(username: username)
            } label: {
                AvatarView(username: username, size: 36)
            }
            .buttonStyle(.plain)
        } else {
            AvatarView(username: entry.username, size: 36)
        }
    }

    /// "username action" line. Bold username links to FriendProfileView
    /// unless the entry is the signed-in user (the profile endpoint 400s
    /// on self).
    @ViewBuilder
    private func usernameLine(for entry: ActivityEntry) -> some View {
        let action = actionLabel(entry.action)
        if let username = entry.username {
            if isSelf(username) {
                (
                    Text(username)
                        .font(BrandFont.sans(13.5, weight: .semibold))
                        .foregroundColor(BrandTheme.text)
                    + Text(" \(action)")
                        .font(BrandFont.sans(13.5))
                        .foregroundColor(BrandTheme.textMuted)
                )
                .lineLimit(2)
            } else {
                NavigationLink {
                    FriendProfileView(username: username)
                } label: {
                    (
                        Text(username)
                            .font(BrandFont.sans(13.5, weight: .semibold))
                            .foregroundColor(BrandTheme.text)
                        + Text(" \(action)")
                            .font(BrandFont.sans(13.5))
                            .foregroundColor(BrandTheme.textMuted)
                    )
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                }
                .buttonStyle(.plain)
            }
        } else {
            Text(action)
                .font(BrandFont.sans(13.5))
                .foregroundStyle(BrandTheme.textMuted)
        }
    }

    /// Wraps `label` in the right NavigationLink for the activity entry —
    /// EpisodeInfoView for episode-level actions, MediaDetailView for
    /// show/movie-level actions. Falls back to a plain view when the
    /// payload doesn't carry enough info to route.
    @ViewBuilder
    private func contentLink<Label: View>(
        for entry: ActivityEntry,
        @ViewBuilder label: () -> Label
    ) -> some View {
        if let typeRaw = entry.contentType,
           let type = ContentType(rawValue: typeRaw),
           let id = entry.contentId {
            // Episode-level action: jump straight to the episode page.
            if type == .tv,
               let season = entry.seasonNumber,
               let number = entry.episodeNumber {
                NavigationLink {
                    EpisodeInfoView(
                        showID: id,
                        season: season,
                        episode: number,
                        initialShowName: entry.contentTitle
                    )
                } label: { label() }
                .buttonStyle(.plain)
            } else {
                NavigationLink {
                    MediaDetailView(
                        item: MediaItem(
                            id: id,
                            contentType: type,
                            title: entry.contentTitle ?? "",
                            posterPath: entry.contentPosterPath
                        )
                    )
                } label: { label() }
                .buttonStyle(.plain)
            }
        } else {
            label()
        }
    }

    /// True when `username` matches the signed-in user (case-insensitive).
    /// Used to suppress navigation to FriendProfileView for self entries.
    private func isSelf(_ username: String) -> Bool {
        guard let me = viewModel.currentUsername else { return false }
        return me.caseInsensitiveCompare(username) == .orderedSame
    }

    private func actionLabel(_ raw: String) -> String {
        switch raw {
        case "watched": "watched"
        case "want_to_watch": "added to watchlist"
        case "episode_watched": "watched an episode of"
        case "currently_watching": "started watching"
        case "rated": "rated"
        default: raw.replacingOccurrences(of: "_", with: " ")
        }
    }

    @ViewBuilder
    private var inboxList: some View {
        if viewModel.inbox.isEmpty {
            ContentUnavailableView("Inbox is empty", systemImage: "envelope.open", description: Text("Friends can recommend titles to you here."))
        } else {
            LazyVStack(spacing: 10) {
                ForEach(viewModel.inbox) { rec in
                    recommendationCard(rec)
                        .padding(.horizontal, 16)
                }
            }
        }
    }

    private func recommendationCard(_ rec: RecommendationInboxEntry) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("From @\(rec.senderUsername ?? "—")")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.brandTextSecondary)
                if rec.isRead != true {
                    Text("NEW")
                        .font(.system(.caption2, design: .monospaced))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.brandPrimary, in: Capsule())
                        .foregroundStyle(.white)
                }
                Spacer()
                if let ago = TimeAgo.format(rec.createdAt) {
                    Text(ago).font(.caption).foregroundStyle(Color.brandTextSecondary)
                }
            }
            HStack(alignment: .top, spacing: 10) {
                LazyImage(url: TMDBImage.poster(rec.contentPosterPath, size: "w185")) { state in
                    if let image = state.image { image.resizable().scaledToFill() }
                    else { Color.brandSurfaceElevated }
                }
                .frame(width: 60, height: 90)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                VStack(alignment: .leading, spacing: 4) {
                    Text(rec.contentTitle ?? "—").font(.headline).foregroundStyle(.white)
                    if let message = rec.message, !message.isEmpty {
                        Text(message)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.85))
                            .lineLimit(4)
                    }
                }
                Spacer()
            }
            HStack {
                Button("Mark read") {
                    Task {
                        await viewModel.markRead(rec, client: env.apiClient, notifications: notifications)
                    }
                }
                .buttonStyle(.bordered)
                .disabled(rec.isRead == true)
                Spacer()
                Button(role: .destructive) {
                    Task {
                        await viewModel.delete(rec, client: env.apiClient, notifications: notifications)
                    }
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(12)
        .background(Color.brandSurface, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.brandBorder, lineWidth: 1))
    }
}

@Observable @MainActor
final class ActivityFeedViewModel {
    enum Tab { case friends, me, inbox }

    var tab: Tab = .friends
    var friendsActivity: [ActivityEntry] = []
    var myActivity: [ActivityEntry] = []
    var inbox: [RecommendationInboxEntry] = []
    var unreadCount: Int = 0
    /// The signed-in user's username, cached so the activity rows can
    /// suppress the navigation to FriendProfileView for self entries
    /// (the public-profile endpoint 400s when asked about yourself).
    var currentUsername: String?
    var isLoading = false
    var errorMessage: String?

    func load(client: APIClient) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        async let friends: [ActivityEntry] = (try? await client.friendsActivityDecoded()) ?? []
        async let mine: [ActivityEntry] = (try? await client.friendsMyActivityDecoded()) ?? []
        async let inbox: [RecommendationInboxEntry] = (try? await client.recommendationsInboxDecoded()) ?? []
        async let unread: CountResponse? = try? await client.recommendationsUnreadCount()
        async let me: ProfileSummary? = try? await client.userProfileSummaryDecoded()
        self.friendsActivity = await friends
        self.myActivity = await mine
        self.inbox = await inbox
        self.unreadCount = await (unread?.count ?? 0)
        if let user = await me?.user.username { self.currentUsername = user }
    }

    func markRead(_ rec: RecommendationInboxEntry, client: APIClient, notifications: NotificationsModel) async {
        do {
            try await client.recommendationsMarkRead(recommendationID: rec.id)
            if let idx = inbox.firstIndex(where: { $0.id == rec.id }) {
                inbox[idx] = RecommendationInboxEntry(
                    id: rec.id,
                    senderUsername: rec.senderUsername,
                    contentType: rec.contentType,
                    contentId: rec.contentId,
                    contentTitle: rec.contentTitle,
                    contentPosterPath: rec.contentPosterPath,
                    message: rec.message,
                    isRead: true,
                    createdAt: rec.createdAt
                )
            }
            unreadCount = max(0, unreadCount - 1)
            await clearMatchingNotification(for: rec, client: client, notifications: notifications)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete(_ rec: RecommendationInboxEntry, client: APIClient, notifications: NotificationsModel) async {
        do {
            _ = try await client.recommendationsDelete(recommendationID: rec.id)
            inbox.removeAll { $0.id == rec.id }
            if rec.isRead != true {
                unreadCount = max(0, unreadCount - 1)
            }
            await clearMatchingNotification(for: rec, client: client, notifications: notifications)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// `/recommendations/mark-read` only touches the recommendations table —
    /// the matching row in the `notifications` table stays unread and the
    /// `/notifications/badge` count doesn't budge. Look up any unread
    /// notification rows the backend created for this recommendation
    /// (matched by type + content) and mark them read in the same gesture
    /// so the in-app badge and the home-screen icon badge stay in lockstep.
    private func clearMatchingNotification(
        for rec: RecommendationInboxEntry,
        client: APIClient,
        notifications: NotificationsModel
    ) async {
        do {
            let inbox = try await client.notificationsInbox(limit: 100, beforeID: nil, unreadOnly: true)
            let matchingIDs = inbox.items
                .filter { $0.type == "recommendation"
                    && $0.contentType == rec.contentType
                    && $0.contentId == rec.contentId }
                .map(\.id)
            if matchingIDs.isEmpty {
                await notifications.refresh(client: client)
            } else {
                let badge = try await client.notificationsMarkInboxRead(ids: matchingIDs)
                notifications.apply(badge: badge.badge)
            }
        } catch {
            await notifications.refresh(client: client)
        }
    }
}
