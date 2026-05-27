import SwiftUI
import NukeUI

struct ShelvesView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var viewModel = ShelvesViewModel()
    @State private var showingCreate = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                LargeTitleHeader(
                    eyebrow: shelvesSubtitle,
                    title: "Shelves",
                    accent: nil
                ) {
                    Button {
                        showingCreate = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(BrandTheme.primaryText)
                            .frame(width: 38, height: 38)
                            .background(BrandTheme.primarySoft, in: RoundedRectangle(cornerRadius: 13))
                    }
                    .buttonStyle(.plain)
                }

                if viewModel.isLoading && viewModel.shelves.isEmpty {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, 32)
                } else if let error = viewModel.errorMessage, viewModel.shelves.isEmpty {
                    InlineErrorBanner(message: error) { Task { await viewModel.load(client: env.apiClient) } }
                        .padding(.horizontal, 16)
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.shelves) { shelf in
                            NavigationLink {
                                ShelfDetailView(shelf: shelf)
                            } label: {
                                shelfRow(shelf)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button("Rename") {
                                    viewModel.renamingShelf = shelf
                                    viewModel.renameDraft = shelf.name
                                }
                                Button("Delete", role: .destructive) {
                                    Task { await viewModel.delete(shelf, client: env.apiClient) }
                                }
                            }
                        }
                        newShelfButton
                    }
                    .padding(.horizontal, 16)
                }
            }
            .padding(.bottom, 22)
        }
        .pageBackground()
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load(client: env.apiClient) }
        .refreshable { await viewModel.load(client: env.apiClient) }
        .sheet(isPresented: $showingCreate) {
            CreateShelfSheet(
                onSubmit: { name, desc in
                    Task { await viewModel.create(name: name, description: desc, client: env.apiClient) }
                }
            )
        }
        .alert(
            "Rename shelf",
            isPresented: Binding(
                get: { viewModel.renamingShelf != nil },
                set: { if !$0 { viewModel.renamingShelf = nil } }
            )
        ) {
            TextField("Name", text: $viewModel.renameDraft)
            Button("Cancel", role: .cancel) { viewModel.renamingShelf = nil }
            Button("Save") {
                Task { await viewModel.rename(client: env.apiClient) }
            }
        }
    }

    private var shelvesSubtitle: String {
        let count = viewModel.shelves.count
        let total = viewModel.shelves.reduce(0) { $0 + ($1.itemCount ?? 0) }
        return "\(count) shelves · \(total) titles"
    }

    private func shelfRow(_ shelf: ShelfEntry) -> some View {
        HStack(alignment: .top, spacing: 14) {
            posterStack(for: shelf)
                .frame(width: 70, height: 90)

            VStack(alignment: .leading, spacing: 4) {
                EyebrowLabel(text: "Personal shelf")

                Text(shelf.name)
                    .font(BrandFont.serif(19))
                    .foregroundStyle(BrandTheme.text)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                if let description = shelf.description, !description.isEmpty {
                    Text(description)
                        .font(BrandFont.sans(12))
                        .foregroundStyle(BrandTheme.textMuted)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 6)

                HStack {
                    Text("\(shelf.itemCount ?? 0) TITLES")
                        .font(BrandFont.mono(11, weight: .medium))
                        .tracking(0.6)
                        .foregroundStyle(BrandTheme.textDim)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(BrandTheme.textDim)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(BrandTheme.surface, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(BrandTheme.border, lineWidth: 1))
    }

    /// Three poster rectangles fanned out with rotation + offset to suggest
    /// a stack of titles on the shelf. Uses the backend's `preview_posters`
    /// (TMDB paths) when available; pads with tinted blanks behind the real
    /// posters so a shelf with 1 or 2 items still shows a full three-card
    /// stack. The real posters always render in front of the blanks.
    private func posterStack(for shelf: ShelfEntry) -> some View {
        let posters = Array((shelf.previewPosters ?? []).prefix(3))
        let totalSlots = 3
        let blanksCount = totalSlots - posters.count
        let palette = Self.tintPalette
        let base = abs(shelf.id)

        return ZStack {
            ForEach(0..<totalSlots, id: \.self) { idx in
                let tint = palette[(base + idx * 2) % palette.count]

                Group {
                    if idx < blanksCount {
                        // Back layers — blank tinted card.
                        tint
                    } else {
                        // Front layers — real TMDB poster, falling back to
                        // the tint while the image loads or 404s.
                        let posterIdx = idx - blanksCount
                        LazyImage(url: TMDBImage.poster(posters[posterIdx], size: "w185")) { state in
                            if let image = state.image {
                                image.resizable().scaledToFill()
                            } else {
                                tint
                            }
                        }
                    }
                }
                .frame(width: 58, height: 86)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
                .rotationEffect(.degrees(Double(idx - 1) * -4))
                .offset(x: CGFloat(idx) * 6 - 6, y: CGFloat(idx) * 1.5 - 1.5)
                .shadow(color: .black.opacity(0.4), radius: 4, y: 2)
            }
        }
    }

    private static let tintPalette: [Color] = [
        Color(hex: 0xC07A2A), // amber
        Color(hex: 0xC74A55), // rose
        Color(hex: 0x2D2D2D), // charcoal
        Color(hex: 0x6B4A8C), // violet
        Color(hex: 0x4A6B9B), // blue
        Color(hex: 0x3D8B7A), // teal
        Color(hex: 0x10B981)  // emerald
    ]

    /// Dashed-border "New shelf" tile pinned at the bottom of the list.
    private var newShelfButton: some View {
        Button {
            showingCreate = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 15, weight: .semibold))
                Text("New shelf")
                    .font(BrandFont.sans(14, weight: .medium))
            }
            .foregroundStyle(BrandTheme.primaryText)
            .frame(maxWidth: .infinity)
            .padding(16)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(BrandTheme.borderStrong, style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            )
        }
        .buttonStyle(.plain)
    }
}

@Observable @MainActor
final class ShelvesViewModel {
    var shelves: [ShelfEntry] = []
    var isLoading = false
    var errorMessage: String?
    var renamingShelf: ShelfEntry?
    var renameDraft: String = ""

    func load(client: APIClient) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            shelves = try await client.shelves()
        } catch is CancellationError {
            // ignore
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func create(name: String, description: String?, client: APIClient) async {
        guard !name.isEmpty else { return }
        do {
            let new = try await client.shelfCreate(name: name, description: description)
            shelves.append(new)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func rename(client: APIClient) async {
        guard let shelf = renamingShelf, !renameDraft.isEmpty else { return }
        defer { renamingShelf = nil }
        do {
            let updated = try await client.shelfUpdate(shelfID: shelf.id, name: renameDraft)
            if let i = shelves.firstIndex(where: { $0.id == shelf.id }) {
                shelves[i] = updated
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete(_ shelf: ShelfEntry, client: APIClient) async {
        do {
            try await client.shelfDelete(shelfID: shelf.id)
            shelves.removeAll { $0.id == shelf.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct CreateShelfSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var description = ""
    let onSubmit: (String, String?) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("e.g. Comfort movies", text: $name)
                }
                Section("Description (optional)") {
                    TextField("What's this shelf for?", text: $description, axis: .vertical)
                        .lineLimit(2...5)
                }
            }
            .navigationTitle("New shelf")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        onSubmit(name, description.isEmpty ? nil : description)
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}
