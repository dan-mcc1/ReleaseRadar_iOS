import SwiftUI
import NukeUI

struct FriendProfileView: View {
    let username: String
    @Environment(AppEnvironment.self) private var env
    @State private var viewModel = FriendProfileViewModel()
    @State private var selectedSection: ProfileSection = .favorites
    @State private var showingReport = false
    @State private var reportReason: String = "spam"
    @State private var reportMessage: String = ""

    enum ProfileSection: String, CaseIterable, Identifiable {
        case favorites, watchlist, watched
        var id: String { rawValue }
        var label: String {
            switch self {
            case .favorites: "Favorites"
            case .watchlist: "Watchlist"
            case .watched: "Watched"
            }
        }
        var accent: String {
            switch self {
            case .favorites: "of all time"
            case .watchlist: "to watch"
            case .watched: "watched"
            }
        }
        var caption: String? {
            switch self {
            case .favorites: nil
            case .watchlist: "NEXT UP"
            case .watched: "MOST RECENT"
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if viewModel.isLoading {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, 64)
                } else if let error = viewModel.errorMessage {
                    InlineErrorBanner(message: error) {
                        Task { await viewModel.load(username: username, client: env.apiClient) }
                    }
                    .padding(.horizontal, 20)
                } else if viewModel.blocked {
                    blockedCard
                        .padding(.horizontal, 20)
                } else if let profile = viewModel.profile {
                    hero(profile: profile)

                    if canSeeDetails(profile) {
                        statsStrip(profile: profile)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 18)

                        sectionChips(profile: profile)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 14)

                        sectionScroller(for: selectedSection, profile: profile)
                            .padding(.bottom, 24)
                    } else {
                        privateProfile(profile: profile)
                            .padding(.horizontal, 20)
                            .padding(.top, 8)
                    }
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .pageBackground()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let profile = viewModel.profile {
                ToolbarItem(placement: .topBarTrailing) {
                    profileMenu(profile: profile)
                }
            }
        }
        .task { await viewModel.load(username: username, client: env.apiClient) }
        .sheet(isPresented: $showingReport) {
            reportSheet
        }
    }

    private func canSeeDetails(_ profile: PublicProfile) -> Bool {
        let visibility = profile.profileVisibility ?? "public"
        if visibility == "public" { return true }
        if visibility == "friends_only" && (profile.isFriend ?? false) { return true }
        return false
    }

    // MARK: - Hero

    /// Centered avatar, serif `@username`, italic-serif bio, and the
    /// primary relationship action pill (Add friend / Friends / Accept
    /// request etc.). Replaces the old gradient banner with the editorial
    /// hero treatment used across the rest of the redesigned screens.
    private func hero(profile: PublicProfile) -> some View {
        let displayName = profile.displayName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasDisplayName = !(displayName ?? "").isEmpty
        let handle = "@\(profile.username ?? username)"

        return VStack(spacing: 12) {
            AvatarView(username: profile.username, avatarKey: profile.avatarKey, size: 92)

            VStack(spacing: 2) {
                if hasDisplayName, let displayName {
                    Text(displayName)
                        .font(BrandFont.serif(30))
                        .foregroundStyle(BrandTheme.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text(handle)
                        .font(BrandFont.sans(13))
                        .foregroundStyle(BrandTheme.textMuted)
                } else {
                    Text(handle)
                        .font(BrandFont.serif(30))
                        .foregroundStyle(BrandTheme.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }

            if let bio = profile.bio, !bio.isEmpty {
                Text(bio)
                    .font(BrandFont.serif(14, italic: true))
                    .foregroundStyle(BrandTheme.textMuted)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .padding(.horizontal, 24)
            }

            relationshipActions(profile: profile)
                .padding(.top, 6)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .padding(.horizontal, 20)
    }

    private func relationshipActions(profile: PublicProfile) -> some View {
        HStack(spacing: 8) {
            if profile.isFriend == true {
                pill(label: "Friends", icon: "checkmark", style: .emeraldSoft, action: nil)
            } else if profile.pendingRequestId != nil {
                pill(label: "Request sent", icon: "paperplane", style: .surface, action: nil)
            } else if profile.incomingRequestId != nil {
                pill(label: "Accept request", icon: "checkmark", style: .emerald) {
                    Task { await viewModel.respondIncoming(accept: true, client: env.apiClient) }
                }
            } else {
                pill(label: "Add friend", icon: "person.crop.circle.badge.plus", style: .emerald) {
                    Task { await viewModel.sendRequest(client: env.apiClient) }
                }
            }
        }
    }

    /// Pill button used for the relationship action. `nil` action makes
    /// the pill non-interactive (e.g. "Friends" status badge).
    private func pill(
        label: String,
        icon: String,
        style: PillStyle,
        action: (() -> Void)?
    ) -> some View {
        let content = HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 12, weight: .semibold))
            Text(label).font(BrandFont.sans(13, weight: .semibold))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 9)
        .foregroundStyle(style.foreground)
        .background(style.background, in: Capsule())
        .overlay(Capsule().stroke(style.borderColor, lineWidth: style.borderWidth))

        return Group {
            if let action {
                Button(action: action) { content }.buttonStyle(.plain)
            } else {
                content
            }
        }
    }

    private enum PillStyle {
        case emerald, emeraldSoft, surface
        var foreground: Color {
            switch self {
            case .emerald: .white
            case .emeraldSoft: BrandTheme.primaryText
            case .surface: BrandTheme.text
            }
        }
        var background: Color {
            switch self {
            case .emerald: BrandTheme.primary
            case .emeraldSoft: BrandTheme.primarySoft
            case .surface: BrandTheme.surface
            }
        }
        var borderColor: Color {
            switch self {
            case .emerald, .emeraldSoft: .clear
            case .surface: BrandTheme.border
            }
        }
        var borderWidth: CGFloat {
            switch self {
            case .emerald, .emeraldSoft: 0
            case .surface: 1
            }
        }
    }

    // MARK: - Stats strip

    private func statsStrip(profile: PublicProfile) -> some View {
        HStack(spacing: 8) {
            statCard(value: "\(profile.watched?.combined.count ?? 0)", label: "watched")
            statCard(value: "\(profile.watchlist?.combined.count ?? 0)", label: "watchlist")
            statCard(value: "\(profile.favorites?.combined.count ?? 0)", label: "favorites")
        }
    }

    private func statCard(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(BrandFont.serif(22))
                .foregroundStyle(BrandTheme.text)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label.uppercased())
                .font(BrandFont.mono(9, weight: .medium))
                .tracking(1.2)
                .foregroundStyle(BrandTheme.textDim)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(BrandTheme.surface, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(BrandTheme.border, lineWidth: 1))
    }

    // MARK: - Section chips + scroller

    private func sectionChips(profile: PublicProfile) -> some View {
        HStack(spacing: 8) {
            ForEach(ProfileSection.allCases) { section in
                FilterChip(
                    label: section.label,
                    count: count(for: section, profile: profile),
                    isActive: selectedSection == section,
                    action: { selectedSection = section }
                )
            }
            Spacer(minLength: 0)
        }
    }

    private func count(for section: ProfileSection, profile: PublicProfile) -> Int? {
        switch section {
        case .favorites: profile.favorites?.combined.count
        case .watchlist: profile.watchlist?.combined.count
        case .watched:   profile.watched?.combined.count
        }
    }

    private func items(for section: ProfileSection, profile: PublicProfile) -> [MediaItem] {
        switch section {
        case .favorites: profile.favorites?.combined ?? []
        case .watchlist: profile.watchlist?.combined ?? []
        case .watched:   profile.watched?.combined ?? []
        }
    }

    private let posterGridColumns = [
        GridItem(.flexible(), spacing: 12, alignment: .top),
        GridItem(.flexible(), spacing: 12, alignment: .top),
        GridItem(.flexible(), spacing: 12, alignment: .top)
    ]

    @ViewBuilder
    private func sectionScroller(for section: ProfileSection, profile: PublicProfile) -> some View {
        let items = self.items(for: section, profile: profile)
        let collections = section == .favorites ? (profile.favorites?.collections ?? []) : []

        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .lastTextBaseline) {
                (
                    Text("\(section.label) ").font(BrandFont.serif(20)).foregroundColor(BrandTheme.text)
                    + Text(section.accent).font(BrandFont.serif(20, italic: true)).foregroundColor(BrandTheme.primaryText)
                )
                Spacer()
                if let caption = section.caption {
                    Text(caption)
                        .font(BrandFont.mono(10, weight: .medium))
                        .tracking(1.2)
                        .foregroundStyle(BrandTheme.textDim)
                }
            }
            .padding(.horizontal, 20)

            if items.isEmpty && collections.isEmpty {
                Text("Nothing here yet")
                    .font(BrandFont.sans(13))
                    .foregroundStyle(BrandTheme.textMuted)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
            } else {
                if !items.isEmpty {
                    LazyVGrid(columns: posterGridColumns, spacing: 18) {
                        ForEach(items) { item in
                            NavigationLink {
                                MediaDetailView(item: item)
                            } label: {
                                posterCell(item: item)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                }

                if !collections.isEmpty {
                    collectionsGrid(collections)
                        .padding(.top, items.isEmpty ? 0 : 18)
                }
            }
        }
    }

    /// `Favorite collections` row that appears beneath the Favorites grid
    /// when the friend has favorited at least one TMDB collection.
    private func collectionsGrid(_ collections: [SearchedCollection]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .lastTextBaseline) {
                (
                    Text("Favorite ").font(BrandFont.serif(20)).foregroundColor(BrandTheme.text)
                    + Text("collections").font(BrandFont.serif(20, italic: true)).foregroundColor(BrandTheme.primaryText)
                )
                Spacer()
            }
            .padding(.horizontal, 20)

            LazyVGrid(columns: posterGridColumns, spacing: 18) {
                ForEach(collections) { collection in
                    NavigationLink {
                        CollectionInfoView(collectionID: collection.id)
                    } label: {
                        collectionCell(collection)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private func collectionCell(_ collection: SearchedCollection) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Color.clear
                .aspectRatio(2.0 / 3.0, contentMode: .fit)
                .overlay {
                    LazyImage(url: TMDBImage.poster(collection.posterPath)) { state in
                        if let image = state.image {
                            image.resizable().scaledToFill()
                        } else {
                            BrandTheme.surface2
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            Text(collection.name ?? "—")
                .font(BrandFont.sans(12, weight: .semibold))
                .foregroundStyle(BrandTheme.text)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// Grid-sized poster + title. Adds a TMDB-rating chip in the
    /// top-left (when `voteAverage` is set) and the `MiniWatchButtons`
    /// overlay in the bottom-right.
    private func posterCell(item: MediaItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Color.clear
                .aspectRatio(2.0 / 3.0, contentMode: .fit)
                .overlay {
                    LazyImage(url: TMDBImage.poster(item.posterPath)) { state in
                        if let image = state.image {
                            image.resizable().scaledToFill()
                        } else if state.error != nil {
                            BrandTheme.surface2.overlay(
                                Image(systemName: "photo").foregroundStyle(.secondary)
                            )
                        } else {
                            BrandTheme.surface2.overlay(ProgressView())
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(alignment: .topLeading) {
                    ratingBadge(for: item)
                }
                .overlay(alignment: .topTrailing) {
                    CurrentlyWatchingBadge(type: item.contentType, id: item.id)
                        .padding(6)
                }
                .overlay(alignment: .bottomTrailing) {
                    MiniWatchButtons(type: item.contentType, id: item.id)
                        .padding(6)
                }

            Text(item.title)
                .font(BrandFont.sans(12, weight: .semibold))
                .foregroundStyle(BrandTheme.text)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// Translucent dark pill in the top-left of the poster: gold star +
    /// 1-decimal TMDB rating. Hidden when the backend doesn't return a
    /// rating (e.g. unreleased titles).
    @ViewBuilder
    private func ratingBadge(for item: MediaItem) -> some View {
        if let rating = item.voteAverage, rating > 0 {
            HStack(spacing: 3) {
                Image(systemName: "star.fill")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(Color(hex: 0xFBBF24))
                Text(String(format: "%.1f", rating))
                    .font(BrandFont.mono(10, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color.black.opacity(0.6), in: Capsule())
            .padding(6)
        }
    }

    // MARK: - Edge cases

    private func privateProfile(profile: PublicProfile) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "lock.fill")
                .font(.title)
                .foregroundStyle(BrandTheme.primaryText)
            Text("This profile is private")
                .font(BrandFont.sans(15, weight: .semibold))
                .foregroundStyle(BrandTheme.text)
            Text("Become friends to see their library.")
                .font(BrandFont.sans(13))
                .foregroundStyle(BrandTheme.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(BrandTheme.surface, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(BrandTheme.border, lineWidth: 1))
    }

    private var blockedCard: some View {
        VStack(spacing: 10) {
            Image(systemName: "hand.raised.fill").font(.title).foregroundStyle(.red)
            Text("You've blocked this user")
                .font(BrandFont.sans(15, weight: .semibold))
                .foregroundStyle(BrandTheme.text)
            Button("Unblock") {
                Task { await viewModel.unblock(client: env.apiClient) }
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(BrandTheme.surface, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(BrandTheme.border, lineWidth: 1))
    }

    // MARK: - Moderation menu

    /// Trailing ellipsis menu for Unfriend / Block / Report — pulled out
    /// of the hero so the public-facing surface stays clean.
    private func profileMenu(profile: PublicProfile) -> some View {
        Menu {
            if profile.isFriend == true {
                Button(role: .destructive) {
                    Task { await viewModel.removeFriend(client: env.apiClient) }
                } label: { Label("Unfriend", systemImage: "person.fill.xmark") }
            }
            Button(role: .destructive) {
                Task { await viewModel.block(client: env.apiClient) }
            } label: { Label("Block", systemImage: "hand.raised") }
            Button {
                showingReport = true
            } label: { Label("Report", systemImage: "flag") }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(BrandTheme.text)
                .frame(width: 32, height: 32)
                .background(BrandTheme.surface, in: Circle())
                .overlay(Circle().stroke(BrandTheme.border, lineWidth: 1))
        }
    }

    private var reportSheet: some View {
        NavigationStack {
            Form {
                Section("Reason") {
                    Picker("Reason", selection: $reportReason) {
                        Text("Spam").tag("spam")
                        Text("Harassment").tag("harassment")
                        Text("Hate speech").tag("hate_speech")
                        Text("Inappropriate content").tag("inappropriate_content")
                        Text("Misinformation").tag("misinformation")
                        Text("Other").tag("other")
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
                Section("Message (optional)") {
                    TextField("Additional context", text: $reportMessage, axis: .vertical).lineLimit(3...6)
                }
            }
            .navigationTitle("Report user")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showingReport = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Submit") {
                        Task {
                            await viewModel.report(reason: reportReason, message: reportMessage, client: env.apiClient)
                            showingReport = false
                        }
                    }
                }
            }
        }
    }
}

@Observable @MainActor
final class FriendProfileViewModel {
    var profile: PublicProfile?
    var blocked = false
    var isLoading = false
    var errorMessage: String?

    func load(username: String, client: APIClient) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            profile = try await client.userPublicProfileDecoded(username: username)
            blocked = profile?.blockedByViewer ?? false
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func sendRequest(client: APIClient) async {
        guard let username = profile?.username else { return }
        do {
            try await client.friendsSendRequest(addresseeUsername: username)
            await reload(client: client)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func respondIncoming(accept: Bool, client: APIClient) async {
        guard let id = profile?.incomingRequestId else { return }
        do {
            try await client.friendsRespond(friendshipID: id, accept: accept)
            await reload(client: client)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func removeFriend(client: APIClient) async {
        guard let id = profile?.id else { return }
        do {
            try await client.friendsRemove(friendID: id)
            await reload(client: client)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func block(client: APIClient) async {
        guard let id = profile?.id else { return }
        do {
            _ = try await client.moderationBlock(userID: id)
            blocked = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func unblock(client: APIClient) async {
        guard let id = profile?.id else { return }
        do {
            try await client.moderationUnblock(userID: id)
            blocked = false
            await reload(client: client)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func report(reason: String, message: String, client: APIClient) async {
        guard let id = profile?.id else { return }
        do {
            try await client.moderationReport(
                reportedType: "user",
                reportedID: id,
                reason: reason,
                message: message.isEmpty ? nil : message
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func reload(client: APIClient) async {
        guard let username = profile?.username else { return }
        await load(username: username, client: client)
    }
}
