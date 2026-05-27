import SwiftUI
import NukeUI

/// Browse every collection in the catalog — paginated, sortable, filterable
/// by size / rating / year / genre. Mirrors the editorial style of the other
/// Discover surfaces (LargeTitleHeader, FilterChip row, mono eyebrow labels).
struct BrowseCollectionsView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var viewModel = BrowseCollectionsViewModel()

    var body: some View {
        @Bindable var vm = viewModel
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                LargeTitleHeader(
                    eyebrow: "Curated picks",
                    title: "Browse",
                    accent: "collections"
                ) { EmptyView() }

                searchField
                    .padding(.horizontal, 16)

                sortChips
                    .padding(.horizontal, 16)

                if vm.isLoading && vm.entries.isEmpty {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, 48)
                } else if let error = vm.errorMessage, vm.entries.isEmpty {
                    InlineErrorBanner(message: error) { Task { await viewModel.load(client: env.apiClient) } }
                        .padding(.horizontal, 16)
                } else if vm.entries.isEmpty {
                    ContentUnavailableView(
                        "No collections",
                        systemImage: "rectangle.stack",
                        description: Text("Try adjusting the filter or sort.")
                    )
                    .padding(.top, 32)
                } else {
                    grid
                    pagination
                }
            }
            .padding(.bottom, 24)
        }
        .pageBackground()
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.loadIfNeeded(client: env.apiClient) }
    }

    private var searchField: some View {
        @Bindable var vm = viewModel
        return HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(BrandTheme.textMuted)
            TextField("Search collections", text: $vm.query)
                .font(BrandFont.sans(14))
                .foregroundStyle(BrandTheme.text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .onSubmit { Task { await viewModel.search(client: env.apiClient) } }
            if !vm.query.isEmpty {
                Button {
                    vm.query = ""
                    Task { await viewModel.load(client: env.apiClient) }
                } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(BrandTheme.textMuted) }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(BrandTheme.surface, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(BrandTheme.border, lineWidth: 1))
    }

    private var sortChips: some View {
        @Bindable var vm = viewModel
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(BrowseCollectionsViewModel.Sort.allCases) { sort in
                    let isActive = vm.sort == sort
                    let arrow = vm.direction == .asc ? " ↑" : " ↓"
                    FilterChip(
                        label: isActive ? "\(sort.label)\(arrow)" : sort.label,
                        count: nil,
                        isActive: isActive,
                        action: {
                            if isActive {
                                vm.direction = vm.direction == .asc ? .desc : .asc
                            } else {
                                vm.sort = sort
                                vm.direction = sort.defaultDirection
                            }
                            Task { await viewModel.load(client: env.apiClient) }
                        }
                    )
                }
            }
        }
    }

    private var grid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 12, alignment: .top),
                GridItem(.flexible(), spacing: 12, alignment: .top),
                GridItem(.flexible(), spacing: 12, alignment: .top)
            ],
            spacing: 18
        ) {
            ForEach(viewModel.entries) { entry in
                NavigationLink {
                    CollectionInfoView(collectionID: entry.id)
                } label: {
                    cell(for: entry)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
    }

    private func cell(for entry: CollectionBrowseEntry) -> some View {
        let progress = viewModel.progress[entry.id]
        return VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .topTrailing) {
                Color.clear
                    .aspectRatio(2.0 / 3.0, contentMode: .fit)
                    .overlay(
                        LazyImage(url: TMDBImage.poster(entry.posterPath)) { state in
                            if let image = state.image { image.resizable().scaledToFill() }
                            else { BrandTheme.surface2 }
                        }
                    )
                    .overlay(alignment: .bottomLeading) {
                        if let progress, progress.releasedParts > 0 {
                            progressOverlay(fraction: progress.fraction)
                        }
                    }
                    .overlay(alignment: .topLeading) {
                        if let progress, progress.finished {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(BrandTheme.primary, .white)
                                .padding(6)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                // Size badge — top-right, mono so it stays editorial.
                Text("\(entry.size)")
                    .font(BrandFont.mono(10, weight: .semibold))
                    .tracking(0.4)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(.black.opacity(0.55), in: Capsule())
                    .padding(6)
            }

            Text(entry.name)
                .font(BrandFont.sans(12.5, weight: .semibold))
                .foregroundStyle(BrandTheme.text)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            if let rating = entry.avgRating, rating > 0 {
                Text(String(format: "★ %.1f", rating))
                    .font(BrandFont.mono(10, weight: .medium))
                    .foregroundStyle(BrandTheme.primaryText)
            } else if let min = entry.minYear, let max = entry.maxYear {
                // verbatim: skip Text's LocalizedStringKey path, which would
                // render "2,026" with a grouping separator on most locales.
                Text(verbatim: min == max ? "\(min)" : "\(min)–\(max)")
                    .font(BrandFont.mono(10, weight: .medium))
                    .foregroundStyle(BrandTheme.textDim)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    /// Small green progress sliver layered at the bottom of the poster.
    /// Mirrors the same overlay used on the My Collections / Library pages
    /// so a user can tell at a glance how far along they are.
    private func progressOverlay(fraction: Double) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Rectangle().fill(.black.opacity(0.45))
                Rectangle().fill(BrandTheme.primary)
                    .frame(width: proxy.size.width * max(0, min(1, fraction)))
            }
        }
        .frame(height: 4)
    }

    @ViewBuilder
    private var pagination: some View {
        @Bindable var vm = viewModel
        if vm.totalPages > 1 {
            HStack(spacing: 12) {
                Button {
                    Task { await viewModel.previousPage(client: env.apiClient) }
                } label: { Image(systemName: "chevron.left") }
                .disabled(vm.page <= 1)

                Spacer()
                Text("Page \(vm.page) of \(vm.totalPages)")
                    .font(BrandFont.mono(11, weight: .medium))
                    .foregroundStyle(BrandTheme.textMuted)
                Spacer()

                Button {
                    Task { await viewModel.nextPage(client: env.apiClient) }
                } label: { Image(systemName: "chevron.right") }
                .disabled(vm.page >= vm.totalPages)
            }
            .buttonStyle(.bordered)
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
    }
}

@Observable @MainActor
final class BrowseCollectionsViewModel {
    enum Direction: String {
        case asc, desc
    }

    enum Sort: String, CaseIterable, Identifiable {
        case popularity
        case rating
        case size
        case name

        var id: String { rawValue }
        var label: String {
            switch self {
            case .popularity: "Popular"
            case .rating: "Highest rated"
            case .size: "Largest"
            case .name: "A–Z"
            }
        }
        /// Default direction used when switching to this sort from another.
        var defaultDirection: Direction {
            switch self {
            case .popularity, .rating, .size: .desc
            case .name: .asc
            }
        }
        /// Backend's `sort` token for this preset.
        var backendKey: String {
            switch self {
            case .popularity: "popularity"
            case .rating: "rating"
            case .size: "size"
            case .name: "name"
            }
        }
    }

    var query: String = ""
    var sort: Sort = .popularity
    var direction: Direction = .desc
    var entries: [CollectionBrowseEntry] = []
    var progress: [Int: CollectionBulkStatus] = [:]
    var page: Int = 1
    var pageSize: Int = 30
    var totalPages: Int = 1
    var isLoading = false
    var errorMessage: String?

    private var hasLoaded = false

    func loadIfNeeded(client: APIClient) async {
        guard !hasLoaded else { return }
        await load(client: client)
    }

    func load(client: APIClient) async {
        page = 1
        await fetch(client: client)
    }

    func nextPage(client: APIClient) async {
        guard page < totalPages else { return }
        page += 1
        await fetch(client: client)
    }

    func previousPage(client: APIClient) async {
        guard page > 1 else { return }
        page -= 1
        await fetch(client: client)
    }

    func search(client: APIClient) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            await load(client: client)
            return
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            // /collections/search returns the lite shape; promote to browse
            // shape so the same grid renders.
            let data = try await client.collectionsSearch(query: trimmed)
            let response = try JSONDecoder().decode(SearchResponse.self, from: data)
            entries = response.results.map {
                CollectionBrowseEntry(
                    id: $0.id,
                    name: $0.name,
                    posterPath: $0.posterPath,
                    backdropPath: $0.backdropPath,
                    size: 0,
                    avgRating: nil,
                    popularity: nil,
                    minYear: nil,
                    maxYear: nil
                )
            }
            totalPages = 1
            page = 1
            hasLoaded = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func fetch(client: APIClient) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let response = try await client.collectionsBrowse(
                sort: sort.backendKey,
                direction: direction.rawValue,
                page: page,
                pageSize: pageSize
            )
            entries = response.results
            totalPages = max(1, Int(ceil(Double(response.total) / Double(max(1, response.pageSize)))))
            hasLoaded = true
            await loadProgress(client: client)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Fetch user progress for every visible collection in one round trip.
    /// Best-effort — if the bulk endpoint fails, the cells just render
    /// without progress overlays.
    private func loadProgress(client: APIClient) async {
        let ids = entries.map(\.id)
        guard !ids.isEmpty else {
            progress = [:]
            return
        }
        if let bulk = try? await client.collectionsBulkStatus(ids: ids) {
            progress = bulk
        }
    }

    /// Decode shape for `/collections/search`.
    private struct SearchResponse: Decodable {
        let results: [SearchHit]
    }
    private struct SearchHit: Decodable, Identifiable {
        let id: Int
        let name: String
        let posterPath: String?
        let backdropPath: String?
        enum CodingKeys: String, CodingKey {
            case id, name
            case posterPath = "poster_path"
            case backdropPath = "backdrop_path"
        }
    }
}
