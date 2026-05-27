import SwiftUI

struct ShelfDetailView: View {
    let shelf: ShelfEntry
    @Environment(AppEnvironment.self) private var env
    @State private var movies: [MediaItem] = []
    @State private var shows: [MediaItem] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let description = shelf.description, !description.isEmpty {
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(Color.brandTextSecondary)
                        .padding(.horizontal, 16)
                }

                if isLoading {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, 32)
                } else if let error = errorMessage {
                    InlineErrorBanner(message: error) { Task { await load() } }
                        .padding(.horizontal, 16)
                } else if movies.isEmpty && shows.isEmpty {
                    ContentUnavailableView("Empty shelf", systemImage: "tray", description: Text("Add titles from a movie or show's detail page."))
                } else {
                    if !shows.isEmpty {
                        SectionHeader(title: "TV Shows", subtitle: "\(shows.count)")
                            .padding(.horizontal, 16)
                        grid(items: shows)
                    }
                    if !movies.isEmpty {
                        SectionHeader(title: "Movies", subtitle: "\(movies.count)")
                            .padding(.horizontal, 16)
                        grid(items: movies)
                    }
                }
            }
            .padding(.vertical, 16)
        }
        .navigationTitle(shelf.name)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
    }

    private func grid(items: [MediaItem]) -> some View {
        LazyVGrid(columns: columns, spacing: 16) {
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
                .contextMenu {
                    Button("Remove from shelf", role: .destructive) {
                        Task { await remove(item) }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let data = try await env.apiClient.shelfItems(shelfID: shelf.id)
            let response = try JSONDecoder().decode(ShelfItemsResponse.self, from: data)
            movies = response.movies.map { $0.withType(.movie) }
            shows = response.shows.map { $0.withType(.tv) }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func remove(_ item: MediaItem) async {
        do {
            try await env.apiClient.shelfRemoveItem(shelfID: shelf.id, type: item.contentType, id: item.id)
            movies.removeAll { $0.id == item.id && item.contentType == .movie }
            shows.removeAll { $0.id == item.id && item.contentType == .tv }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct ShelfItemsResponse: Decodable {
    let movies: [MediaItem]
    let shows: [MediaItem]

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        movies = (try? c.decode([MediaItem].self, forKey: .movies)) ?? []
        shows = (try? c.decode([MediaItem].self, forKey: .shows)) ?? []
    }
    enum CodingKeys: String, CodingKey { case movies, shows }
}
