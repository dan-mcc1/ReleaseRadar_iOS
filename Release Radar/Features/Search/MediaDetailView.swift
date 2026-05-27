import SwiftUI

/// Dispatches to `MovieInfoView` or `ShowInfoView` based on the item's content type.
/// Acts as the single entry point used by Search, Library, Watchlist, and recommendation links.
struct MediaDetailView: View {
    let item: MediaItem
    @State private var showingAddToShelf = false
    @State private var showingAddToGroup = false

    var body: some View {
        Group {
            switch item.contentType {
            case .movie:
                MovieInfoView(item: item)
            case .tv:
                ShowInfoView(item: item)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                FavoriteButton(item: item)
            }
            ToolbarItem(placement: .topBarTrailing) {
                RecommendToolbarButton(item: item)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showingAddToShelf = true
                    } label: {
                        Label("Add to shelf…", systemImage: "books.vertical")
                    }
                    Button {
                        showingAddToGroup = true
                    } label: {
                        Label("Add to group…", systemImage: "person.3")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingAddToShelf) {
            AddToShelfSheet(item: item)
        }
        .sheet(isPresented: $showingAddToGroup) {
            AddToGroupSheet(item: item)
        }
    }
}
