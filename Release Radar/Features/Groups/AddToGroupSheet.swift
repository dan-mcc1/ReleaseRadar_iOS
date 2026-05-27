import SwiftUI

/// Sheet for adding a movie/show to one of the user's groups. Lists every
/// community the user is a member of with edit permission and adds the
/// title via `POST /communities/{id}/media` when tapped.
struct AddToGroupSheet: View {
    let item: MediaItem

    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    @State private var groups: [Community] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var addingTo: Int?
    @State private var addedTo: Set<Int> = []

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Add to group")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Done") { dismiss() }
                    }
                }
                .task { await load() }
        }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading && groups.isEmpty {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = errorMessage, groups.isEmpty {
            InlineErrorBanner(message: error) { Task { await load() } }
                .padding()
        } else if eligible.isEmpty {
            ContentUnavailableView(
                "No eligible groups",
                systemImage: "person.3",
                description: Text("You need to be a member with edit permission to share a title.")
            )
        } else {
            List(eligible) { community in
                Button {
                    Task { await add(to: community) }
                } label: {
                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(bannerColor(community.bannerColor))
                            .frame(width: 36, height: 36)
                            .overlay(
                                Text(initials(community.name))
                                    .font(BrandFont.serif(13))
                                    .foregroundStyle(.white)
                            )
                        VStack(alignment: .leading, spacing: 2) {
                            Text(community.name)
                                .font(BrandFont.sans(14, weight: .semibold))
                                .foregroundStyle(BrandTheme.text)
                            Text(verbatim: "\(community.memberCount) members")
                                .font(BrandFont.mono(10))
                                .foregroundStyle(BrandTheme.textMuted)
                        }
                        Spacer()
                        if addedTo.contains(community.id) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(BrandTheme.primary)
                        } else if addingTo == community.id {
                            ProgressView()
                        }
                    }
                }
                .disabled(addingTo != nil || addedTo.contains(community.id))
            }
        }
    }

    private var eligible: [Community] {
        groups.filter { $0.viewerCanEditMedia }
    }

    // MARK: - Actions

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            groups = try await env.apiClient.communitiesMine()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func add(to community: Community) async {
        addingTo = community.id
        defer { addingTo = nil }
        do {
            _ = try await env.apiClient.communityAddMedia(
                id: community.id,
                contentType: item.contentType.rawValue,
                contentID: item.id
            )
            addedTo.insert(community.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Helpers

    private func initials(_ name: String) -> String {
        let words = name.split(separator: " ").prefix(2)
        return words.compactMap { $0.first.map(String.init) }.joined().uppercased()
    }

    private func bannerColor(_ hex: String?) -> Color {
        if let hex, let parsed = Color(hexString: hex) { return parsed }
        return BrandTheme.primary
    }
}

private extension Color {
    init?(hexString: String) {
        var s = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let value = UInt32(s, radix: 16) else { return nil }
        let r = Double((value >> 16) & 0xFF) / 255.0
        let g = Double((value >> 8) & 0xFF) / 255.0
        let b = Double(value & 0xFF) / 255.0
        self = Color(red: r, green: g, blue: b)
    }
}
