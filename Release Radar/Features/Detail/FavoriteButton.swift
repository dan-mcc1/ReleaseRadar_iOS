import SwiftUI

/// Heart-icon toolbar button that loads the current favorite status on appear
/// and toggles it via `/favorites/add` / `/favorites/remove`. Optimistic with
/// rollback on failure.
struct FavoriteButton: View {
    let item: MediaItem
    @Environment(AppEnvironment.self) private var env
    @State private var isFavorited = false
    @State private var isLoaded = false
    @State private var isSaving = false

    var body: some View {
        Button {
            Task { await toggle() }
        } label: {
            Image(systemName: isFavorited ? "heart.fill" : "heart")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(isFavorited ? Color.pink : Color.primary)
        }
        .disabled(!isLoaded || isSaving)
        .task { await load() }
    }

    private func load() async {
        do {
            let response = try await env.apiClient.favoriteStatus(type: item.contentType, id: item.id)
            isFavorited = response.favorited
        } catch {
            // Silent — leave default state.
        }
        isLoaded = true
    }

    private func toggle() async {
        let previous = isFavorited
        isFavorited.toggle()
        isSaving = true
        defer { isSaving = false }
        do {
            if isFavorited {
                _ = try await env.apiClient.favoriteAdd(type: item.contentType, id: item.id)
            } else {
                _ = try await env.apiClient.favoriteRemove(type: item.contentType, id: item.id)
            }
        } catch {
            isFavorited = previous
        }
    }
}
