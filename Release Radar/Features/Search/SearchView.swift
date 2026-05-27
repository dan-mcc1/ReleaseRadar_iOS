import SwiftUI
import NukeUI

struct DiscoverView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var viewModel = DiscoverViewModel()

    var body: some View {
        @Bindable var viewModel = viewModel
        NavigationStack {
            VStack(spacing: 0) {
                LargeTitleHeader(
                    eyebrow: "Trending now",
                    title: "Discover",
                    accent: nil
                ) { EmptyView() }
                searchField
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
                content
            }
            .pageBackground()
            .toolbar(.hidden, for: .navigationBar)
            .onChange(of: viewModel.query) { _, _ in
                viewModel.scheduleSearch(client: env.apiClient)
            }
            .task { await viewModel.loadIfNeeded(client: env.apiClient) }
            .refreshable { await viewModel.load(client: env.apiClient) }
        }
    }

    /// Inline editorial-styled search field — replaces the native
    /// `.searchable(...)` UI which can't render with the nav bar hidden.
    /// Typing here flips `viewModel.isQueryActive` and swaps the body to
    /// the search overlay below.
    private var searchField: some View {
        @Bindable var vm = viewModel
        return HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(BrandTheme.textMuted)
            TextField("Search movies & TV", text: $vm.query)
                .font(BrandFont.sans(15))
                .foregroundStyle(BrandTheme.text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
            if !vm.query.isEmpty {
                Button {
                    vm.query = ""
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

    @ViewBuilder
    private var content: some View {
        ScrollView {
            if viewModel.isQueryActive {
                searchOverlay
            } else {
                discoverFeed
            }
        }
    }

    // MARK: - Discover feed

    private var discoverFeed: some View {
        @Bindable var viewModel = viewModel
        return LazyVStack(alignment: .leading, spacing: 28) {
            DiscoverHubMenu()

            if let hero = viewModel.hero {
                HeroBanner(item: hero)
                    .padding(.horizontal, 16)
            } else if viewModel.trendingLoading {
                HeroSkeleton().padding(.horizontal, 16)
            }

            HorizontalRow(
                title: "Trending",
                accent: "this week",
                subtitle: "What people are talking about",
                isLoading: viewModel.trendingLoading,
                items: viewModel.filtered(viewModel.trending, by: viewModel.trendingFilter),
                filter: $viewModel.trendingFilter,
                style: .standard
            )

            HorizontalRow(
                title: "Coming",
                accent: "soon",
                subtitle: dateRangeLabel(),
                isLoading: viewModel.upcomingLoading,
                items: viewModel.filtered(viewModel.upcoming, by: viewModel.upcomingFilter),
                filter: $viewModel.upcomingFilter,
                style: .release
            )

            HorizontalRow(
                title: "Airing",
                accent: "today",
                subtitle: "New episodes on TV right now",
                isLoading: viewModel.airingTodayLoading,
                items: viewModel.airingToday,
                filter: nil,
                style: .standard
            )

            HorizontalRow(
                title: "In theaters",
                accent: "now",
                subtitle: "Currently showing on the big screen",
                isLoading: viewModel.nowPlayingLoading,
                items: viewModel.nowPlaying,
                filter: nil,
                style: .standard
            )

            HorizontalRow(
                title: "Popular",
                accent: "right now",
                subtitle: "What people are watching",
                isLoading: viewModel.popularLoading,
                items: viewModel.filtered(viewModel.popular, by: viewModel.popularFilter),
                filter: $viewModel.popularFilter,
                style: .standard
            )

            HorizontalRow(
                title: "Top",
                accent: "rated",
                subtitle: "The highest-rated of all time",
                isLoading: viewModel.topRatedLoading,
                items: viewModel.filtered(viewModel.topRated, by: viewModel.topRatedFilter),
                filter: $viewModel.topRatedFilter,
                style: .standard
            )
        }
        .padding(.vertical, 16)
    }

    // MARK: - Search overlay

    @ViewBuilder
    private var searchOverlay: some View {
        @Bindable var vm = viewModel
        let r = viewModel.searchResults
        let total = r.totalCount

        VStack(alignment: .leading, spacing: 12) {
            // Tabs (only render the tab if it has results, like the web app)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(DiscoverViewModel.SearchTab.allCases) { tab in
                        let count = viewModel.searchTabCount(tab)
                        if tab == .all || count > 0 {
                            Button {
                                vm.searchTab = tab
                            } label: {
                                HStack(spacing: 4) {
                                    Text(tab.label).font(.caption.weight(.medium))
                                    Text("\(count)")
                                        .font(.system(.caption2, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    vm.searchTab == tab ? Color.brandPrimary : Color.brandSurface,
                                    in: Capsule()
                                )
                                .foregroundStyle(vm.searchTab == tab ? .white : .white.opacity(0.85))
                                .overlay(Capsule().stroke(Color.brandBorder, lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }

            if viewModel.isSearching && total == 0 {
                ProgressView().frame(maxWidth: .infinity).padding(.top, 40)
            } else if let error = viewModel.searchError, total == 0 {
                ContentUnavailableView("Couldn't search", systemImage: "exclamationmark.triangle", description: Text(error))
                    .padding(.top, 24)
            } else if total == 0 {
                ContentUnavailableView("No results", systemImage: "magnifyingglass", description: Text("Try a different search."))
                    .padding(.top, 24)
            } else {
                switch viewModel.searchTab {
                case .all:
                    allTabResults(r)
                case .movies:
                    posterGrid(r.movies)
                case .tv:
                    posterGrid(r.shows)
                case .people:
                    peopleList(r.people)
                case .collections:
                    collectionsList(r.collections)
                }
            }
        }
    }

    @ViewBuilder
    private func allTabResults(_ r: SearchAllResults) -> some View {
        // Decide whether the Movies or TV Shows row appears first by
        // comparing the top result of each. Falls back to voteAverage
        // when popularity is missing from the payload, then to a fixed
        // TV-first ordering as a last resort.
        let showsFirst = topScore(r.shows.first) >= topScore(r.movies.first)
        VStack(alignment: .leading, spacing: 24) {
            if showsFirst {
                if !r.shows.isEmpty {
                    searchSection(title: "TV Shows", count: r.shows.count, seeAll: { viewModel.searchTab = .tv }) {
                        horizontalPosters(Array(r.shows.prefix(8)))
                    }
                }
                if !r.movies.isEmpty {
                    searchSection(title: "Movies", count: r.movies.count, seeAll: { viewModel.searchTab = .movies }) {
                        horizontalPosters(Array(r.movies.prefix(8)))
                    }
                }
            } else {
                if !r.movies.isEmpty {
                    searchSection(title: "Movies", count: r.movies.count, seeAll: { viewModel.searchTab = .movies }) {
                        horizontalPosters(Array(r.movies.prefix(8)))
                    }
                }
                if !r.shows.isEmpty {
                    searchSection(title: "TV Shows", count: r.shows.count, seeAll: { viewModel.searchTab = .tv }) {
                        horizontalPosters(Array(r.shows.prefix(8)))
                    }
                }
            }
            if !r.people.isEmpty {
                searchSection(title: "People", count: r.people.count, seeAll: { viewModel.searchTab = .people }) {
                    peopleStrip(Array(r.people.prefix(8)))
                }
            }
            if !r.collections.isEmpty {
                searchSection(title: "Collections", count: r.collections.count, seeAll: { viewModel.searchTab = .collections }) {
                    collectionsStrip(Array(r.collections.prefix(8)))
                }
            }
        }
    }

    /// Sort key for All-tab section ordering. Prefer TMDB popularity when
    /// the backend includes it, otherwise fall back to voteAverage so the
    /// ordering still reflects relevance instead of being constant.
    private func topScore(_ item: MediaItem?) -> Double {
        guard let item else { return -.infinity }
        return item.popularity ?? item.voteAverage ?? 0
    }

    @ViewBuilder
    private func searchSection<Content: View>(
        title: String,
        count: Int,
        seeAll: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title).font(.system(.title3, design: .serif)).foregroundStyle(.white)
                Text("\(count)").font(.caption).foregroundStyle(Color.brandTextSecondary)
                Spacer()
                if let seeAll {
                    Button("See all", action: seeAll).font(.caption.weight(.semibold))
                }
            }
            .padding(.horizontal, 16)
            content()
        }
    }

    @ViewBuilder
    private func horizontalPosters(_ items: [MediaItem]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: 12) {
                ForEach(items) { item in
                    NavigationLink {
                        MediaDetailView(item: item)
                    } label: {
                        SharedPosterCard(posterPath: item.posterPath, title: item.title, width: 110)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    @ViewBuilder
    private func posterGrid(_ items: [MediaItem]) -> some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 110), spacing: 12)],
            alignment: .leading,
            spacing: 16
        ) {
            ForEach(items) { item in
                NavigationLink {
                    MediaDetailView(item: item)
                } label: {
                    SharedPosterCard(
                        posterPath: item.posterPath,
                        title: item.title,
                        subtitle: item.releaseDate.flatMap { $0.formatted(.dateTime.year()) }
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private func peopleStrip(_ people: [PersonItem]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: 12) {
                ForEach(people) { p in
                    NavigationLink {
                        PersonInfoView(personID: p.id, initialName: p.name)
                    } label: {
                        personCard(p)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    @ViewBuilder
    private func peopleList(_ people: [PersonItem]) -> some View {
        LazyVStack(spacing: 10) {
            ForEach(people) { p in
                NavigationLink {
                    PersonInfoView(personID: p.id, initialName: p.name)
                } label: {
                    HStack(spacing: 10) {
                        personAvatar(p, size: 56)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(p.name ?? "—")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                            if let dept = p.knownForDepartment {
                                Text(dept).font(.caption).foregroundStyle(Color.brandTextSecondary)
                            }
                        }
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(Color.brandTextSecondary)
                    }
                    .padding(12)
                    .background(Color.brandSurface, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.brandBorder, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private func personCard(_ p: PersonItem) -> some View {
        VStack(spacing: 6) {
            personAvatar(p, size: 88)
            Text(p.name ?? "—")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .frame(width: 96)
            if let dept = p.knownForDepartment {
                Text(dept).font(.caption2).foregroundStyle(Color.brandTextSecondary).lineLimit(1)
            }
        }
    }

    @ViewBuilder
    private func personAvatar(_ p: PersonItem, size: CGFloat) -> some View {
        LazyImage(url: TMDBImage.providerLogo(p.profilePath)) { state in
            if let image = state.image {
                image.resizable().scaledToFill()
            } else {
                ZStack {
                    Color.brandSurfaceElevated
                    Image(systemName: "person.fill").foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    @ViewBuilder
    private func collectionsStrip(_ collections: [SearchedCollection]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: 12) {
                ForEach(collections) { c in
                    NavigationLink {
                        CollectionInfoView(collectionID: c.id)
                    } label: {
                        collectionCard(c)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    @ViewBuilder
    private func collectionsList(_ collections: [SearchedCollection]) -> some View {
        LazyVStack(spacing: 10) {
            ForEach(collections) { c in
                NavigationLink {
                    CollectionInfoView(collectionID: c.id)
                } label: {
                    HStack(spacing: 10) {
                        LazyImage(url: TMDBImage.poster(c.posterPath)) { state in
                            if let image = state.image {
                                image.resizable().scaledToFill()
                            } else { Color.brandSurfaceElevated }
                        }
                        .frame(width: 60, height: 90)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(c.name ?? "—").font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                            if let overview = c.overview, !overview.isEmpty {
                                Text(overview).font(.caption).foregroundStyle(Color.brandTextSecondary).lineLimit(2)
                            }
                        }
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(Color.brandTextSecondary)
                    }
                    .padding(12)
                    .background(Color.brandSurface, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.brandBorder, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private func collectionCard(_ c: SearchedCollection) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            LazyImage(url: TMDBImage.poster(c.posterPath)) { state in
                if let image = state.image {
                    image.resizable().scaledToFill()
                } else { Color.brandSurfaceElevated }
            }
            .aspectRatio(2.0 / 3.0, contentMode: .fit)
            .frame(width: 110)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            Text(c.name ?? "—")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .frame(width: 110, alignment: .leading)
        }
    }

    private func dateRangeLabel() -> String {
        let today = Date()
        let cal = Calendar.current
        let nextMonth = cal.date(byAdding: .month, value: 1, to: today) ?? today
        let fmt = Date.FormatStyle().month(.wide).day()
        let fmtYear = Date.FormatStyle().month(.wide).day().year()
        return "\(today.formatted(fmt)) – \(nextMonth.formatted(fmtYear))"
    }
}

// MARK: - Hero

private struct HeroBanner: View {
    let item: MediaItem

    var body: some View {
        // Use Color.clear as the sizing anchor so the banner inherits the
        // parent's width exactly (no intrinsic-size feedback from the image)
        // and we just paint the artwork + gradient + overlay on top.
        Color.clear
            .frame(maxWidth: .infinity)
            .frame(height: 280)
            .overlay {
                LazyImage(url: item.backdropURL) { state in
                    if let image = state.image {
                        image.resizable().scaledToFill()
                    } else {
                        Color.brandSurface
                    }
                }
            }
            .overlay {
                LinearGradient(
                    colors: [Color.black.opacity(0.85), Color.black.opacity(0.4), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            }
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("SPOTLIGHT · TRENDING")
                        .font(.system(.caption2, design: .monospaced))
                        .tracking(2)
                        .foregroundStyle(.white.opacity(0.85))
                    Text(spotlightTitle)
                        .font(.system(.title, design: .serif))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    if let overview = item.overview, !overview.isEmpty {
                        Text(overview)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.8))
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                    HStack(spacing: 12) {
                        NavigationLink {
                            MediaDetailView(item: item)
                        } label: {
                            Text("More info →")
                                .font(.subheadline.weight(.semibold))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Color.brandPrimary, in: RoundedRectangle(cornerRadius: 8))
                                .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)
                        if let rating = item.voteAverage, rating > 0 {
                            Text("★ \(String(format: "%.1f", rating))")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                    .padding(.top, 4)
                }
                .frame(maxWidth: 260, alignment: .leading)
                .padding(20)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    /// Last word italicized — matches the web app's typographic touch.
    private var spotlightTitle: AttributedString {
        let words = item.title.split(separator: " ")
        var attr = AttributedString(item.title)
        if words.count > 1, let lastWord = words.last,
           let range = attr.range(of: String(lastWord), options: .backwards) {
            attr[range].font = .system(.largeTitle, design: .serif).italic()
        }
        return attr
    }
}

private struct HeroSkeleton: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color.brandSurface)
            .frame(height: 280)
            .frame(maxWidth: .infinity)
    }
}

// MARK: - Row

private struct HorizontalRow: View {
    enum Style { case standard, release }

    let title: String
    let accent: String?
    let subtitle: String?
    let isLoading: Bool
    let items: [MediaItem]
    let filter: Binding<DiscoverViewModel.ContentFilter>?
    let style: Style

    init(
        title: String,
        accent: String? = nil,
        subtitle: String?,
        isLoading: Bool,
        items: [MediaItem],
        filter: Binding<DiscoverViewModel.ContentFilter>?,
        style: Style
    ) {
        self.title = title
        self.accent = accent
        self.subtitle = subtitle
        self.isLoading = isLoading
        self.items = items
        self.filter = filter
        self.style = style
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    SectionTitle(title, accent: accent)
                    if let subtitle {
                        Text(subtitle)
                            .font(BrandFont.sans(12))
                            .foregroundStyle(BrandTheme.textMuted)
                    }
                }
                Spacer()
                if let filter {
                    FilterPill(filter: filter)
                }
            }
            .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 12) {
                    if isLoading {
                        ForEach(0..<8, id: \.self) { _ in PosterSkeleton() }
                    } else if items.isEmpty {
                        Text("Nothing to show")
                            .font(.caption)
                            .foregroundStyle(Color.brandTextSecondary)
                            .padding(.vertical, 12)
                    } else {
                        ForEach(items) { item in
                            NavigationLink {
                                MediaDetailView(item: item)
                            } label: {
                                PosterCard(
                                    item: item,
                                    releaseDateOverride: style == .release ? item.releaseDate : nil
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
}

// MARK: - Filter pill

private struct FilterPill: View {
    @Binding var filter: DiscoverViewModel.ContentFilter

    var body: some View {
        HStack(spacing: 2) {
            ForEach(DiscoverViewModel.ContentFilter.allCases) { option in
                Button {
                    filter = option
                } label: {
                    Text(option.label)
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            filter == option ? Color.brandSurfaceElevated : Color.clear,
                            in: Capsule()
                        )
                        .foregroundStyle(filter == option ? .white : Color.brandTextSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(Color.brandSurface, in: Capsule())
        .overlay(Capsule().stroke(Color.brandBorder, lineWidth: 1))
    }
}

// MARK: - Poster card

private struct PosterCard: View {
    let item: MediaItem
    let releaseDateOverride: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            LazyImage(url: item.posterURL) { state in
                if let image = state.image {
                    image.resizable().scaledToFill()
                } else if state.error != nil {
                    Color.brandSurfaceElevated.overlay(Image(systemName: "photo").foregroundStyle(.secondary))
                } else {
                    Color.brandSurfaceElevated.overlay(ProgressView())
                }
            }
            .aspectRatio(2.0 / 3.0, contentMode: .fit)
            .frame(width: 130)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(alignment: .bottomTrailing) {
                MiniWatchButtons(type: item.contentType, id: item.id)
                    .padding(6)
            }

            Text(item.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .frame(width: 130, alignment: .leading)

            HStack(spacing: 4) {
                if let date = releaseDateOverride {
                    Text(date.formatted(.dateTime.month(.abbreviated).day().year()))
                        .font(.caption2)
                        .foregroundStyle(Color.brandTextSecondary)
                } else if let rating = item.voteAverage, rating > 0 {
                    Text("★ \(String(format: "%.1f", rating))")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(Color.brandTextSecondary)
                }
            }
            .frame(width: 130, alignment: .leading)
        }
    }
}

private struct PosterSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.brandSurface)
                .aspectRatio(2.0 / 3.0, contentMode: .fit)
                .frame(width: 130)
            Rectangle()
                .fill(Color.brandSurface)
                .frame(width: 100, height: 10)
                .clipShape(RoundedRectangle(cornerRadius: 3))
            Rectangle()
                .fill(Color.brandSurface)
                .frame(width: 60, height: 8)
                .clipShape(RoundedRectangle(cornerRadius: 3))
        }
    }
}

#Preview {
    DiscoverView()
        .environment(AppEnvironment())
        .tint(.brandPrimary)
        .preferredColorScheme(.dark)
}
