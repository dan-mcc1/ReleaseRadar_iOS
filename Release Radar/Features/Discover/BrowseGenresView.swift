import SwiftUI
import NukeUI

struct BrowseGenresView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var viewModel = BrowseGenresViewModel()

    private let tileColumns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    private static let genreTints: [Color] = [
        Color(hex: 0xC74A55), // rose
        Color(hex: 0x4A6B9B), // blue
        Color(hex: 0x2D2D2D), // charcoal
        Color(hex: 0xC07A2A), // amber
        Color(hex: 0x6B4A8C), // violet
        Color(hex: 0x3D8B7A)  // teal
    ]

    private func tint(for index: Int) -> Color {
        Self.genreTints[index % Self.genreTints.count]
    }

    var body: some View {
        @Bindable var vm = viewModel
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                LargeTitleHeader(
                    eyebrow: "Find by mood",
                    title: "Browse",
                    accent: "genres"
                ) { EmptyView() }

                HStack(spacing: 8) {
                    FilterChip(
                        label: "Movies",
                        count: nil,
                        isActive: vm.typeFilter == .movies,
                        action: { vm.typeFilter = .movies }
                    )
                    FilterChip(
                        label: "TV",
                        count: nil,
                        isActive: vm.typeFilter == .tv,
                        action: { vm.typeFilter = .tv }
                    )
                    Spacer()
                }
                .padding(.horizontal, 16)

                if viewModel.genres.isEmpty && viewModel.isLoadingGenres {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 24)
                } else if let error = viewModel.errorMessage {
                    InlineErrorBanner(message: error) {
                        Task { await viewModel.loadGenres(client: env.apiClient) }
                    }
                    .padding(.horizontal, 16)
                } else {
                    LazyVGrid(columns: tileColumns, spacing: 10) {
                        ForEach(Array(viewModel.genres.enumerated()), id: \.element.id) { idx, genre in
                            NavigationLink {
                                GenreResultsView(genre: genre, typeFilter: viewModel.typeFilter)
                            } label: {
                                genreTile(genre: genre, tint: tint(for: idx))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            .padding(.bottom, 16)
        }
        .pageBackground()
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.loadGenres(client: env.apiClient) }
    }

    @ViewBuilder
    private func genreTile(genre: Genre, tint: Color) -> some View {
        ZStack(alignment: .bottomLeading) {
            Rectangle()
                .fill(tint)
                .aspectRatio(1.4, contentMode: .fit)
                .frame(maxWidth: .infinity)

            LinearGradient(
                colors: [Color.black.opacity(0.05), Color.black.opacity(0.65)],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 0) {
                EyebrowLabel(text: "Explore")
                    .foregroundStyle(Color.white.opacity(0.85))
                Spacer(minLength: 0)
                Text(genre.name)
                    .font(BrandFont.serif(22))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .padding(12)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }
}

@Observable @MainActor
final class BrowseGenresViewModel {
    enum TypeFilter: CaseIterable, Hashable {
        case movies, tv
    }

    var typeFilter: TypeFilter = .movies
    /// The concrete content type used for downstream loads.
    var type: ContentType { typeFilter == .tv ? .tv : .movie }
    /// Full genre response from the backend — we filter for the active
    /// content type at render time so we never offer a genre that the
    /// selected type can't return results for.
    private var genreResponse: GenreListResponse?
    var isLoadingGenres = false
    var errorMessage: String?

    /// Genres for the currently-selected content type. Falls back to the
    /// combined list if the typed lists are empty (older server response).
    var genres: [Genre] {
        guard let response = genreResponse else { return [] }
        let typed = response.genres(for: type)
        return typed.isEmpty ? response.combined : typed
    }

    func loadGenres(client: APIClient) async {
        isLoadingGenres = true
        errorMessage = nil
        defer { isLoadingGenres = false }
        do {
            genreResponse = try await client.searchGenresDecoded()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Genre results sub-page

struct GenreResultsView: View {
    let genre: Genre
    let typeFilter: BrowseGenresViewModel.TypeFilter

    @Environment(AppEnvironment.self) private var env
    @State private var viewModel = GenreResultsViewModel()

    private let posterColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    private var eyebrowText: String {
        switch typeFilter {
        case .movies: return "Movies · sorted by popularity"
        case .tv: return "TV shows · sorted by popularity"
        }
    }

    var body: some View {
        @Bindable var vm = viewModel
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                LargeTitleHeader(
                    eyebrow: eyebrowText,
                    title: genre.name,
                    accent: nil
                ) { EmptyView() }

                if viewModel.isLoading {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, 32)
                } else if let error = viewModel.errorMessage {
                    InlineErrorBanner(message: error) {
                        Task { await viewModel.load(genre: genre, typeFilter: typeFilter, client: env.apiClient) }
                    }
                    .padding(.horizontal, 16)
                } else if viewModel.items.isEmpty {
                    ContentUnavailableView("Nothing found", systemImage: "magnifyingglass", description: Text("Try another genre."))
                } else {
                    LazyVGrid(columns: posterColumns, spacing: 16) {
                        ForEach(viewModel.items) { item in
                            NavigationLink {
                                MediaDetailView(item: item)
                            } label: {
                                BrowseGenresPosterCell(item: item)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)

                    if viewModel.totalPages > 1 {
                        HStack {
                            Button("Previous") {
                                Task { await viewModel.previousPage(genre: genre, typeFilter: typeFilter, client: env.apiClient) }
                            }
                            .disabled(vm.page <= 1)
                            Spacer()
                            Text("Page \(vm.page) of \(vm.totalPages)")
                                .font(.caption)
                                .foregroundStyle(Color.brandTextSecondary)
                            Spacer()
                            Button("Next") {
                                Task { await viewModel.nextPage(genre: genre, typeFilter: typeFilter, client: env.apiClient) }
                            }
                            .disabled(vm.page >= vm.totalPages)
                        }
                        .buttonStyle(.bordered)
                        .padding(.horizontal, 16)
                    }
                }
            }
            .padding(.bottom, 16)
        }
        .pageBackground()
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load(genre: genre, typeFilter: typeFilter, client: env.apiClient) }
    }
}

@Observable @MainActor
final class GenreResultsViewModel {
    var items: [MediaItem] = []
    var page = 1
    var totalPages = 1
    var isLoading = false
    var errorMessage: String?

    func load(genre: Genre, typeFilter: BrowseGenresViewModel.TypeFilter, client: APIClient) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        let type: ContentType = typeFilter == .tv ? .tv : .movie
        do {
            let response = try await client.searchByGenre(type: type, genreID: genre.id, page: page)
            let rawItems = (type == .tv ? (response.shows ?? []) : (response.movies ?? []))
            items = rawItems.map { $0.withType(type) }
            totalPages = response.totalPages ?? 1
        } catch is CancellationError {
            // ignore
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func nextPage(genre: Genre, typeFilter: BrowseGenresViewModel.TypeFilter, client: APIClient) async {
        guard page < totalPages else { return }
        page += 1
        await load(genre: genre, typeFilter: typeFilter, client: client)
    }

    func previousPage(genre: Genre, typeFilter: BrowseGenresViewModel.TypeFilter, client: APIClient) async {
        guard page > 1 else { return }
        page -= 1
        await load(genre: genre, typeFilter: typeFilter, client: client)
    }
}

// MARK: - Poster cell — title + year + MiniWatchButtons in the metadata row
//
// `SharedPosterCard` is reused by other screens, so we keep it untouched and
// build a local cell that mirrors its layout but places the watchlist /
// watched toggles cleanly on the right of the year line — no overlay
// that drifts when the title wraps.

private struct BrowseGenresPosterCell: View {
    let item: MediaItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            LazyImage(url: item.posterURL) { state in
                if let image = state.image {
                    image.resizable().scaledToFill()
                } else if state.error != nil {
                    Color.brandSurfaceElevated.overlay(
                        Image(systemName: "photo").foregroundStyle(.secondary)
                    )
                } else {
                    Color.brandSurfaceElevated.overlay(ProgressView())
                }
            }
            .aspectRatio(2.0 / 3.0, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            Text(item.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 4) {
                if let year = item.releaseDate?.formatted(.dateTime.year()) {
                    Text(year)
                        .font(.caption2)
                        .foregroundStyle(Color.brandTextSecondary)
                }
                Spacer(minLength: 0)
                MiniWatchButtons(type: item.contentType, id: item.id)
            }
        }
    }
}
