import SwiftUI

struct FriendsView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(NotificationsModel.self) private var notifications
    @State private var viewModel = FriendsViewModel()

    var body: some View {
        @Bindable var vm = viewModel
        VStack(spacing: 0) {
            Picker("Tab", selection: $vm.tab) {
                Text("Friends \(viewModel.friends.count)").tag(FriendsViewModel.Tab.friends)
                Text("Requests \(viewModel.incoming.count)").tag(FriendsViewModel.Tab.requests)
                Text("Find").tag(FriendsViewModel.Tab.search)
                Text("Sent \(viewModel.outgoing.count)").tag(FriendsViewModel.Tab.sent)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.top, 12)

            content
        }
        .task {
            await viewModel.load(client: env.apiClient)
            await notifications.refresh(client: env.apiClient)
        }
        .refreshable {
            await viewModel.load(client: env.apiClient)
            await notifications.refresh(client: env.apiClient)
        }
    }

    @ViewBuilder
    private var content: some View {
        // Only show the full-screen spinner on the very first load. Once we
        // have data, keep rendering it while pull-to-refresh runs in the
        // background so the list doesn't blink to a spinner mid-refresh.
        if viewModel.isLoading && !viewModel.hasLoaded {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = viewModel.errorMessage, !viewModel.hasLoaded {
            InlineErrorBanner(message: error) { Task { await viewModel.load(client: env.apiClient) } }
                .padding(16)
        } else {
            switch viewModel.tab {
            case .friends: friendsList
            case .requests: incomingList
            case .search: SearchPeopleView()
            case .sent: outgoingList
            }
        }
    }

    @ViewBuilder
    private var friendsList: some View {
        if viewModel.friends.isEmpty {
            ContentUnavailableView("No friends yet", systemImage: "person.2", description: Text("Try the Find tab to start adding friends."))
        } else {
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(viewModel.friends) { friend in
                        NavigationLink {
                            FriendProfileView(username: friend.username ?? "")
                        } label: {
                            personRow(username: friend.username, avatarKey: friend.avatarKey, trailing: {
                                Button(role: .destructive) {
                                    Task { await viewModel.removeFriend(friend, client: env.apiClient) }
                                } label: {
                                    Image(systemName: "person.fill.xmark")
                                }
                                .buttonStyle(.bordered)
                            })
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
            }
        }
    }

    @ViewBuilder
    private var incomingList: some View {
        if viewModel.incoming.isEmpty {
            ContentUnavailableView("No requests", systemImage: "person.crop.circle.badge.plus", description: Text("Pending friend requests will show here."))
        } else {
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(viewModel.incoming) { req in
                        requestCard(req, incoming: true)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
            }
        }
    }

    @ViewBuilder
    private var outgoingList: some View {
        if viewModel.outgoing.isEmpty {
            ContentUnavailableView("Nothing pending", systemImage: "paperplane", description: Text("Requests you've sent will appear here."))
        } else {
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(viewModel.outgoing) { req in
                        requestCard(req, incoming: false)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
            }
        }
    }

    private func requestCard(_ req: FriendRequest, incoming: Bool) -> some View {
        HStack(spacing: 10) {
            AvatarView(username: req.username, size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(req.username ?? "—")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                if let message = req.message, !message.isEmpty {
                    Text(message).font(.caption).foregroundStyle(Color.brandTextSecondary).lineLimit(2)
                } else if let ago = TimeAgo.format(req.createdAt) {
                    Text(ago).font(.caption).foregroundStyle(Color.brandTextSecondary)
                }
            }
            Spacer()
            if incoming {
                Button {
                    Task {
                        await viewModel.respond(req, accept: true, client: env.apiClient)
                        await notifications.refresh(client: env.apiClient)
                    }
                } label: { Text("Accept").font(.caption.weight(.semibold)) }
                    .buttonStyle(.borderedProminent)
                Button(role: .destructive) {
                    Task {
                        await viewModel.respond(req, accept: false, client: env.apiClient)
                        await notifications.refresh(client: env.apiClient)
                    }
                } label: { Text("Decline").font(.caption) }
                    .buttonStyle(.bordered)
            } else {
                Button(role: .destructive) {
                    Task { await viewModel.cancelRequest(req, client: env.apiClient) }
                } label: { Text("Cancel").font(.caption) }
                    .buttonStyle(.bordered)
            }
        }
        .padding(12)
        .background(Color.brandSurface, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.brandBorder, lineWidth: 1))
    }

    @ViewBuilder
    private func personRow<Trailing: View>(
        username: String?,
        avatarKey: String?,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack(spacing: 10) {
            AvatarView(username: username, avatarKey: avatarKey, size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(username ?? "—").font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                if let username {
                    Text("@\(username)").font(.caption).foregroundStyle(Color.brandTextSecondary)
                }
            }
            Spacer()
            trailing()
        }
        .padding(12)
        .background(Color.brandSurface, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.brandBorder, lineWidth: 1))
    }
}

@Observable @MainActor
final class FriendsViewModel {
    enum Tab { case friends, requests, search, sent }

    var tab: Tab = .friends
    var friends: [FriendEntry] = []
    var incoming: [FriendRequest] = []
    var outgoing: [FriendRequest] = []
    var isLoading = false
    /// Flipped after the first successful or failed load — used by the view
    /// to decide between showing the full-screen spinner vs. keeping the
    /// existing data on subsequent refreshes.
    var hasLoaded = false
    var errorMessage: String?

