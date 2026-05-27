import SwiftUI
import NukeUI

/// Shows the signed-in user's collections, bucketed into Favorites,
/// In Progress, and Finished. Favorites omit the progress strip; the other
/// two segments overlay a small bar so the user can see at-a-glance how
/// close they are to clearing a franchise.
struct MyCollectionsView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var viewModel = MyCollectionsViewModel()
    @State private var segment: Segment = .favorites

    enum Segment: String, CaseIterable, Identifiable {
        case favorites, inProgress, finished
        var id: String { rawValue }
        var title: String {
            switch self {
            case .favorites: "Favorites"
            case .inProgress: "In progress"
            case .finished: "Finished"
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                LargeTitleHeader(
                    eyebrow: "Your library · Collections",
                    title: "My",
                    accent: "collections"
                ) { EmptyView() }

                Text("Franchises and movie series you've favorited, finished, or are working through.")
                    .font(BrandFont.sans(13))
                    .foregroundStyle(BrandTheme.textMuted)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 4)

                segmentChips
                    .padding(.horizontal, 20)

                content
            }
            .padding(.bottom, 24)
        }
        .pageBackground()
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load(client: env.apiClient) }
        .refreshable { await viewModel.load(client: env.apiClient) }
    }

    private var segmentChips: some View {
        HStack(spacing: 8) {
            ForEach(Segment.allCases) { s in
                FilterChip(
                    label: s.title,
                    count: viewModel.count(for: s),
                    isActive: segment == s,
                    action: { segment = s }
                )
            }
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && !viewModel.hasLoaded {
            ProgressView().frame(maxWidth: .infinity).padding(.top, 48)
        } else if let error = viewModel.errorMessage, !viewModel.hasLoaded {
            InlineErrorBanner(message: error) { Task { await viewModel.load(client: env.apiClient) } }
                .padding(.horizontal, 16)
        } else {
            let items = viewModel.entries(for: segment)
            if items.isEmpty {
                ContentUnavailableView(
                    emptyTitle,
                    systemImage: "rectangle.stack",
                    description: Text(emptyMessage)
                )
                .padding(.top, 32)
            } else {
                grid(items: items)
            }
        }
    }

    private var emptyTitle: String {
        switch segment {
        case .favorites: "No favorite collections yet"
        case .inProgress: "Nothing in progress"
        case .finished: "Nothing finished"
        }
    }

    private var emptyMessage: String {
        switch segment {
        case .favorites: "Tap the heart on a collection's page to save it here."
        case .inProgress: "Start watching a franchise to track your progress."
        case .finished: "Completed franchises will land here."
        }
    }

    private func grid(items: [MyCollectionEntry]) -> some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 12, alignment: .top),
                GridItem(.flexible(), spacing: 12, alignment: .top),
                GridItem(.flexible(), spacing: 12, alignment: .top)
            ],
            spacing: 18
        ) {
            ForEach(items) { entry in
                NavigationLink {
                    CollectionInfoView(collectionID: entry.id)
                } label: {
                    cell(for: entry, showProgress: segment != .favorites)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
    }

    private func cell(for entry: MyCollectionEntry, showProgress: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .bottomLeading) {
                Color.clear
                    .aspectRatio(2.0 / 3.0, contentMode: .fit)
                    .overlay(
                        LazyImage(url: TMDBImage.poster(entry.posterPath)) { state in
                            if let image = state.image { image.resizable().scaledToFill() }
                            else { BrandTheme.surface2 }
                        }
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                if showProgress,
                   let released = entry.releasedParts, released > 0,
                   let watched = entry.watchedParts {
                    progressOverlay(watched: watched, released: released)
                }
            }

            Text(entry.name)
                .font(BrandFont.sans(12.5, weight: .semibold))
                .foregroundStyle(BrandTheme.text)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            if showProgress,
               let released = entry.releasedParts,
               let watched = entry.watchedParts {
                Text("\(watched) / \(released)")
                    .font(BrandFont.mono(10, weight: .medium))
                    .foregroundStyle(BrandTheme.textDim)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private func progressOverlay(watched: Int, released: Int) -> some View {
        let fraction = released > 0 ? min(1.0, Double(watched) / Double(released)) : 0
        return VStack(spacing: 0) {
            Spacer()
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Rectangle().fill(.black.opacity(0.45))
                    Rectangle().fill(BrandTheme.primary)
                        .frame(width: proxy.size.width * fraction)
                }
            }
            .frame(height: 4)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

@Observable @MainActor
final class MyCollectionsViewModel {
    var response: MyCollectionsResponse?
    var isLoading = false
    var errorMessage: String?
    var hasLoaded = false

    func load(client: APIClient) async {
        isLoading = true
        errorMessage = nil
        defer {
            isLoading = false
            hasLoaded = true
        }
        do {
            response = try await client.collectionsMine()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func entries(for segment: MyCollectionsView.Segment) -> [MyCollectionEntry] {
        guard let response else { return [] }
        switch segment {
        case .favorites: return response.favorites
        case .inProgress: return response.inProgress
        case .finished: return response.finished
        }
    }

    func count(for segment: MyCollectionsView.Segment) -> Int {
        entries(for: segment).count
    }
}
