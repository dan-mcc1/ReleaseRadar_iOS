import SwiftUI
import NukeUI

/// Full group page reached via slug. Four tabs across the top:
/// `Discussion` (posts feed + composer), `Titles` (shared movies and shows),
/// `Members` (member list with roles), and `Settings` (admin-only edits and
/// join/leave button for everyone else).
struct GroupDetailView: View {
    let slug: String
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = GroupDetailViewModel()
    @State private var tab: Tab = .discussion
    @State private var showCompose = false
    @State private var showInvite = false
    /// Edit mode for the Titles tab — toggled by the small `Edit` chip in
    /// the section header. When on, each poster gains a destructive `×`
    /// affordance so the viewer can remove items they're allowed to.
    @State private var titlesEditing = false
    /// Debounced search query for the "Add a title" panel above the Titles
    /// grid. Cleared whenever the panel collapses.
    @State private var titleSearchQuery = ""

    enum Tab: String, CaseIterable, Identifiable {
        case discussion, titles, members, settings
        var id: String { rawValue }
        var label: String {
            switch self {
            case .discussion: "Discussion"
            case .titles: "Titles"
            case .members: "Members"
            case .settings: "Settings"
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if viewModel.isLoading && viewModel.community == nil {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, 64)
                } else if let error = viewModel.errorMessage, viewModel.community == nil {
                    InlineErrorBanner(message: error) { Task { await viewModel.load(client: env.apiClient, slug: slug) } }
                        .padding(.horizontal, 16)
                } else if let community = viewModel.community {
                    header(community: community)

                    tabSelector

                    Group {
                        switch tab {
                        case .discussion: discussionSection(community: community)
                        case .titles: titlesSection(community: community)
                        case .members: membersSection(community: community)
                        case .settings:
                            GroupSettingsView(
                                community: community,
                                onUpdated: { updated in viewModel.community = updated },
                                onDeleted: { dismiss() }
                            )
                            .frame(minHeight: 500)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            .padding(.bottom, 24)
        }
        .pageBackground()
        .navigationTitle(viewModel.community?.name ?? "Group")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let community = viewModel.community {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        if community.isOwnerOrAdmin {
                            Button { showInvite = true } label: { Label("Invite member", systemImage: "person.crop.circle.badge.plus") }
                        }
                        if community.isMember && community.viewerRole != "owner" {
                            Button(role: .destructive) {
                                Task { await viewModel.leave(client: env.apiClient) }
                            } label: { Label("Leave group", systemImage: "rectangle.portrait.and.arrow.right") }
                        }
                        if !community.isMember && community.isPublic {
                            Button {
                                Task { await viewModel.join(client: env.apiClient) }
                            } label: { Label("Join group", systemImage: "person.badge.plus") }
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                }
            }
        }
        .sheet(isPresented: $showCompose) {
            if let community = viewModel.community {
                PostComposerSheet(community: community) { newPost in
                    viewModel.prepend(post: newPost)
                }
            }
        }
        .sheet(isPresented: $showInvite) {
            if let community = viewModel.community {
                InviteMemberSheet(community: community)
            }
        }
        .task { await viewModel.load(client: env.apiClient, slug: slug) }
        .refreshable { await viewModel.refreshSelectedTab(client: env.apiClient) }
    }

    // MARK: - Header

    private func header(community: Community) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .bottomLeading) {
                Rectangle()
                    .fill(bannerColor(community.bannerColor))
                    .frame(height: 130)

                HStack(alignment: .bottom, spacing: 12) {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.white.opacity(0.18))
                        .frame(width: 60, height: 60)
                        .overlay(
                            Text(initials(community.name))
                                .font(BrandFont.serif(22))
                                .foregroundStyle(.white)
                        )
                    VStack(alignment: .leading, spacing: 2) {
                        Text(community.name)
                            .font(BrandFont.serif(24))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                        Text(verbatim: "\(community.memberCount) members · \(community.visibility.capitalized)")
                            .font(BrandFont.mono(10, weight: .semibold))
                            .tracking(0.4)
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    Spacer(minLength: 0)
                }
                .padding(16)
            }
            if let description = community.description, !description.isEmpty {
                Text(description)
                    .font(BrandFont.sans(13.5))
                    .foregroundStyle(BrandTheme.text.opacity(0.85))
                    .padding(.horizontal, 16)
            }
            if !community.isMember, community.isPublic {
                Button {
                    Task { await viewModel.join(client: env.apiClient) }
                } label: {
                    Text("Join group")
                        .font(BrandFont.sans(13, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(BrandTheme.primary, in: Capsule())
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
            }
        }
    }

    private var tabSelector: some View {
        // Settings only appears for owners and admins — regular members and
        // non-members shouldn't see the privileged controls.
        let tabs: [Tab] = {
            var ts: [Tab] = [.discussion, .titles, .members]
            if viewModel.community?.isOwnerOrAdmin == true {
                ts.append(.settings)
            }
            return ts
        }()
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(tabs) { t in
                    FilterChip(
                        label: t.label,
                        count: nil,
                        isActive: tab == t,
                        action: { tab = t; Task { await viewModel.refreshSelectedTab(client: env.apiClient, requested: t) } }
                    )
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Discussion

    @ViewBuilder
    private func discussionSection(community: Community) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if community.isMember {
                Button { showCompose = true } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.pencil")
                            .foregroundStyle(BrandTheme.primaryText)
                        Text("Start a new post…")
                            .font(BrandFont.sans(13))
                            .foregroundStyle(BrandTheme.textMuted)
                        Spacer(minLength: 0)
                    }
                    .padding(12)
                    .background(BrandTheme.surface, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(BrandTheme.border, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }

            if viewModel.posts.isEmpty {
                ContentUnavailableView(
                    "No posts yet",
                    systemImage: "bubble.left.and.bubble.right",
                    description: Text(community.isMember ? "Start the first conversation." : "Members are quiet so far.")
                )
                .padding(.top, 16)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(viewModel.posts) { post in
                        NavigationLink {
                            GroupPostDetailView(communitySlug: slug, postID: post.id)
                        } label: {
                            PostCard(post: post)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Titles

    @ViewBuilder
    private func titlesSection(community: Community) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            if community.viewerCanEditMedia {
                titleSearchPanel(community: community)
            }

            if let media = viewModel.media,
               media.movies.count + media.shows.count > 0 {
                if !viewModel.hasLoadedWatchStatuses {
                    progressLoadingCard()
                } else if let progress = viewModel.titlesProgress(media: media) {
                    progressCard(progress: progress)
                }
            }

            if let media = viewModel.media,
               media.movies.isEmpty, media.shows.isEmpty {
                ContentUnavailableView(
                    "No titles yet",
                    systemImage: "tv",
                    description: Text(community.viewerCanEditMedia
                        ? "Use the search above to add your first title."
                        : "Shared movies and shows will live here.")
                )
                .padding(.top, 4)
            } else if let media = viewModel.media {
                let canRemoveAny = viewerCanRemoveAny(community: community)

                if !media.shows.isEmpty {
                    titlesSectionHeader(
                        title: "TV Shows · \(media.shows.count)",
                        // First visible section hosts the Edit chip.
                        showsEditButton: canRemoveAny
                    )
                    titlesGrid(
                        items: media.shows.map {
                            TitleItem(id: $0.id, contentID: $0.contentId, name: $0.name, poster: $0.posterPath, type: .tv, rating: $0.voteAverage)
                        },
                        community: community
                    )
                }
                if !media.movies.isEmpty {
                    titlesSectionHeader(
                        title: "Movies · \(media.movies.count)",
                        // Only show the Edit chip here if Shows section
                        // is hidden — otherwise it's already up top.
                        showsEditButton: media.shows.isEmpty && canRemoveAny
                    )
                    titlesGrid(
                        items: media.movies.map {
                            TitleItem(id: $0.id, contentID: $0.contentId, name: $0.title, poster: $0.posterPath, type: .movie, rating: $0.voteAverage)
                        },
                        community: community
                    )
                }
            } else {
                ProgressView().frame(maxWidth: .infinity).padding(.top, 16)
            }
        }
    }

    /// Header above each titles sub-grid (Shows / Movies). The first
    /// visible section also hosts the Edit chip that toggles remove mode.
    @ViewBuilder
    private func titlesSectionHeader(title: String, showsEditButton: Bool) -> some View {
        HStack {
            Text(title)
                .font(BrandFont.mono(10, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(BrandTheme.textMuted)
            Spacer()
            if showsEditButton {
                Button {
                    titlesEditing.toggle()
                } label: {
                    Text(titlesEditing ? "DONE" : "EDIT")
                        .font(BrandFont.mono(10, weight: .semibold))
                        .tracking(1.0)
                        .foregroundStyle(titlesEditing ? BrandTheme.primaryText : BrandTheme.text)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule().fill(titlesEditing ? BrandTheme.primarySoft : BrandTheme.surface)
                        )
                        .overlay(
                            Capsule().stroke(titlesEditing ? Color.clear : BrandTheme.border, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// True if the viewer can remove any item from this group's media list.
    /// Owners/admins always can; members can remove their own additions
    /// (or anything when `members_can_edit_media`).
    private func viewerCanRemoveAny(community: Community) -> Bool {
        community.isOwnerOrAdmin || community.isMember
    }

    /// Decides whether the viewer is allowed to remove this specific item.
    /// Owners/admins → yes, members → yes when the group allows it. The
    /// per-item "added by me" rule lives on the backend; we send the
    /// remove request optimistically and let the server enforce it.
    private func canRemove(_ communityID: Int, community: Community) -> Bool {
        community.isOwnerOrAdmin || (community.isMember && community.membersCanEditMedia)
    }

    /// Card that summarizes the viewer's watch progress across all titles
    /// in the group. Mirrors the web app's "Your progress" panel.
    private func progressCard(progress: GroupDetailViewModel.GroupProgress) -> some View {
        let complete = progress.watched == progress.total && progress.total > 0
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("YOUR PROGRESS")
                    .font(BrandFont.mono(10, weight: .semibold))
                    .tracking(1.5)
                    .foregroundStyle(BrandTheme.textDim)
                Spacer()
                if complete {
                    Text("★ COMPLETE")
                        .font(BrandFont.mono(10, weight: .bold))
                        .tracking(1.0)
                        .foregroundStyle(BrandTheme.primaryText)
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(progress.watched)")
                    .font(BrandFont.serif(28))
                    .foregroundStyle(BrandTheme.text)
                Text("of \(progress.total) watched")
                    .font(BrandFont.sans(13))
                    .foregroundStyle(BrandTheme.textMuted)
                Spacer()
                Text("\(progress.pct)%")
                    .font(BrandFont.mono(13, weight: .medium))
                    .foregroundStyle(BrandTheme.textMuted)
            }

            ProgressTrack(
                fraction: Double(progress.pct) / 100,
                height: 6,
                trackColor: BrandTheme.surface2,
                fillColor: complete ? BrandTheme.primary : BrandTheme.primary
            )

            HStack(spacing: 0) {
                progressStat(value: progress.watching, label: "Watching")
                progressStat(value: progress.watchlisted, label: "Watchlist")
                progressStat(value: progress.unseen, label: "Unseen")
            }
            .padding(.top, 2)
        }
        .padding(14)
        .background(BrandTheme.surface, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(BrandTheme.border, lineWidth: 1))
    }

    private func progressStat(value: Int, label: String) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(BrandFont.sans(15, weight: .semibold))
                .foregroundStyle(BrandTheme.text)
            Text(label.uppercased())
                .font(BrandFont.mono(9, weight: .medium))
                .tracking(1.0)
                .foregroundStyle(BrandTheme.textDim)
        }
        .frame(maxWidth: .infinity)
    }

    /// Placeholder card shown while the bulk watch-status fetch is still
    /// in flight — keeps the same shape as `progressCard` so the layout
    /// doesn't jump when the real numbers arrive.
    private func progressLoadingCard() -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("YOUR PROGRESS")
                    .font(BrandFont.mono(10, weight: .semibold))
                    .tracking(1.5)
                    .foregroundStyle(BrandTheme.textDim)
                Spacer()
                ProgressView()
                    .controlSize(.small)
                    .tint(BrandTheme.primaryText)
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Capsule()
                    .fill(BrandTheme.surface2)
                    .frame(width: 56, height: 26)
                Text("Calculating progress…")
                    .font(BrandFont.sans(13))
                    .foregroundStyle(BrandTheme.textMuted)
                Spacer()
            }

            Capsule()
                .fill(BrandTheme.surface2)
                .frame(height: 6)

            HStack(spacing: 0) {
                ForEach(["Watching", "Watchlist", "Unseen"], id: \.self) { label in
                    VStack(spacing: 2) {
                        Capsule()
                            .fill(BrandTheme.surface2)
                            .frame(width: 22, height: 14)
                        Text(label.uppercased())
                            .font(BrandFont.mono(9, weight: .medium))
                            .tracking(1.0)
                            .foregroundStyle(BrandTheme.textDim)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.top, 2)
        }
        .padding(14)
        .background(BrandTheme.surface, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(BrandTheme.border, lineWidth: 1))
    }

    /// "Add a title" search panel: typing for ≥2 chars kicks off a
    /// debounced `searchAll` call; each result row has an emerald + button
    /// that toggles add/remove based on whether the item is already in
    /// this group.
    @ViewBuilder
    private func titleSearchPanel(community: Community) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ADD A TITLE")
                .font(BrandFont.mono(10, weight: .semibold))
                .tracking(1.5)
                .foregroundStyle(BrandTheme.textDim)

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14))
                    .foregroundStyle(BrandTheme.textMuted)
                TextField("Search movies and shows…", text: $titleSearchQuery)
                    .font(BrandFont.sans(14))
                    .foregroundStyle(BrandTheme.text)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                if !titleSearchQuery.isEmpty {
                    Button {
                        titleSearchQuery = ""
                        viewModel.titleSearchResults = []
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(BrandTheme.textMuted)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(BrandTheme.bg, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(BrandTheme.border, lineWidth: 1))

            // Debounced query → searchAll. Cancels in-flight searches
            // when the query changes.
            Color.clear
                .frame(height: 0)
                .task(id: titleSearchQuery) {
                    let q = titleSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard q.count >= 2 else {
                        viewModel.titleSearchResults = []
                        return
                    }
                    try? await Task.sleep(nanoseconds: 250_000_000)
                    if Task.isCancelled { return }
                    await viewModel.searchTitles(query: q, client: env.apiClient)
                }

            if !titleSearchQuery.isEmpty {
                if viewModel.isSearchingTitles && viewModel.titleSearchResults.isEmpty {
                    Text("Searching…")
                        .font(BrandFont.sans(13))
                        .foregroundStyle(BrandTheme.textMuted)
                        .padding(.vertical, 4)
                } else if viewModel.titleSearchResults.isEmpty {
                    Text("No matches.")
                        .font(BrandFont.sans(13))
                        .foregroundStyle(BrandTheme.textMuted)
                        .padding(.vertical, 4)
                } else {
                    LazyVStack(spacing: 6) {
                        ForEach(viewModel.titleSearchResults) { row in
                            searchResultRow(row, community: community)
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(BrandTheme.surface, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(BrandTheme.border, lineWidth: 1))
    }

    private func searchResultRow(_ row: GroupDetailViewModel.SearchRow, community: Community) -> some View {
        let isAttached = viewModel.attachedMediaKey(for: row) != nil
        let key = "\(row.type.rawValue):\(row.id)"
        let isPending = viewModel.pendingSearchKey == key

        return HStack(spacing: 10) {
            LazyImage(url: TMDBImage.poster(row.posterPath, size: "w185")) { state in
                if let image = state.image { image.resizable().scaledToFill() }
                else { BrandTheme.surface2 }
            }
            .frame(width: 36, height: 54)
            .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 2) {
                Text(row.title)
                    .font(BrandFont.sans(13.5, weight: .semibold))
                    .foregroundStyle(BrandTheme.text)
                    .lineLimit(1)
                Text(row.type == .movie ? "Movie" : "TV" + (row.year.map { " · \($0)" } ?? ""))
                    .font(BrandFont.mono(10.5, weight: .medium))
                    .foregroundStyle(BrandTheme.textMuted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                Task { await viewModel.toggleSearchRow(row, community: community, client: env.apiClient) }
            } label: {
                ZStack {
                    Circle()
                        .fill(isAttached ? BrandTheme.primarySoft : BrandTheme.surface2)
                    Circle()
                        .stroke(isAttached ? Color.clear : BrandTheme.border, lineWidth: 1)
                    if isPending {
                        ProgressView()
                            .scaleEffect(0.6)
                    } else {
                        Image(systemName: isAttached ? "checkmark" : "plus")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(isAttached ? BrandTheme.primaryText : BrandTheme.text)
                    }
                }
                .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .disabled(isPending)
        }
        .padding(.vertical, 4)
    }

    private struct TitleItem: Identifiable, Hashable {
        let id: Int
        let contentID: Int
        let name: String
        let poster: String?
        let type: ContentType
        let rating: Double?
    }

    private func titlesGrid(items: [TitleItem], community: Community) -> some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 12, alignment: .top),
                GridItem(.flexible(), spacing: 12, alignment: .top),
                GridItem(.flexible(), spacing: 12, alignment: .top)
            ],
            spacing: 16
        ) {
            ForEach(items) { item in
                let rating = item.rating ?? viewModel.ratings[Self.ratingKey(type: item.type, id: item.contentID)]
                let editing = titlesEditing
                VStack(alignment: .leading, spacing: 6) {
                    NavigationLink {
                        MediaDetailView(item: MediaItem(
                            id: item.contentID,
                            contentType: item.type,
                            title: item.name,
                            posterPath: item.poster
                        ))
                    } label: {
                        Color.clear
                            .aspectRatio(2.0 / 3.0, contentMode: .fit)
                            .overlay(
                                LazyImage(url: TMDBImage.poster(item.poster)) { state in
                                    if let image = state.image { image.resizable().scaledToFill() }
                                    else { BrandTheme.surface2 }
                                }
                                .opacity(editing ? 0.55 : 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(alignment: .bottomTrailing) {
                                if !editing {
                                    MiniWatchButtons(type: item.type, id: item.contentID)
                                        .padding(6)
                                }
                            }
                            .overlay(alignment: .topTrailing) {
                                if editing && canRemove(item.contentID, community: community) {
                                    Button {
                                        Task {
                                            await viewModel.removeMedia(
                                                mediaID: item.id,
                                                contentType: item.type,
                                                contentID: item.contentID,
                                                client: env.apiClient
                                            )
                                        }
                                    } label: {
                                        Image(systemName: "xmark")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundStyle(.white)
                                            .frame(width: 24, height: 24)
                                            .background(Circle().fill(Color(hex: 0xDC2626)))
                                            .overlay(Circle().stroke(BrandTheme.bg, lineWidth: 2))
                                    }
                                    .buttonStyle(.plain)
                                    .padding(4)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .disabled(editing)

                    Text(item.name)
                        .font(BrandFont.sans(12.5, weight: .semibold))
                        .foregroundStyle(BrandTheme.text)
                        .lineLimit(2)

                    if let rating, rating > 0 {
                        Text(String(format: "★ %.1f", rating))
                            .font(BrandFont.mono(10, weight: .medium))
                            .foregroundStyle(BrandTheme.primaryText)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
    }

    static func ratingKey(type: ContentType, id: Int) -> String {
        "\(type == .tv ? "tv" : "movie"):\(id)"
    }

    // MARK: - Members

    @ViewBuilder
    private func membersSection(community: Community) -> some View {
        if viewModel.members.isEmpty {
            ProgressView().frame(maxWidth: .infinity).padding(.top, 16)
        } else {
            LazyVStack(spacing: 8) {
                ForEach(viewModel.members) { member in
                    HStack(spacing: 10) {
                        AvatarView(username: member.user.username, size: 40)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(member.user.label)
                                .font(BrandFont.sans(13.5, weight: .semibold))
                                .foregroundStyle(BrandTheme.text)
                            Text("@\(member.user.username)")
                                .font(BrandFont.sans(11.5))
                                .foregroundStyle(BrandTheme.textMuted)
                        }
                        Spacer()
                        Text(member.role.capitalized)
                            .font(BrandFont.mono(10, weight: .semibold))
                            .tracking(0.6)
                            .foregroundStyle(roleColor(member.role))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(roleColor(member.role).opacity(0.18), in: Capsule())
                    }
                    .padding(10)
                    .background(BrandTheme.surface, in: RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(BrandTheme.border, lineWidth: 1))
                }
            }
        }
    }

    private func roleColor(_ role: String) -> Color {
        switch role {
        case "owner": return Color(hex: 0xFBBF24)
        case "admin": return Color(hex: 0x60A5FA)
        default: return BrandTheme.primaryText
        }
    }

    // MARK: - Helpers

    private func initials(_ name: String) -> String {
        let words = name.split(separator: " ").prefix(2)
        return words.compactMap { $0.first.map(String.init) }.joined().uppercased()
    }

    private func bannerColor(_ hex: String?) -> Color {
        if let hex, let parsed = Color(hexString: hex) {
            return parsed
        }
        return BrandTheme.primary
    }
}

// MARK: - Card

struct PostCard: View {
    let post: CommunityPost

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                AvatarView(username: post.user?.username, size: 28)
                Text(post.user?.label ?? "—")
                    .font(BrandFont.sans(12.5, weight: .semibold))
                    .foregroundStyle(BrandTheme.text)
                Spacer()
                if let created = post.createdAt, let ago = TimeAgo.format(created) {
                    Text(ago)
                        .font(BrandFont.mono(10))
                        .foregroundStyle(BrandTheme.textDim)
                }
            }
            if let title = post.title, !title.isEmpty {
                Text(title)
                    .font(BrandFont.serif(17))
                    .foregroundStyle(BrandTheme.text)
                    .lineLimit(2)
            }
            Text(post.body)
                .font(BrandFont.sans(13))
                .foregroundStyle(BrandTheme.text.opacity(0.9))
                .lineLimit(4)
                .multilineTextAlignment(.leading)
            HStack(spacing: 14) {
                Label("\(post.likeCount)", systemImage: post.viewerLiked ? "heart.fill" : "heart")
                    .font(BrandFont.mono(11, weight: .medium))
                    .foregroundStyle(post.viewerLiked ? BrandTheme.primaryText : BrandTheme.textMuted)
                Label("\(post.replyCount)", systemImage: "bubble.left")
                    .font(BrandFont.mono(11, weight: .medium))
                    .foregroundStyle(BrandTheme.textMuted)
                Spacer()
            }
        }
        .padding(12)
        .background(BrandTheme.surface, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(BrandTheme.border, lineWidth: 1))
    }
}

// MARK: - View model

@Observable @MainActor
final class GroupDetailViewModel {
    struct GroupProgress {
        let total: Int
        let watched: Int
        let watching: Int
        let watchlisted: Int
        let unseen: Int
        var pct: Int {
            guard total > 0 else { return 0 }
            return Int((Double(watched) / Double(total) * 100).rounded())
        }
    }

    struct SearchRow: Identifiable, Hashable {
        let id: Int
        let type: ContentType
        let title: String
        let year: String?
        let posterPath: String?
        let popularity: Double

        /// Stable key matching the bulk-status / attachment map format.
        var key: String { "\(type.rawValue):\(id)" }
    }

    var community: Community?
    var posts: [CommunityPost] = []
    var media: CommunityMediaResponse?
    var members: [CommunityMember] = []
    /// Ratings keyed by `"movie:<id>"` / `"tv:<id>"`. Fetched client-side via
    /// the per-title info endpoints because the community media response
    /// doesn't include `vote_average` today.
    var ratings: [String: Double] = [:]
    /// Watch status (`Want To Watch` / `Currently Watching` / `Watched` /
    /// `none`) per attached title. Drives the progress card.
    var watchStatuses: [String: WatchStatusEntry] = [:]
    /// True once the first bulk watch-status fetch has completed for the
    /// current media set. Lets the Progress card show a loading skeleton
    /// instead of "0 of N · 0%" while the request is still in flight.
    var hasLoadedWatchStatuses = false
    /// Live search results for the "Add a title" panel.
    var titleSearchResults: [SearchRow] = []
    var isSearchingTitles = false
    /// Key of the row whose add/remove request is currently in flight, so
    /// the row can show a spinner and ignore double taps.
    var pendingSearchKey: String?
    var isLoading = false
    var errorMessage: String?

    func load(client: APIClient, slug: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            community = try await client.community(slug: slug)
            await loadTabs(client: client)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadTabs(client: APIClient) async {
        guard let id = community?.id else { return }
        async let postsTask: [CommunityPost] = (try? await client.communityPosts(id: id)) ?? []
        async let mediaTask: CommunityMediaResponse? = try? await client.communityMedia(id: id)
        async let membersTask: [CommunityMember] = (try? await client.communityMembers(id: id)) ?? []
        posts = await postsTask
        media = await mediaTask
        members = await membersTask
        // Fire ratings enrichment and watch-status fetch in parallel. The
        // bulk watch-status call is a single round trip, so the progress
        // card appears as soon as it lands — no longer blocked by the N
        // per-title ratings requests that may still be in flight.
        async let ratingsTask: Void = enrichRatings(client: client)
        async let statusesTask: Void = loadWatchStatuses(client: client)
        _ = await (ratingsTask, statusesTask)
    }

    /// Pulls the viewer's watch status for every title in the group in a
    /// single bulk request so the progress card and the per-tile state
    /// match without N follow-up requests.
    private func loadWatchStatuses(client: APIClient) async {
        guard let media else { return }
        var refs: [(ContentType, Int)] = []
        refs.append(contentsOf: media.movies.map { (.movie, $0.contentId) })
        refs.append(contentsOf: media.shows.map { (.tv, $0.contentId) })
        guard !refs.isEmpty else {
            watchStatuses = [:]
            hasLoadedWatchStatuses = true
            return
        }
        if let map = try? await client.watchlistStatusBulk(refs) {
            watchStatuses = map
        }
        hasLoadedWatchStatuses = true
    }

    /// Computes the viewer's progress across all attached titles. Returns
    /// nil when the group has no media (the card just hides).
    func titlesProgress(media: CommunityMediaResponse) -> GroupProgress? {
        let total = media.movies.count + media.shows.count
        guard total > 0 else { return nil }
        var watched = 0
        var watching = 0
        var watchlisted = 0
        for movie in media.movies {
            switch watchStatuses["movie:\(movie.contentId)"]?.status {
            case WatchStatus.watched.rawValue: watched += 1
            case WatchStatus.currentlyWatching.rawValue: watching += 1
            case WatchStatus.wantToWatch.rawValue: watchlisted += 1
            default: break
            }
        }
        for show in media.shows {
            switch watchStatuses["tv:\(show.contentId)"]?.status {
            case WatchStatus.watched.rawValue: watched += 1
            case WatchStatus.currentlyWatching.rawValue: watching += 1
            case WatchStatus.wantToWatch.rawValue: watchlisted += 1
            default: break
            }
        }
        let unseen = max(0, total - watched - watching - watchlisted)
        return GroupProgress(
            total: total,
            watched: watched,
            watching: watching,
            watchlisted: watchlisted,
            unseen: unseen
        )
    }

    // MARK: - Add / remove titles

    /// Returns the CommunityMedia row id for a `(contentType, id)` if the
    /// item is already attached to this group; used by the search panel
    /// to decide between add and remove.
    func attachedMediaKey(for row: SearchRow) -> Int? {
        guard let media else { return nil }
        if row.type == .movie {
            return media.movies.first(where: { $0.contentId == row.id })?.id
        } else {
            return media.shows.first(where: { $0.contentId == row.id })?.id
        }
    }

    /// Search the global content index for the panel above the titles
    /// grid. We sort movies + shows together by popularity to mirror the
    /// web app's ordering.
    func searchTitles(query: String, client: APIClient) async {
        isSearchingTitles = true
        defer { isSearchingTitles = false }
        guard let response = try? await client.searchAll(query: query) else {
            titleSearchResults = []
            return
        }
        let shows = response.shows.map {
            SearchRow(
                id: $0.id,
                type: .tv,
                title: $0.title,
                year: $0.releaseDate.map { String(Calendar.current.component(.year, from: $0)) },
                posterPath: $0.posterPath,
                popularity: $0.voteAverage ?? 0
            )
        }
        let movies = response.movies.map {
            SearchRow(
                id: $0.id,
                type: .movie,
                title: $0.title,
                year: $0.releaseDate.map { String(Calendar.current.component(.year, from: $0)) },
                posterPath: $0.posterPath,
                popularity: $0.voteAverage ?? 0
            )
        }
        titleSearchResults = (shows + movies)
            .sorted { $0.popularity > $1.popularity }
            .prefix(12)
            .map { $0 }
    }

    /// Toggle a search row's attachment to the group: add if not yet
    /// attached, remove the existing CommunityMedia row otherwise.
    func toggleSearchRow(_ row: SearchRow, community: Community, client: APIClient) async {
        pendingSearchKey = row.key
        defer { pendingSearchKey = nil }
        if let mediaID = attachedMediaKey(for: row) {
            await removeMedia(mediaID: mediaID, contentType: row.type, contentID: row.id, client: client)
        } else {
            do {
                _ = try await client.communityAddMedia(
                    id: community.id,
                    contentType: row.type.rawValue,
                    contentID: row.id
                )
                // Reload the media list so the panel reflects the new
                // attachment and the grid renders the new tile.
                if let refreshed = try? await client.communityMedia(id: community.id) {
                    media = refreshed
                    await loadWatchStatuses(client: client)
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    /// Removes a single attached item by its CommunityMedia row id.
    /// Optimistically updates the local list so the tile disappears
    /// immediately; rolls back on failure.
    func removeMedia(mediaID: Int, contentType: ContentType, contentID: Int, client: APIClient) async {
        guard let id = community?.id else { return }
        let previous = media
        if let media {
            var copy = media
            if contentType == .movie {
                copy = CommunityMediaResponse(
                    movies: media.movies.filter { $0.id != mediaID },
                    shows: media.shows
                )
            } else {
                copy = CommunityMediaResponse(
                    movies: media.movies,
                    shows: media.shows.filter { $0.id != mediaID }
                )
            }
            self.media = copy
        }
        do {
            _ = try await client.communityRemoveMedia(id: id, mediaID: mediaID)
            watchStatuses.removeValue(forKey: "\(contentType.rawValue):\(contentID)")
        } catch {
            self.media = previous
            errorMessage = error.localizedDescription
        }
    }

    /// Look up `vote_average` for every movie/show in the loaded media so the
    /// title grid can show a ★ rating. Runs in parallel; ignores per-item
    /// failures so a single 404 doesn't stall the whole grid.
    private func enrichRatings(client: APIClient) async {
        guard let media else { return }
        await withTaskGroup(of: (String, Double?).self) { group in
            for movie in media.movies where ratings["movie:\(movie.contentId)"] == nil {
                group.addTask { [contentId = movie.contentId] in
                    let key = "movie:\(contentId)"
                    let rating = (try? await client.movieInfo(id: contentId).voteAverage) ?? nil
                    return (key, rating)
                }
            }
            for show in media.shows where ratings["tv:\(show.contentId)"] == nil {
                group.addTask { [contentId = show.contentId] in
                    let key = "tv:\(contentId)"
                    let rating = (try? await client.showInfo(id: contentId).voteAverage) ?? nil
                    return (key, rating)
                }
            }
            for await (key, rating) in group {
                if let rating { ratings[key] = rating }
            }
        }
    }

    func refreshSelectedTab(client: APIClient, requested: GroupDetailView.Tab? = nil) async {
        guard let id = community?.id else { return }
        let tab = requested ?? .discussion
        switch tab {
        case .discussion:
            posts = (try? await client.communityPosts(id: id)) ?? posts
        case .titles:
            media = (try? await client.communityMedia(id: id)) ?? media
            // Parallelize so the progress card refreshes as soon as the
            // bulk watch-status call lands instead of waiting on the
            // ratings enrichment.
            async let ratingsTask: Void = enrichRatings(client: client)
            async let statusesTask: Void = loadWatchStatuses(client: client)
            _ = await (ratingsTask, statusesTask)
        case .members:
            members = (try? await client.communityMembers(id: id)) ?? members
        case .settings:
            // Settings doesn't need a backend refresh — the form binds to
            // the existing community fields.
            break
        }
    }

    func prepend(post: CommunityPost) {
        posts.insert(post, at: 0)
    }

    func join(client: APIClient) async {
        guard let id = community?.id else { return }
        do {
            _ = try await client.communityJoin(id: id)
            community = try? await client.community(slug: community?.slug ?? "")
            await loadTabs(client: client)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func leave(client: APIClient) async {
        guard let id = community?.id else { return }
        do {
            _ = try await client.communityLeave(id: id)
            community = try? await client.community(slug: community?.slug ?? "")
            members = (try? await client.communityMembers(id: id)) ?? members
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Color hex helper

private extension Color {
    init?(hexString: String) {
        var s = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let value = UInt32(s, radix: 16) else { return nil }
        let r = Double((value >> 16) & 0xFF) / 255.0
        let g = Double((value >> 8) & 0xFF) / 255.0
        let b = Double(value & 0xFF) / 255.0
        self = Color(red: r, green: g, blue: b)
    }
}
