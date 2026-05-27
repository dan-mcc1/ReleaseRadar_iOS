import SwiftUI

/// Public-group discovery page. Search field on top, scrollable list of
/// community cards below. Tapping a card pushes the group detail; the
/// `+` button in the toolbar opens the create-group sheet.
struct BrowseGroupsView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var viewModel = BrowseGroupsViewModel()
    @State private var showCreate = false

    var body: some View {
        @Bindable var vm = viewModel
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                LargeTitleHeader(
                    eyebrow: "Find your people",
                    title: "Browse",
                    accent: "groups"
                ) { EmptyView() }

                searchField
                    .padding(.horizontal, 16)

                if vm.isLoading && vm.entries.isEmpty {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, 48)
                } else if let error = vm.errorMessage, vm.entries.isEmpty {
                    InlineErrorBanner(message: error) { Task { await viewModel.load(client: env.apiClient) } }
                        .padding(.horizontal, 16)
                } else if vm.entries.isEmpty {
                    ContentUnavailableView(
                        "No groups found",
                        systemImage: "person.3",
                        description: Text("Try a different search, or start your own.")
                    )
                    .padding(.top, 32)
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(vm.entries) { community in
                            NavigationLink {
                                GroupDetailView(slug: community.slug)
                            } label: {
                                GroupCard(community: community)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            .padding(.bottom, 24)
        }
        .pageBackground()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showCreate = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showCreate) {
            CreateGroupSheet { _ in
                Task { await viewModel.load(client: env.apiClient) }
            }
        }
        .task { await viewModel.loadIfNeeded(client: env.apiClient) }
    }

    private var searchField: some View {
        @Bindable var vm = viewModel
        return HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(BrandTheme.textMuted)
            TextField("Search groups", text: $vm.query)
                .font(BrandFont.sans(14))
                .foregroundStyle(BrandTheme.text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .onSubmit { Task { await viewModel.load(client: env.apiClient) } }
            if !vm.query.isEmpty {
                Button {
                    vm.query = ""
                    Task { await viewModel.load(client: env.apiClient) }
                } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(BrandTheme.textMuted) }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(BrandTheme.surface, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(BrandTheme.border, lineWidth: 1))
    }
}

@Observable @MainActor
final class BrowseGroupsViewModel {
    var query: String = ""
    var entries: [Community] = []
    var isLoading = false
    var errorMessage: String?
    private var hasLoaded = false

    func loadIfNeeded(client: APIClient) async {
        guard !hasLoaded else { return }
        await load(client: client)
    }

    func load(client: APIClient) async {
        isLoading = true
        errorMessage = nil
        defer {
            isLoading = false
            hasLoaded = true
        }
        do {
            entries = try await client.communitiesBrowse(query: query.isEmpty ? nil : query)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

/// Shared card used on Browse, My Groups, and the My Groups invitation
/// list. Banner colour comes from the community's `banner_color` field
/// (hex string) — falls back to the brand emerald when missing.
struct GroupCard: View {
    let community: Community

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 12)
                .fill(bannerColor)
                .frame(width: 56, height: 56)
                .overlay(
                    Text(initials)
                        .font(BrandFont.serif(20))
                        .foregroundStyle(.white)
                )
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(community.name)
                        .font(BrandFont.sans(15, weight: .semibold))
                        .foregroundStyle(BrandTheme.text)
                        .lineLimit(1)
                    if !community.isPublic {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(BrandTheme.textMuted)
                    }
                    Spacer(minLength: 0)
                }
                if let description = community.description, !description.isEmpty {
                    Text(description)
                        .font(BrandFont.sans(12.5))
                        .foregroundStyle(BrandTheme.textMuted)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                HStack(spacing: 8) {
                    Text(verbatim: "\(community.memberCount) members")
                        .font(BrandFont.mono(10, weight: .medium))
                        .foregroundStyle(BrandTheme.textDim)
                    if let role = community.viewerRole {
                        Text(role.capitalized)
                            .font(BrandFont.mono(10, weight: .semibold))
                            .tracking(0.6)
                            .foregroundStyle(BrandTheme.primaryText)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(BrandTheme.primarySoft, in: Capsule())
                    }
                }
            }
        }
        .padding(12)
        .background(BrandTheme.surface, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(BrandTheme.border, lineWidth: 1))
    }

    private var initials: String {
        let words = community.name.split(separator: " ").prefix(2)
        let letters = words.compactMap { $0.first.map(String.init) }
        return letters.joined().uppercased()
    }

    private var bannerColor: Color {
        if let hex = community.bannerColor, let parsed = Color(hexString: hex) {
            return parsed
        }
        return BrandTheme.primary
    }
}

// MARK: - Color hex helper

private extension Color {
    /// Parse a 6-digit `#RRGGBB` or `RRGGBB` hex string. Returns nil for
    /// malformed input so the caller can fall back to the brand colour.
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