    func load(client: APIClient) async {
        isLoading = true
        errorMessage = nil
        defer {
            isLoading = false
            hasLoaded = true
        }
        async let f: [FriendEntry] = (try? await client.friendsListDecoded()) ?? []
        async let inc: [FriendRequest] = (try? await client.friendsIncomingRequestsDecoded()) ?? []
        async let out: [FriendRequest] = (try? await client.friendsOutgoingRequestsDecoded()) ?? []
        friends = await f
        incoming = await inc
        outgoing = await out
    }

    func respond(_ req: FriendRequest, accept: Bool, client: APIClient) async {
        do {
            try await client.friendsRespond(friendshipID: req.id, accept: accept)
            incoming.removeAll { $0.id == req.id }
            if accept { await load(client: client) }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func cancelRequest(_ req: FriendRequest, client: APIClient) async {
        do {
            try await client.friendsCancelRequest(friendshipID: req.id)
            outgoing.removeAll { $0.id == req.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func removeFriend(_ friend: FriendEntry, client: APIClient) async {
        do {
            try await client.friendsRemove(friendID: friend.id)
            friends.removeAll { $0.id == friend.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Search People

struct SearchPeopleView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var query = ""
    @State private var results: [FriendSearchEntry] = []
    @State private var suggestions: [FriendSuggestion] = []
    @State private var isSearching = false
    @State private var isLoadingSuggestions = false
    @State private var errorMessage: String?
    @State private var searchTask: Task<Void, Never>?

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                TextField("Search by username", text: $query)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .submitLabel(.search)
                    .onSubmit { Task { await runSearch() } }
                    .onChange(of: query) { _, _ in scheduleSearch() }
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)

                if let error = errorMessage {
                    InlineErrorBanner(message: error).padding(.horizontal, 16)
                }

                if trimmedQuery.isEmpty {
                    suggestionsSection
                } else if isSearching {
                    ProgressView().padding(.top, 24)
                } else if results.isEmpty {
                    ContentUnavailableView("No matches", systemImage: "magnifyingglass", description: Text("Try a different name."))
                } else {
                    searchResults
                }
            }
        }
        .task { await loadSuggestions() }
    }

    @ViewBuilder
    private var suggestionsSection: some View {
        SectionHeader(title: "Suggested for you", subtitle: "Friends of friends and popular users")
            .padding(.horizontal, 16)
            .padding(.top, 4)

        if isLoadingSuggestions && suggestions.isEmpty {
            ProgressView().padding(.top, 16)
        } else if suggestions.isEmpty {
            ContentUnavailableView(
                "No suggestions yet",
                systemImage: "person.crop.circle.dashed",
                description: Text("Add a few friends to get personalized suggestions.")
            )
        } else {
            LazyVStack(spacing: 10) {
                ForEach(suggestions) { person in
                    NavigationLink {
                        FriendProfileView(username: person.username)
                    } label: {
                        suggestionRow(person)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func suggestionRow(_ person: FriendSuggestion) -> some View {
        HStack(spacing: 10) {
            AvatarView(username: person.username, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(person.username).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                Text(suggestionSubtitle(person)).font(.caption).foregroundStyle(Color.brandTextSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(Color.brandTextSecondary)
        }
        .padding(12)
        .background(Color.brandSurface, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.brandBorder, lineWidth: 1))
    }

    private func suggestionSubtitle(_ p: FriendSuggestion) -> String {
        if let n = p.mutualFriends, n > 0 {
            return "\(n) mutual friend\(n == 1 ? "" : "s")"
        }
        switch p.reason {
        case "popular": return "Popular on Release Radar"
        case "mutual_friends": return "Friend of a friend"
        default: return "@\(p.username)"
        }
    }

    @ViewBuilder
    private var searchResults: some View {
        LazyVStack(spacing: 10) {
            ForEach(results) { person in
                NavigationLink {
                    FriendProfileView(username: person.username)
                } label: {
                    HStack(spacing: 10) {
                        AvatarView(username: person.username, size: 40)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(person.username).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                            Text("@\(person.username)").font(.caption).foregroundStyle(Color.brandTextSecondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(Color.brandTextSecondary)
                    }
                    .padding(12)
                    .background(Color.brandSurface, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.brandBorder, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
    }

    /// Debounced live search — fires 300ms after the user stops typing.
    private func scheduleSearch() {
        searchTask?.cancel()
        let q = trimmedQuery
        if q.isEmpty {
            results = []
            errorMessage = nil
            return
        }
        searchTask = Task { [q] in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await performSearch(q: q)
        }
    }

    private func runSearch() async {
        searchTask?.cancel()
        let q = trimmedQuery
        guard !q.isEmpty else { results = []; return }
        await performSearch(q: q)
    }

    private func performSearch(q: String) async {
        isSearching = true
        errorMessage = nil
        defer { isSearching = false }
        do {
            results = try await env.apiClient.friendsSearch(query: q)
        } catch is CancellationError {
            // user typed more — ignore
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadSuggestions() async {
        guard suggestions.isEmpty else { return }
        isLoadingSuggestions = true
        defer { isLoadingSuggestions = false }
        do {
            suggestions = try await env.apiClient.friendsSuggestionsDecoded()
        } catch {
            // Silent — the search input still works.
        }
    }
}
