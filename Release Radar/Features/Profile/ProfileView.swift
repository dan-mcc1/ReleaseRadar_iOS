import SwiftUI
import NukeUI

struct ProfileView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(TabNavigationCoordinator.self) private var tabCoordinator
    @State private var viewModel = ProfileViewModel()
    @State private var selectedSection: ProfileSection = .favorites

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
            case .favorites: "of yours"
            case .watchlist: "to watch"
            case .watched: "watched"
            }
        }
    }

    private let posterGridColumns = [
        GridItem(.flexible(), spacing: 12, alignment: .top),
        GridItem(.flexible(), spacing: 12, alignment: .top),
        GridItem(.flexible(), spacing: 12, alignment: .top)
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                LargeTitleHeader(
                    eyebrow: viewModel.summary?.user.username.map { "@\($0)" },
                    title: "You",
                    accent: nil
                ) {
                    HStack(spacing: 8) {
                        NotificationsBellButton()
                        NavigationLink {
                            SettingsView()
                        } label: {
                            Image(systemName: "gearshape")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(BrandTheme.text)
                                .frame(width: 38, height: 38)
                                .background(BrandTheme.surface, in: RoundedRectangle(cornerRadius: 13))
                                .overlay(RoundedRectangle(cornerRadius: 13).stroke(BrandTheme.border, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        if viewModel.isLoading && viewModel.summary == nil {
                            ProgressView().frame(maxWidth: .infinity).padding(.top, 64)
                        } else if let error = viewModel.errorMessage {
                            InlineErrorBanner(message: error) {
                                Task { await viewModel.load(client: env.apiClient) }
                            }
                            .padding(.horizontal, 20)
                        } else if let summary = viewModel.summary {
                            hero(summary: summary)
                            statsStrip(summary: summary).padding(.horizontal, 20)
                            quickLinks
                            sectionChips(summary: summary).padding(.horizontal, 20)
                            sectionContent(for: selectedSection, summary: summary)
                        }
                    }
                    .padding(.bottom, 28)
                }
            }
            .pageBackground()
            .toolbar(.hidden, for: .navigationBar)
            .task { await viewModel.load(client: env.apiClient) }
            .refreshable { await viewModel.load(client: env.apiClient) }
        }
    }

    // MARK: - Hero

    /// Centered avatar, serif username, italic-serif bio, optional emerald
    /// subscription pill — matches the FriendProfileView hero so the two
    /// flows feel visually consistent.
    private func hero(summary: ProfileSummary) -> some View {
        let displayName = summary.user.displayName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasDisplayName = !(displayName ?? "").isEmpty

        return VStack(spacing: 12) {
            AvatarView(username: summary.user.username, avatarKey: summary.user.avatarKey, size: 92)

            VStack(spacing: 2) {
                if hasDisplayName, let displayName {
                    Text(displayName)
                        .font(BrandFont.serif(30))
                        .foregroundStyle(BrandTheme.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    if let username = summary.user.username {
                        Text("@\(username)")
                            .font(BrandFont.sans(13))
                            .foregroundStyle(BrandTheme.textMuted)
                    }
                } else if let username = summary.user.username {
                    Text("@\(username)")
                        .font(BrandFont.serif(30))
                        .foregroundStyle(BrandTheme.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }

            if let bio = summary.user.bio, !bio.isEmpty {
                Text(bio)
                    .font(BrandFont.serif(14, italic: true))
                    .foregroundStyle(BrandTheme.textMuted)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .padding(.horizontal, 24)
            }

            if let tier = summary.user.subscriptionTier, tier != "free" {
                Text(tier.uppercased())
                    .font(BrandFont.mono(10, weight: .semibold))
                    .tracking(1.4)
                    .foregroundStyle(BrandTheme.primaryText)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(BrandTheme.primarySoft, in: Capsule())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 12)
        .padding(.bottom, 6)
    }

    // MARK: - Stats strip

    private func statsStrip(summary: ProfileSummary) -> some View {
        HStack(spacing: 8) {
            statCard(value: "\(watchedTotal(summary))", label: "watched")
            statCard(value: "\(watchlistTotal(summary))", label: "watchlist")
            statCard(value: "\(favoritesTotal(summary))", label: "favorites")
            statCard(value: "\(summary.friends?.count ?? 0)", label: "friends")
        }
    }

    private func statCard(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(BrandFont.serif(22))
                .foregroundStyle(BrandTheme.text)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label.uppercased())
                .font(BrandFont.mono(9, weight: .medium))
                .tracking(1.2)
                .foregroundStyle(BrandTheme.textDim)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .padding(.horizontal, 8)
        .background(BrandTheme.surface, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(BrandTheme.border, lineWidth: 1))
    }

    private func watchedTotal(_ s: ProfileSummary) -> Int {
        guard let w = s.watched else { return 0 }
        return (w.totalMovies ?? w.movies.count) + (w.totalShows ?? w.shows.count)
    }

    private func watchlistTotal(_ s: ProfileSummary) -> Int {
        guard let w = s.watchlist else { return 0 }
        return (w.totalMovies ?? w.movies.count) + (w.totalShows ?? w.shows.count)
    }

    private func favoritesTotal(_ s: ProfileSummary) -> Int {
        guard let f = s.favorites else { return 0 }
        return f.movies.count + f.shows.count + f.collections.count
    }

    // MARK: - Quick links

    /// Six compact tiles in an adaptive grid — same shape as the Discover
    /// hub menu. Each links to the relevant sub-screen.
    private var quickLinks: some View {
        let columns = [GridItem(.adaptive(minimum: 72), spacing: 14, alignment: .top)]
        return LazyVGrid(columns: columns, alignment: .center, spacing: 14) {
            quickLink(title: "Stats", icon: "chart.bar") { StatsView() }
            quickLink(title: "Friends", icon: "person.2") { FriendsView() }
            quickLink(title: "Activity", icon: "sparkles") { ActivityFeedView() }
            quickLink(title: "Shelves", icon: "books.vertical") { ShelvesView() }
            quickLink(title: "Collections", icon: "rectangle.stack") { MyCollectionsView() }
            quickLink(title: "Settings", icon: "gearshape") { SettingsView() }
        }
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private func quickLink<Destination: View>(
        title: String,
        icon: String,
        @ViewBuilder destination: @escaping () -> Destination
    ) -> some View {
        NavigationLink(destination: destination()) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(BrandTheme.primaryText)
                    .frame(width: 44, height: 44)
                    .background(BrandTheme.primarySoft, in: Circle())
                    .overlay(Circle().stroke(BrandTheme.border, lineWidth: 1))
                Text(title)
                    .font(BrandFont.sans(11, weight: .medium))
                    .foregroundStyle(BrandTheme.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Section chips + grid

    private func sectionChips(summary: ProfileSummary) -> some View {
        HStack(spacing: 8) {
            ForEach(ProfileSection.allCases) { section in
                FilterChip(
                    label: section.label,
                    count: count(for: section, summary: summary),
                    isActive: selectedSection == section,
                    action: { selectedSection = section }
                )
            }
            Spacer(minLength: 0)
        }
    }

    private func count(for section: ProfileSection, summary: ProfileSummary) -> Int? {
        switch section {
        case .favorites:
            guard let f = summary.favorites else { return nil }
            return f.movies.count + f.shows.count + f.collections.count
        case .watchlist:
            guard let w = summary.watchlist else { return nil }
            return (w.totalMovies ?? w.movies.count) + (w.totalShows ?? w.shows.count)
        case .watched:
            guard let w = summary.watched else { return nil }
            return (w.totalMovies ?? w.movies.count) + (w.totalShows ?? w.shows.count)
        }
    }

    private func items(for section: ProfileSection, summary: ProfileSummary) -> [MediaItem] {
        switch section {
        case .favorites: summary.favorites?.combined ?? []
        case .watchlist: summary.watchlist?.combined ?? []
        case .watched:   summary.watched?.combined ?? []
        }
    }

    @ViewBuilder
    private func sectionContent(for section: ProfileSection, summary: ProfileSummary) -> some View {
        let items = self.items(for: section, summary: summary)
        let collections = section == .favorites ? (summary.favorites?.collections ?? []) : []

        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .lastTextBaseline) {
                (
                    Text("\(section.label) ").font(BrandFont.serif(20)).foregroundColor(BrandTheme.text)
                    + Text(section.accent).font(BrandFont.serif(20, italic: true)).foregroundColor(BrandTheme.primaryText)
                )
                Spacer()
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

                if let segment = librarySegment(for: section) {
                    viewAllCard(label: viewAllLabel(for: section), segment: segment)
                        .padding(.horizontal, 20)
                        .padding(.top, 6)
                }
            }
        }
    }

    /// Maps a profile section to the Library segment that hosts the
    /// full list. `nil` for sections (Favorites) that don't have a
    /// dedicated full-list view in the Library tab.
    private func librarySegment(for section: ProfileSection) -> LibraryViewModel.Segment? {
        switch section {
        case .watchlist: .watchlist
        case .watched:   .watched
        case .favorites: nil
        }
    }

    private func viewAllLabel(for section: ProfileSection) -> String {
        switch section {
        case .watchlist: "View all watchlist"
        case .watched:   "View all watched"
        case .favorites: ""
        }
    }

    /// Editorial surface card that jumps the user over to the Library
    /// tab (instead of pushing a duplicate Library onto Profile's stack).
    /// The coordinator carries the desired segment so Library can snap
    /// straight to Watchlist or Watched.
    private func viewAllCard(label: String, segment: LibraryViewModel.Segment) -> some View {
        Button {
            tabCoordinator.openLibrary(segment: segment)
        } label: {
            HStack(spacing: 8) {
                Spacer()
                Text(label)
                    .font(BrandFont.sans(13, weight: .semibold))
                    .foregroundStyle(BrandTheme.primaryText)
                Image(systemName: "arrow.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(BrandTheme.primaryText)
                Spacer()
            }
            .padding(.vertical, 12)
            .background(BrandTheme.surface, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(BrandTheme.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    /// 3-column grid of favorited collections, only rendered under the
    /// Favorites chip.
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
}

@Observable @MainActor
final class ProfileViewModel {
    var summary: ProfileSummary?
    var isLoading = false
    var errorMessage: String?

    func load(client: APIClient) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            summary = try await client.userProfileSummaryDecoded()
        } catch is CancellationError {
            // ignore
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
