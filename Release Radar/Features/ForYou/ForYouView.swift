import SwiftUI
import NukeUI

struct ForYouView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var viewModel = ForYouViewModel()

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        @Bindable var vm = viewModel
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                LargeTitleHeader(
                    eyebrow: "Tailored to you",
                    title: "For",
                    accent: "you"
                ) { EmptyView() }

                HStack(spacing: 10) {
                    ForYouTypeTab(
                        title: "TV",
                        count: viewModel.shows.count,
                        systemImage: "tv",
                        isSelected: vm.tab == .tv
                    ) { vm.tab = .tv }
                    ForYouTypeTab(
                        title: "Movies",
                        count: viewModel.movies.count,
                        systemImage: "film",
                        isSelected: vm.tab == .movie
                    ) { vm.tab = .movie }
                }
                .padding(.horizontal, 16)

                HStack(spacing: 18) {
                    Text("SORT")
                        .font(BrandFont.mono(10, weight: .semibold))
                        .tracking(1.5)
                        .foregroundStyle(BrandTheme.textDim)
                    ForYouSortButton(title: "Most recent", isSelected: vm.mode == .recent) {
                        vm.mode = .recent
                    }
                    ForYouSortButton(title: "Highest rated", isSelected: vm.mode == .topRated) {
                        vm.mode = .topRated
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .onChange(of: vm.mode) { _, _ in Task { await viewModel.load(client: env.apiClient) } }

                if viewModel.isLoading {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, 32)
                } else if let error = viewModel.errorMessage {
                    InlineErrorBanner(message: error) { Task { await viewModel.load(client: env.apiClient) } }
                        .padding(.horizontal, 16)
                } else if (viewModel.seedCount ?? 0) == 0 {
                    ContentUnavailableView(
                        "Nothing to go on yet",
                        systemImage: "wand.and.stars",
                        description: Text("Add some titles to your watchlist or mark some watched, and we'll build recommendations.")
                    )
                } else {
                    let items = vm.tab == .tv ? viewModel.shows : viewModel.movies
                    if items.isEmpty {
                        ContentUnavailableView("No picks here", systemImage: "tray", description: Text("Try the other tab."))
                    } else {
                        if let hero = items.first { heroCard(hero).padding(.horizontal, 16) }
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(items.dropFirst()) { item in
                                NavigationLink {
                                    MediaDetailView(item: item)
                                } label: {
                                    ForYouPosterCell(item: item)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
            }
            .padding(.bottom, 16)
        }
        .pageBackground()
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load(client: env.apiClient) }
        .refreshable { await viewModel.load(client: env.apiClient) }
    }

    private func heroCard(_ item: MediaItem) -> some View {
        ZStack(alignment: .bottomLeading) {
            LazyImage(url: item.backdropURL) { state in
                if let image = state.image { image.resizable().scaledToFill() }
                else { Color.brandSurfaceElevated }
            }
            .aspectRatio(16.0 / 9.0, contentMode: .fill)
            .frame(maxWidth: .infinity)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 14))

            LinearGradient(colors: [Color.black.opacity(0.85), .clear], startPoint: .bottom, endPoint: .top)
                .clipShape(RoundedRectangle(cornerRadius: 14))

            // Quick watchlist/watched toggles in the top-right of the hero,
            // matching the editorial pattern used on grid posters.
            VStack {
                HStack {
                    Spacer()
                    MiniWatchButtons(type: item.contentType, id: item.id)
                }
                Spacer()
            }
            .padding(12)

            VStack(alignment: .leading, spacing: 6) {
                Text("TOP PICK")
                    .font(.system(.caption2, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(Color.brandPrimary)
                Text(item.title)
                    .font(.system(.title2, design: .serif).weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                Text("Most recommended across your watch history")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.85))
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
                }
                .padding(.top, 4)
            }
            .padding(16)
        }
    }
}

// MARK: - For You header tab styling

private struct ForYouTypeTab: View {
    let title: String
    let count: Int
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .semibold))
                Text(title)
                    .font(BrandFont.sans(15, weight: .semibold))
                Text("\(count)")
                    .font(BrandFont.mono(12, weight: .semibold))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(
                        isSelected ? Color.black.opacity(0.18) : BrandTheme.surface,
                        in: Capsule()
                    )
            }
            .foregroundStyle(isSelected ? Color.white : BrandTheme.text)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(
                isSelected ? BrandTheme.primary : BrandTheme.surface2,
                in: Capsule()
            )
            .overlay(
                Capsule().stroke(
                    isSelected ? Color.clear : BrandTheme.border,
                    lineWidth: 1
                )
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.18), value: isSelected)
    }
}

private struct ForYouSortButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(title)
                    .font(BrandFont.sans(13, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? BrandTheme.primaryText : BrandTheme.textMuted)
                Rectangle()
                    .fill(isSelected ? BrandTheme.primary : Color.clear)
                    .frame(height: 1.5)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - For You poster cell — SharedPosterCard look + MiniWatchButtons overlay
//
// `SharedPosterCard` is reused by Profile, Discover, and others, so we keep
// it untouched and build a local cell that mirrors its layout but adds the
// watchlist/watched overlay on the bottom-trailing of the poster.

private struct ForYouPosterCell: View {
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
            .overlay(alignment: .bottomTrailing) {
                MiniWatchButtons(type: item.contentType, id: item.id)
                    .padding(6)
            }

            Text(item.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let year = item.releaseDate?.formatted(.dateTime.year()) {
                Text(year)
                    .font(.caption2)
                    .foregroundStyle(Color.brandTextSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(1)
            }
        }
    }
}

@Observable @MainActor
final class ForYouViewModel {
    enum Mode: String { case recent, topRated = "top_rated" }

    var mode: Mode = .recent
    var tab: ContentType = .tv
    var shows: [MediaItem] = []
    var movies: [MediaItem] = []
    var seedCount: Int?
    var isLoading = false
    var errorMessage: String?

    func load(client: APIClient) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let response = try await client.recommendationsForYouDecoded(mode: mode.rawValue)
            shows = response.shows.map { $0.withType(.tv) }
            movies = response.movies.map { $0.withType(.movie) }
            seedCount = response.seedCount
        } catch is CancellationError {
            // ignore
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
