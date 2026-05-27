import SwiftUI

/// Sheet that lets the user pick which of their shelves a given media item
/// should be added to. Use with a `.sheet(isPresented:)` or `.sheet(item:)`.
struct AddToShelfSheet: View {
    let item: MediaItem
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss

    @State private var shelves: [ShelfEntry] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var addingTo: Set<Int> = []

    var body: some View {
        NavigationStack {
            List {
                if isLoading {
                    ProgressView()
                } else if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
                } else if shelves.isEmpty {
                    ContentUnavailableView("No shelves yet", systemImage: "tray", description: Text("Create one from the Shelves screen."))
                } else {
                    ForEach(shelves) { shelf in
                        Button {
                            Task { await add(to: shelf) }
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(Color.brandPrimary)
                                VStack(alignment: .leading) {
                                    Text(shelf.name).foregroundStyle(.white)
                                    if let count = shelf.itemCount {
                                        Text("\(count) items").font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                if addingTo.contains(shelf.id) {
                                    ProgressView()
                                }
                            }
                        }
                        .disabled(addingTo.contains(shelf.id))
                    }
                }
            }
            .navigationTitle("Add to shelf")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task { await load() }
        }
    }

    private func load() async {
        isLoading = true; defer { isLoading = false }
        do {
            shelves = try await env.apiClient.shelves()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func add(to shelf: ShelfEntry) async {
        addingTo.insert(shelf.id)
        defer { addingTo.remove(shelf.id) }
        do {
            _ = try await env.apiClient.shelfAddItem(shelfID: shelf.id, type: item.contentType, id: item.id)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
