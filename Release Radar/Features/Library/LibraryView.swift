import SwiftUI
import NukeUI

/// Poster-grid library: a segment for Watchlist / Watched and a sub-filter for
/// All / Movies / TV Shows. Mirrors the web app's two list pages.
struct LibraryView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(TabNavigationCoordinator.self) private var tabCoordinator
    @State private var viewModel = LibraryViewModel()
    /// Tracks whether the optional `initialSegment` has already been
    /// applied so it doesn't override the user's manual chip taps after
    /// the first appearance.
    @State private var didApplyInitialSegment = false

    /// Optional segment to scroll the Library to when it appears. Lets
    /// callers like `ProfileView` push the Library already scrolled to
    /// Watchlist or Watched.
    var initialSegment: LibraryViewModel.Segment? = nil

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                LargeTitleHeader(
                    eyebrow: "Your collection",
                    title: "Library",
                    accent: nil
                ) {
                    HStack(spacing: 8) {
                        sortMenu
                        NavigationLink {
                            ShelvesView()
                        } label: {
                            Image(systemName: "books.vertical")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(BrandTheme.text)
                                .frame(width: 38, height: 38)
                                .background(BrandTheme.surface, in: RoundedRectangle(cornerRadius: 13))
                                .overlay(RoundedRectangle(cornerRadius: 13).stroke(BrandTheme.border, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }

                searchField
                    .padding(.horizontal, 20)
                    .padding(.bottom, 10)

                // Primary segment (Watchlist / Watched) — capsule chips so
                // the two top-level lists are visually distinct from the
                // underlined sub-tabs below.
                HStack(spacing: 8) {
                    ForEach(LibraryViewModel.Segment.allCases) { segment in
                        FilterChip(
                            label: segment.title,
                            count: nil,
                            isActive: viewModel.segment == segment,
                            action: { viewModel.segment = segment }
                        )
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 10)

                // Underlined sub-tabs mirroring the web app: Up next /
                // Watching / All / Shows / Movies under Watchlist; All /
                // Movies / Shows under Watched. Each shows a small mono
                // count to the right of the label.
                filterTabs
                    .padding(.bottom, 12)

                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .pageBackground()
            .toolbar(.hidden, for: .navigationBar)
            .refreshable { await viewModel.load(client: env.apiClient) }
            .task { await viewModel.loadIfNeeded(client: env.apiClient) }
            .onAppear {
                if !didApplyInitialSegment, let initialSegment {
                    viewModel.segment = initialSegment
                    didApplyInitialSegment = true
                }
                // Drain the cross-tab coordinator intent (set by ProfileView's
                // "View all" cards). Consume + clear so a subsequent tab
                // switch back to Library doesn't keep snapping the segment.
                if let pending = tabCoordinator.pendingLibrarySegment {
                    viewModel.segment = pending
                    tabCoordinator.pendingLibrarySegment = nil
                }
            }
            .onChange(of: tabCoordinator.pendingLibrarySegment) { _, pending in
                if let pending {
                    viewModel.segment = pending
                    tabCoordinator.pendingLibrarySegment = nil
                }
            }
        }
    }

    /// Web-app-style underlined sub-tabs. Sits under a thin baseline
    /// divider so the active tab's emerald indicator reads as a tab
    /// underline rather than a floating accent. Wrapped in a horizontal
    /// ScrollView so the Watchlist segment's longer set of filters can
    /// shrink/overflow without resizing the page itself.
    private var filterTabs: some View {
        let filters = LibraryViewModel.LibraryFilter.filters(for: viewModel.segment)
        return VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(filters) { filter in
                        Button {
                            viewModel.filter = filter
                        } label: {
                            VStack(spacing: 6) {
                                HStack(alignment: .firstTextBaseline, spacing: 3) {
                                    Text(filter.title)
                                        .font(BrandFont.sans(13, weight: viewModel.filter == filter ? .semibold : .medium))
                                        .foregroundStyle(viewModel.filter == filter ? BrandTheme.text : BrandTheme.textMuted)
                                    Text("\(viewModel.count(for: filter))")
                                        .font(BrandFont.mono(9, weight: .medium))
                                        .foregroundStyle(BrandTheme.textDim)
                                }
                                .fixedSize(horizontal: true, vertical: false)
                                Rectangle()
                                    .fill(viewModel.filter == filter ? BrandTheme.primary : Color.clear)
                                    .frame(height: 2)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
            }
            Rectangle()
                .fill(BrandTheme.border)
                .frame(height: 1)
                .offset(y: -1)
        }
    }

    /// Inline search field that filters the visible library items by title.
    /// Styled to match the rest of the redesigned screens — surface fill,
    /// border, leading magnifyingglass, trailing clear button when active.
    private var searchField: some View {
        @Bindable var vm = viewModel
        return HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(BrandTheme.textMuted)
            TextField("Search your library", text: $vm.searchQuery)
                .font(BrandFont.sans(15))
                .foregroundStyle(BrandTheme.text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
            if !vm.searchQuery.isEmpty {
                Button {
                    vm.searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(BrandTheme.textMuted)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 10)
        .background(BrandTheme.surface, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(BrandTheme.border, lineWidth: 1))
    }

    /// Sort menu trigger styled to match the editorial soft-icon-button look.
    /// When a non-default sort is active, the chip lights up in emerald soft
    /// fill so the active sort state is glanceable.
    private var sortMenu: some View {
        Menu {
            Picker("Sort", selection: $viewModel.sort) {
                ForEach(LibraryViewModel.Sort.allCases) { option in
                    Text(option.title).tag(option)
                }
            }
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 13)
                    .fill(viewModel.sort == .default ? BrandTheme.surface : BrandTheme.primarySoft)
                RoundedRectangle(cornerRadius: 13)
                    .stroke(
                        viewModel.sort == .default ? BrandTheme.border : .clear,
                        lineWidth: 1
                    )
                Image(systemName: "arrow.up.arrow.down")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(viewModel.sort == .default ? BrandTheme.text : BrandTheme.primaryText)
            }
            .frame(width: 38, height: 38)
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.totalCount == 0 {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = viewModel.errorMessage, viewModel.totalCount == 0 {
            ContentUnavailableView(
                "Couldn't load library",
                systemImage: "exclamationmark.triangle",
                description: Text(error)
            )
        } else if viewModel.totalCount == 0 {
            ContentUnavailableView(
                emptyTitle,
                systemImage: emptyIcon,
                description: Text(emptyDescription)
            )
        } else if viewModel.items.isEmpty {
            ContentUnavailableView(
                "Nothing in \(viewModel.filter.title)",
                systemImage: "line.3.horizontal.decrease.circle",
                description: Text("Try switching the filter.")
            )
        } else {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(viewModel.items) { item in
                        NavigationLink {
                            MediaDetailView(item: item)
                        } label: {
                            LibraryPosterCell(
                                item: item,
                                progress: viewModel.progressByShowID[item.id]
                            )
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(role: .destructive) {
                                Task { await viewModel.remove(item, client: env.apiClient) }
                            } label: {
                                Label("Remove from \(viewModel.segment.title)", systemImage: "trash")
                            }
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 16)
                .padding(.bottom, 24)
            }
        }
    }

    private var emptyTitle: String {
        switch viewModel.segment {
        case .watchlist: "Your watchlist is empty"
        case .watched: "Nothing watched yet"
        }
    }

    private var emptyIcon: String {
        switch viewModel.segment {
        case .watchlist: "bookmark"
        case .watched: "checkmark.circle"
        }
    }

    private var emptyDescription: String {
        switch viewModel.segment {
        case .watchlist: "Browse Discover to add movies and TV shows."
        case .watched: "Mark something as watched from its detail page."
        }
    }
}

private struct LibraryPosterCell: View {
    let item: MediaItem
    let progress: ShowProgress?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            poster
            Text(item.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let status = statusLine {
                Text(status.text)
                    .font(BrandFont.mono(10, weight: .medium))
                    .tracking(0.4)
                    .foregroundStyle(status.isEmerald ? BrandTheme.primaryText : BrandTheme.textMuted)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    /// Small "5 eps · 4h left" caption rendered under the title for TV
    /// shows. Falls back to "Caught up" in emerald when nothing remains;
    /// hides itself for movies and shows without progress data.
    private var statusLine: (text: String, isEmerald: Bool)? {
        guard item.contentType == .tv, let p = progress else { return nil }
        if p.isCaughtUp { return ("Caught up", true) }
        let eps = "\(p.remainingEpisodes) ep\(p.remainingEpisodes == 1 ? "" : "s")"
        let time = Self.formatMinutes(p.remainingMinutes)
        return ("\(eps) · \(time) left", false)
    }

    private static func formatMinutes(_ mins: Int) -> String {
        let h = mins / 60
        let m = mins % 60
        if h == 0 { return "\(m)m" }
        if m == 0 { return "\(h)h" }
        return "\(h)h \(m)m"
    }

    @ViewBuilder
    private var poster: some View {
        LazyImage(url: item.posterURL) { state in
            if let image = state.image {
                image.resizable().scaledToFill()
            } else if state.error != nil {
                placeholder(systemImage: "photo")
            } else {
                placeholder(systemImage: nil)
            }
        }
        .aspectRatio(2.0 / 3.0, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(alignment: .topLeading) { ratingBadge }
        .overlay(alignment: .topTrailing) { caughtUpBadge }
        .overlay(alignment: .bottom) { progressBar }
    }

    /// TMDb rating badge in the top-left of the poster. Translucent dark
    /// pill with a yellow star + 1-decimal score. Hidden when the item
    /// has no rating (e.g. unreleased titles).
    @ViewBuilder
    private var ratingBadge: some View {
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

    /// Small emerald progress bar pinned near the bottom of the poster.
    /// Hidden when there's no progress to show or the user is caught up.
    @ViewBuilder
    private var progressBar: some View {
        if let progress, progress.watchedEpisodes > 0, !progress.isCaughtUp {
            ProgressTrack(
                fraction: progress.fraction,
                height: 3,
                trackColor: Color.black.opacity(0.5),
                fillColor: BrandTheme.primary
            )
            .clipShape(Capsule())
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
    }

    /// Emerald checkmark badge shown when the user has watched every
    /// available episode of a TV show.
    @ViewBuilder
    private var caughtUpBadge: some View {
        if let progress, progress.isCaughtUp {
            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(BrandTheme.bg)
                .frame(width: 24, height: 24)
                .background(Circle().fill(BrandTheme.primary))
                .padding(8)
                .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 1)
        }
    }

    private func placeholder(systemImage: String?) -> some View {
        ZStack {
            Color.secondary.opacity(0.15)
            if let systemImage {
                Image(systemName: systemImage).foregroundStyle(.secondary)
            } else {
                ProgressView()
            }
        }
    }
}

#Preview {
    LibraryView()
        .environment(AppEnvironment())
}
