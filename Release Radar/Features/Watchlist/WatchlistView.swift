import SwiftUI

struct WatchlistView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var viewModel = WatchlistViewModel()

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("My Library")
                .refreshable { await viewModel.load(client: env.apiClient) }
                .task { await viewModel.loadIfNeeded(client: env.apiClient) }
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.items.isEmpty {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = viewModel.errorMessage, viewModel.items.isEmpty {
            ContentUnavailableView("Couldn't load watchlist", systemImage: "exclamationmark.triangle", description: Text(error))
        } else if viewModel.items.isEmpty {
            ContentUnavailableView("Your library is empty", systemImage: "books.vertical", description: Text("Browse Discover to add movies and TV shows."))
        } else {
            List {
                ForEach(viewModel.items) { item in
                    NavigationLink {
                        MediaDetailView(item: item)
                    } label: {
                        MediaCardView(item: item)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            Task { await viewModel.remove(item, client: env.apiClient) }
                        } label: {
                            Label("Remove", systemImage: "trash")
                        }
                    }
                }
            }
            .listStyle(.plain)
        }
    }
}

#Preview {
    WatchlistView()
        .environment(AppEnvironment())
}
