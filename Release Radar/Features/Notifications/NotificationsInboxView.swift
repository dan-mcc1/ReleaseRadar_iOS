import SwiftUI
import NukeUI

/// Bell-icon entry point that pushes the notifications inbox. Renders a
/// small red dot in the corner when `NotificationsModel.total > 0` so the
/// user knows there's something waiting.
struct NotificationsBellButton: View {
    @Environment(NotificationsModel.self) private var notifications

    var body: some View {
        NavigationLink {
            NotificationsInboxView()
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "bell")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(BrandTheme.text)
                    .frame(width: 38, height: 38)
                    .background(BrandTheme.surface, in: RoundedRectangle(cornerRadius: 13))
                    .overlay(RoundedRectangle(cornerRadius: 13).stroke(BrandTheme.border, lineWidth: 1))
                if notifications.total > 0 {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 9, height: 9)
                        .overlay(Circle().stroke(BrandTheme.bg, lineWidth: 2))
                        .offset(x: 3, y: -3)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

/// Displays the user's notification inbox (`/notifications/inbox`) and lets
/// them mark items read individually or all at once. Tapping a notification
/// deep-links into the related show/movie/episode when possible. Reading an
/// item updates `NotificationsModel.total` immediately so the tab badge and
/// home-screen badge stay in sync.
struct NotificationsInboxView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(NotificationsModel.self) private var notifications
    @State private var items: [NotificationEntry] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        // Use a List so `.swipeActions` actually fires on each row. The
        // editorial styling is reapplied via plain list style, hidden row
        // backgrounds / separators, and zero row insets so the cards still
        // look custom.
        List {
            if !items.isEmpty {
                Section {
                    actionButtons
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
            }

            Section {
                if isLoading && items.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 32)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                } else if let error = errorMessage, items.isEmpty {
                    InlineErrorBanner(message: error) { Task { await load() } }
                        .padding(.horizontal, 16)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                } else if items.isEmpty {
                    ContentUnavailableView(
                        "No notifications yet",
                        systemImage: "bell.slash",
                        description: Text("New releases, friend requests, and recommendations will appear here.")
                    )
                    .padding(.top, 32)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                } else {
                    ForEach(items) { item in
                        row(for: item)
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .pageBackground()
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
    }

    /// Two pill buttons placed between the header and the list. Read sits
    /// on the left, Clear all on the right. Read is disabled when nothing
    /// is unread; Clear all is always available so the user can wipe even
    /// already-read notifications.
    private var actionButtons: some View {
        HStack(spacing: 8) {
            Button {
                Task { await markAllRead() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Mark all read")
                        .font(BrandFont.sans(13, weight: .semibold))
                }
                .foregroundStyle(hasUnread ? BrandTheme.primaryText : BrandTheme.textMuted)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(BrandTheme.primarySoft.opacity(hasUnread ? 1 : 0.5), in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(!hasUnread)

            Button {
                Task { await clearAll() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "trash")
                    Text("Clear all")
                        .font(BrandFont.sans(13, weight: .semibold))
                }
                .foregroundStyle(BrandTheme.text)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(BrandTheme.surface, in: Capsule())
                .overlay(Capsule().stroke(BrandTheme.border, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }

    private var hasUnread: Bool { notifications.total > 0 }

    /// Renders one inbox row. The whole row is a tap target — tapping it
    /// marks the notification as read and (when applicable) pushes the
    /// matching media detail view. A trailing-edge swipe exposes a Delete
    /// action that removes the row via `/notifications/inbox/delete`.
    ///
    /// The NavigationLink is rendered with an empty label inside a ZStack
    /// behind the card so List doesn't draw its default disclosure chevron.
    @ViewBuilder
    private func row(for item: NotificationEntry) -> some View {
        ZStack {
            if hasDestination(for: item) {
                NavigationLink {
                    makeDestination(for: item)
                        .task { await markRead(item) }
                } label: { EmptyView() }
                .opacity(0)
            }
            Button {
                Task { await markRead(item) }
            } label: {
                card(for: item)
            }
            .buttonStyle(.plain)
            .allowsHitTesting(!hasDestination(for: item))
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                Task { await delete(item) }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func card(for item: NotificationEntry) -> some View {
        HStack(alignment: .top, spacing: 12) {
            iconBadge(for: item)
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .top) {
                    Text(item.title)
                        .font(BrandFont.sans(14, weight: .semibold))
                        .foregroundStyle(BrandTheme.text)
                        .lineLimit(2)
                    Spacer(minLength: 6)
                    if item.isUnread {
                        Circle()
                            .fill(BrandTheme.primary)
                            .frame(width: 7, height: 7)
                            .padding(.top, 5)
                    }
                }
                if let body = item.body, !body.isEmpty {
                    Text(body)
                        .font(BrandFont.sans(12.5))
                        .foregroundStyle(BrandTheme.textMuted)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                }
                Text(timeLabel(for: item))
                    .font(BrandFont.mono(10, weight: .medium))
                    .tracking(0.4)
                    .foregroundStyle(BrandTheme.textDim)
            }
            posterThumbnail(for: item)
        }
        .padding(12)
        .background(
            item.isUnread ? BrandTheme.primarySoft.opacity(0.5) : BrandTheme.surface,
            in: RoundedRectangle(cornerRadius: 12)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(item.isUnread ? .clear : BrandTheme.border, lineWidth: 1)
        )
    }

    /// Colored circular badge on the left of each row. SF Symbol chosen
    /// by notification type so the user can scan the inbox at a glance.
    private func iconBadge(for item: NotificationEntry) -> some View {
        let (symbol, tint) = iconStyle(for: item.type)
        return Image(systemName: symbol)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: 32, height: 32)
            .background(tint.opacity(0.15), in: Circle())
    }

    @ViewBuilder
    private func posterThumbnail(for item: NotificationEntry) -> some View {
        if let urlString = item.imageUrl, let url = URL(string: urlString) {
            LazyImage(url: url) { state in
                if let image = state.image {
                    image.resizable().scaledToFill()
                } else {
                    BrandTheme.surface2
                }
            }
            .frame(width: 36, height: 54)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }

    // MARK: - Destinations

    /// True if we know how to deep-link to the related content. Drives
    /// whether the row is rendered as a NavigationLink or a plain Button.
    private func hasDestination(for item: NotificationEntry) -> Bool {
        guard let typeRaw = item.contentType, let _ = ContentType(rawValue: typeRaw),
              item.contentId != nil else { return false }
        return true
    }

    private func makeDestination(for item: NotificationEntry) -> AnyView {
        guard let typeRaw = item.contentType,
              let type = ContentType(rawValue: typeRaw),
              let id = item.contentId else {
            return AnyView(EmptyView())
        }
        // Backend gives us `episode_id` (a DB row id) but EpisodeInfoView
        // is keyed by episode_number — until the payload includes it, fall
        // back to the show's detail page so the user lands somewhere
        // related.
        return AnyView(
            MediaDetailView(item: MediaItem(
                id: id,
                contentType: type,
                title: item.title,
                posterPath: nil
            ))
        )
    }

    // MARK: - Styling per type

    private func iconStyle(for type: String) -> (String, Color) {
        switch type {
        case "season_premiere", "season_finale":
            return ("tv", BrandTheme.primaryText)
        case "trailer":
            return ("play.rectangle.fill", Color(hex: 0xFBBF24))
        case "streaming_change":
            return ("dot.radiowaves.left.and.right", Color(hex: 0x60A5FA))
        case "recommendation", "friend_rec":
            return ("paperplane.fill", BrandTheme.primaryText)
        case "friend_request":
            return ("person.fill.badge.plus", BrandTheme.primaryText)
        case "review_like":
            return ("heart.fill", Color(hex: 0xF472B6))
        case "episode_air":
            return ("bell.fill", BrandTheme.primaryText)
        case "community_invite":
            return ("person.3.fill", Color(hex: 0xA78BFA))
        default:
            return ("bell", BrandTheme.primaryText)
        }
    }

    private func timeLabel(for item: NotificationEntry) -> String {
        TimeAgo.format(item.createdAt) ?? "just now"
    }

    // MARK: - Networking

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let response = try await env.apiClient.notificationsInbox(limit: 50, beforeID: nil, unreadOnly: false)
            items = response.items
            notifications.apply(badge: response.badge)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func markRead(_ item: NotificationEntry) async {
        guard item.isUnread else { return }
        // Optimistic flip
        if let idx = items.firstIndex(where: { $0.id == item.id }) {
            items[idx] = NotificationEntry.copy(of: item, readAt: ISO8601DateFormatter().string(from: Date()))
            notifications.apply(badge: max(0, notifications.total - 1))
        }
        do {
            let badge = try await env.apiClient.notificationsMarkInboxRead(ids: [item.id])
            notifications.apply(badge: badge.badge)
        } catch {
            // Roll back the local flip on failure.
            if let idx = items.firstIndex(where: { $0.id == item.id }) {
                items[idx] = item
            }
            await notifications.refresh(client: env.apiClient)
        }
    }

    /// Optimistically remove a single notification, then commit on the
    /// server. Rolls back if the request fails.
    private func delete(_ item: NotificationEntry) async {
        let snapshot = items
        items.removeAll { $0.id == item.id }
        if item.isUnread {
            notifications.apply(badge: max(0, notifications.total - 1))
        }
        do {
            let badge = try await env.apiClient.notificationsDeleteInbox(ids: [item.id])
            notifications.apply(badge: badge.badge)
        } catch {
            items = snapshot
            await notifications.refresh(client: env.apiClient)
        }
    }

    /// Wipe every row from the inbox, including ones that were already read.
    private func clearAll() async {
        let snapshot = items
        items = []
        notifications.apply(badge: 0)
        do {
            let badge = try await env.apiClient.notificationsDeleteInbox(ids: nil)
            notifications.apply(badge: badge.badge)
        } catch {
            items = snapshot
            await notifications.refresh(client: env.apiClient)
        }
    }

    private func markAllRead() async {
        let now = ISO8601DateFormatter().string(from: Date())
        let snapshot = items
        items = items.map { $0.isUnread ? NotificationEntry.copy(of: $0, readAt: now) : $0 }
        notifications.apply(badge: 0)
        do {
            let badge = try await env.apiClient.notificationsMarkInboxRead(ids: nil)
            notifications.apply(badge: badge.badge)
        } catch {
            items = snapshot
            await notifications.refresh(client: env.apiClient)
        }
    }
}

// MARK: - Memberwise copy helper
//
// `NotificationEntry`'s synthesized init is internal; this convenience
// lets the inbox view flip the read state optimistically without
// re-declaring every field.

private extension NotificationEntry {
    static func copy(of original: NotificationEntry, readAt: String?) -> NotificationEntry {
        let json: [String: Any?] = [
            "id": original.id,
            "type": original.type,
            "title": original.title,
            "body": original.body,
            "content_type": original.contentType,
            "content_id": original.contentId,
            "image_url": original.imageUrl,
            "season_number": original.seasonNumber,
            "episode_id": original.episodeId,
            "video_key": original.videoKey,
            "read_at": readAt,
            "created_at": original.createdAt
        ]
        let cleaned = json.compactMapValues { $0 }
        guard let data = try? JSONSerialization.data(withJSONObject: cleaned),
              let copy = try? JSONDecoder().decode(NotificationEntry.self, from: data)
        else { return original }
        return copy
    }
}
