import SwiftUI

/// Inline view embedded inside the Social tab. Shows pending invitations at
/// the top (with accept/decline buttons), followed by the user's joined
/// groups. Tapping a group routes to `GroupDetailView`; tapping the `+` in
/// the section header opens the create-group sheet.
struct MyGroupsView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(NotificationsModel.self) private var notifications
    @State private var viewModel = MyGroupsViewModel()
    @State private var showCreate = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if viewModel.isLoading && !viewModel.hasLoaded {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, 32)
                } else if let error = viewModel.errorMessage, !viewModel.hasLoaded {
                    InlineErrorBanner(message: error) { Task { await viewModel.load(client: env.apiClient) } }
                        .padding(.horizontal, 16)
                } else {
                    if !viewModel.invitations.isEmpty {
                        invitationsSection
                    }
                    groupsSection
                }
            }
            .padding(.vertical, 12)
        }
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
        .task { await viewModel.load(client: env.apiClient) }
        .refreshable { await viewModel.load(client: env.apiClient) }
        // Group invite push → re-fetch invitations so they appear immediately.
        .onReceive(NotificationCenter.default.publisher(for: .pushDidRequestRefresh)) { _ in
            Task { await viewModel.load(client: env.apiClient) }
        }
    }

    private var invitationsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle("Pending", accent: "invitations")
                .padding(.horizontal, 16)
            LazyVStack(spacing: 10) {
                ForEach(viewModel.invitations) { invitation in
                    invitationCard(invitation)
                        .padding(.horizontal, 16)
                }
            }
        }
    }

    private func invitationCard(_ invitation: CommunityInvitation) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(BrandTheme.primarySoft)
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: "person.3.fill")
                            .foregroundStyle(BrandTheme.primaryText)
                    )
                VStack(alignment: .leading, spacing: 2) {
                    Text(invitation.community.name)
                        .font(BrandFont.sans(14, weight: .semibold))
                        .foregroundStyle(BrandTheme.text)
                        .lineLimit(2)
                    if let inviter = invitation.invitedBy {
                        Text("Invited by \(inviter.label)")
                            .font(BrandFont.sans(12))
                            .foregroundStyle(BrandTheme.textMuted)
                    }
                }
                Spacer(minLength: 0)
            }
            HStack(spacing: 8) {
                Button {
                    Task { await viewModel.respond(to: invitation, accept: true, client: env.apiClient, notifications: notifications) }
                } label: {
                    Text("Accept")
                        .font(BrandFont.sans(13, weight: .semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(BrandTheme.primary, in: Capsule())
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                Button {
                    Task { await viewModel.respond(to: invitation, accept: false, client: env.apiClient, notifications: notifications) }
                } label: {
                    Text("Decline")
                        .font(BrandFont.sans(13, weight: .semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(BrandTheme.surface2, in: Capsule())
                        .foregroundStyle(BrandTheme.text)
                }
                .buttonStyle(.plain)
                Spacer(minLength: 0)
            }
        }
        .padding(12)
        .background(BrandTheme.surface, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(BrandTheme.border, lineWidth: 1))
    }

    @ViewBuilder
    private var groupsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle("Your", accent: "groups")
                .padding(.horizontal, 16)
            if viewModel.groups.isEmpty {
                ContentUnavailableView(
                    "No groups yet",
                    systemImage: "person.3",
                    description: Text("Browse or create a group to get started.")
                )
                .padding(.top, 16)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(viewModel.groups) { community in
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
            NavigationLink {
                BrowseGroupsView()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                    Text("Browse all groups")
                }
                .font(BrandFont.sans(13, weight: .semibold))
                .foregroundStyle(BrandTheme.primaryText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(BrandTheme.primarySoft, in: RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
        }
    }
}

@Observable @MainActor
final class MyGroupsViewModel {
    var groups: [Community] = []
    var invitations: [CommunityInvitation] = []
    var isLoading = false
    var hasLoaded = false
    var errorMessage: String?

    func load(client: APIClient) async {
        isLoading = true
        errorMessage = nil
        defer {
            isLoading = false
            hasLoaded = true
        }
        async let groupsTask: [Community] = (try? await client.communitiesMine()) ?? []
        async let invsTask: [CommunityInvitation] = (try? await client.communityInvitationsMine()) ?? []
        groups = await groupsTask
        invitations = await invsTask
    }

    /// Accept or decline an invitation. On accept, also pull the latest
    /// `groups` so the new community appears immediately. Optimistically
    /// removes the invitation row so the user gets quick feedback.
    func respond(
        to invitation: CommunityInvitation,
        accept: Bool,
        client: APIClient,
        notifications: NotificationsModel
    ) async {
        let snapshot = invitations
        invitations.removeAll { $0.id == invitation.id }
        do {
            _ = try await client.communityRespondToInvitation(id: invitation.id, accept: accept)
            await notifications.refresh(client: client)
            if accept {
                if let refreshed = try? await client.communitiesMine() {
                    groups = refreshed
                }
            }
        } catch {
            invitations = snapshot
            errorMessage = error.localizedDescription
        }
    }
}
