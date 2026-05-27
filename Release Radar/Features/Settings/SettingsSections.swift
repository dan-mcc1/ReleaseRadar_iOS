import SwiftUI

// MARK: - Profile section

struct SettingsProfileSection: View {
    @Environment(AppEnvironment.self) private var env
    @State private var user: AppUser?
    @State private var username: String = ""
    @State private var displayName: String = ""
    @State private var bio: String = ""
    @State private var avatarKey: String?
    @State private var saving = false
    @State private var errorMessage: String?
    @State private var status: String?

    var body: some View {
        Form {
            Section("Avatar") {
                let columns = [GridItem(.adaptive(minimum: 56))]
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(AvatarPreset.allCases) { preset in
                        Button {
                            avatarKey = preset.rawValue
                        } label: {
                            Circle()
                                .fill(preset.color)
                                .frame(width: 48, height: 48)
                                .overlay(
                                    Circle().stroke(avatarKey == preset.rawValue ? Color.white : Color.clear, lineWidth: 3)
                                )
                        }
                    }
                }
                .padding(.vertical, 4)
                Button("Save avatar") {
                    Task { await saveAvatar() }
                }
                .disabled(avatarKey == nil || saving)
            }

            Section {
                TextField("Display name", text: $displayName)
                    .textInputAutocapitalization(.words)
                Button("Save display name") {
                    Task { await saveDisplayName() }
                }
                .disabled(saving)
            } header: {
                Text("Display name")
            } footer: {
                Text("Shown next to your username on activity, posts, and friend cards.")
            }

            Section("Username") {
                TextField("Username", text: $username)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                Button("Save username") {
                    Task { await saveUsername() }
                }
                .disabled(username.isEmpty || saving)
            }

            Section("Bio") {
                TextField("Tell people about yourself", text: $bio, axis: .vertical)
                    .lineLimit(3...6)
                Button("Save bio") {
                    Task { await saveBio() }
                }
                .disabled(saving)
            }

            if let status { Text(status).foregroundStyle(.green) }
            if let errorMessage { Text(errorMessage).foregroundStyle(.red) }
        }
        .navigationTitle("Profile")
        .task { await load() }
    }

    private func load() async {
        do {
            let me = try await env.apiClient.currentUser()
            user = me
            username = me.username ?? ""
            displayName = me.displayName ?? ""
            bio = me.bio ?? ""
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func saveAvatar() async {
        saving = true; defer { saving = false }
        do {
            _ = try await env.apiClient.userUpdateAvatar(avatarKey: avatarKey)
            status = "Avatar saved"
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func saveUsername() async {
        saving = true; defer { saving = false }
        do {
            _ = try await env.apiClient.userUpdateUsername(newUsername: username)
            status = "Username saved"
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func saveDisplayName() async {
        saving = true; defer { saving = false }
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            // Send nil when blank so the backend clears the field instead
            // of storing an empty string.
            _ = try await env.apiClient.userUpdateDisplayName(
                newDisplayName: trimmed.isEmpty ? nil : trimmed
            )
            status = "Display name saved"
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func saveBio() async {
        saving = true; defer { saving = false }
        do {
            _ = try await env.apiClient.userUpdateBio(bio: bio.isEmpty ? nil : bio)
            status = "Bio saved"
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Notifications

struct SettingsNotificationsSection: View {
    @Environment(AppEnvironment.self) private var env
    @State private var prefs: NotificationPreferences?
    @State private var saving = false
    @State private var errorMessage: String?

    @State private var pushEnabled: Bool = true
    @State private var pushNotifyEpisodeAir: Bool = true
    @State private var leadMinutes: Int = 0
    @State private var emailEnabled: Bool = true
    @State private var frequency: String = "daily"
    @State private var notifyNewSeasons: Bool = true
    @State private var notifyStreamingChanges: Bool = true
    @State private var notifyTrailers: Bool = true
    @State private var digestHour: Int = 9

    /// Lead-time choices for the episode-air alert. The backend stores
    /// `episode_alert_lead_minutes` and uses 0 to mean "fire at the moment
    /// the episode starts". Steps go up in 15-minute increments to an hour
    /// because anything further out feels like spam.
    private let leadOptions: [Int] = [0, 15, 30, 45, 60]

    var body: some View {
        Form {
            Section {
                Toggle("Push notifications", isOn: $pushEnabled)
            } footer: {
                Text("Master switch for all push alerts on this account. Turn off to silence pushes across every device.")
            }

            if pushEnabled {
                Section {
                    Toggle("Episode starting", isOn: $pushNotifyEpisodeAir)
                    if pushNotifyEpisodeAir {
                        Picker("When", selection: $leadMinutes) {
                            ForEach(leadOptions, id: \.self) { mins in
                                Text(leadLabel(for: mins)).tag(mins)
                            }
                        }
                    }
                } header: {
                    Text("Episode alerts")
                } footer: {
                    Text("Get notified when an episode from your watchlist airs.")
                }
            }

            Section("Email") {
                Toggle("Email notifications", isOn: $emailEnabled)
                if emailEnabled {
                    Picker("Digest frequency", selection: $frequency) {
                        Text("Daily").tag("daily")
                        Text("Weekly").tag("weekly")
                        Text("Monthly").tag("monthly")
                    }
                    Stepper("Digest hour: \(digestHour):00", value: $digestHour, in: 0...23)
                }
            }
            Section("Alerts") {
                Toggle("New seasons", isOn: $notifyNewSeasons)
                Toggle("Streaming changes", isOn: $notifyStreamingChanges)
                Toggle("New trailers", isOn: $notifyTrailers)
            }
            Section {
                Button("Save changes") {
                    Task { await save() }
                }
                .disabled(saving)
            }
            if let errorMessage { Text(errorMessage).foregroundStyle(.red) }
        }
        .navigationTitle("Notifications")
        .task { await load() }
    }

    private func leadLabel(for mins: Int) -> String {
        if mins == 0 { return "At showtime" }
        return "\(mins) minutes before"
    }

    private func load() async {
        do {
            let p = try await env.apiClient.notificationPreferences()
            prefs = p
            pushEnabled = p.pushNotificationsEnabled ?? true
            pushNotifyEpisodeAir = p.pushNotifyEpisodeAir ?? true
            leadMinutes = p.episodeAlertLeadMinutes ?? 0
            emailEnabled = p.emailNotifications ?? true
            frequency = p.notificationFrequency ?? "daily"
            notifyNewSeasons = p.notifyNewSeasons ?? true
            notifyStreamingChanges = p.notifyStreamingChanges ?? true
            notifyTrailers = p.notifyTrailers ?? true
            digestHour = p.digestHour ?? 9
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func save() async {
        saving = true; defer { saving = false }
        do {
            try await env.apiClient.updateNotificationPreferences(
                emailNotifications: emailEnabled,
                notificationFrequency: frequency,
                profileVisibility: nil,
                notifyNewSeasons: notifyNewSeasons,
                notifyStreamingChanges: notifyStreamingChanges,
                notifyTrailers: notifyTrailers,
                digestHour: digestHour,
                digestTimezone: TimeZone.current.identifier,
                pushNotificationsEnabled: pushEnabled,
                pushNotifyEpisodeAir: pushNotifyEpisodeAir,
                episodeAlertLeadMinutes: leadMinutes
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Streaming services

struct SettingsStreamingSection: View {
    @Environment(AppEnvironment.self) private var env
    @State private var allProviders: [StreamingProvider] = []
    @State private var myProviders: [StreamingProvider] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var search = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                TextField("Search providers", text: $search)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal, 16)

                if isLoading {
                    ProgressView().padding(.top, 32)
                } else if let errorMessage {
                    InlineErrorBanner(message: errorMessage).padding(.horizontal, 16)
                } else {
                    if !myProviders.isEmpty {
                        SectionHeader(title: "My services").padding(.horizontal, 16)
                        providerGrid(myProviders, owned: true)
                    }
                    SectionHeader(title: "All providers").padding(.horizontal, 16)
                    providerGrid(filtered(allProviders), owned: false)
                }
            }
            .padding(.vertical, 16)
        }
        .navigationTitle("Streaming")
        .task { await load() }
    }

    private func filtered(_ providers: [StreamingProvider]) -> [StreamingProvider] {
        guard !search.isEmpty else { return providers }
        return providers.filter { $0.name.localizedCaseInsensitiveContains(search) }
    }

    private func providerGrid(_ providers: [StreamingProvider], owned: Bool) -> some View {
        let columns = [GridItem(.adaptive(minimum: 80), spacing: 12)]
        return LazyVGrid(columns: columns, spacing: 12) {
            ForEach(providers) { p in
                Button {
                    Task { await toggle(p, currentlyOwned: owned) }
                } label: {
                    VStack(spacing: 4) {
                        AsyncImageOrPlaceholder(url: TMDBImage.providerLogo(p.logoPath))
                            .frame(width: 60, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(alignment: .topTrailing) {
                                Image(systemName: owned ? "checkmark.circle.fill" : "plus.circle.fill")
                                    .foregroundStyle(owned ? Color.brandPrimary : Color.brandTextSecondary)
                                    .background(Circle().fill(Color.brandBackground))
                                    .offset(x: 6, y: -6)
                            }
                        Text(p.name).font(.caption2).lineLimit(1).foregroundStyle(.white)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
    }

    private func load() async {
        isLoading = true; defer { isLoading = false }
        do {
            async let all = (try? await env.apiClient.streamingProviders()) ?? []
            async let mine = (try? await env.apiClient.streamingMyServices()) ?? []
            allProviders = await all
            myProviders = await mine
        }
    }

    private func toggle(_ provider: StreamingProvider, currentlyOwned: Bool) async {
        do {
            if currentlyOwned {
                _ = try await env.apiClient.streamingRemoveService(providerID: provider.id)
                myProviders.removeAll { $0.id == provider.id }
            } else {
                _ = try await env.apiClient.streamingAddService(providerID: provider.id)
                myProviders.append(provider)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct AsyncImageOrPlaceholder: View {
    let url: URL?
    var body: some View {
        if let url {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty: Color.brandSurfaceElevated
                case .success(let image): image.resizable().scaledToFill()
                case .failure: Color.brandSurfaceElevated.overlay(Image(systemName: "photo").foregroundStyle(.secondary))
                @unknown default: Color.brandSurfaceElevated
                }
            }
        } else {
            Color.brandSurfaceElevated
        }
    }
}

// MARK: - Calendar sync

struct SettingsCalendarSyncSection: View {
    @Environment(AppEnvironment.self) private var env
    @State private var token: String?
    @State private var errorMessage: String?
    @State private var copied = false

    var feedURL: URL? {
        guard let token else { return nil }
        return env.apiClient.icalFeedURL(token: token)
    }

    var body: some View {
        Form {
            Section("iCal feed") {
                if let feedURL {
                    HStack {
                        Text(feedURL.absoluteString)
                            .font(.system(.caption, design: .monospaced))
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                        Button(copied ? "Copied" : "Copy") {
                            UIPasteboard.general.string = feedURL.absoluteString
                            copied = true
                            Task { try? await Task.sleep(nanoseconds: 1_500_000_000); copied = false }
                        }
                        .buttonStyle(.bordered)
                    }
                } else {
                    ProgressView()
                }
            }
            Section("Add to your calendar app") {
                Text("Open the link in Apple Calendar, or paste it into the Subscribe by URL field in Google Calendar / Outlook.")
                    .font(.caption)
            }
            Section {
                Button("Regenerate token", role: .destructive) {
                    Task { await regenerate() }
                }
            }
            if let errorMessage { Text(errorMessage).foregroundStyle(.red) }
        }
        .navigationTitle("Calendar sync")
        .task { await load() }
    }

    private func load() async {
        do {
            let response = try await env.apiClient.icalToken()
            token = response.token
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func regenerate() async {
        do {
            let response = try await env.apiClient.icalRevoke()
            token = response.token
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Privacy

struct SettingsPrivacySection: View {
    @Environment(AppEnvironment.self) private var env
    @State private var visibility: String = "public"
    @State private var blocks: [BlockEntry] = []
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section("Profile visibility") {
                Picker("Who can see my profile", selection: $visibility) {
                    Text("Public").tag("public")
                    Text("Friends only").tag("friends_only")
                    Text("Private").tag("private")
                }
                .onChange(of: visibility) { _, _ in Task { await saveVisibility() } }
            }
            Section("Blocked users") {
                if blocks.isEmpty {
                    Text("No one is blocked.").foregroundStyle(.secondary).font(.caption)
                } else {
                    ForEach(blocks) { block in
                        HStack {
                            AvatarView(username: block.username, size: 32)
                            Text(block.username ?? block.userId)
                            Spacer()
                            Button("Unblock") {
                                Task { await unblock(block) }
                            }
                        }
                    }
                }
            }
            if let errorMessage { Text(errorMessage).foregroundStyle(.red) }
        }
        .navigationTitle("Privacy")
        .task { await load() }
    }

    private func load() async {
        do {
            let prefs = try await env.apiClient.notificationPreferences()
            visibility = prefs.profileVisibility ?? "public"
            blocks = try await env.apiClient.moderationBlocks()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func saveVisibility() async {
        do {
            try await env.apiClient.updateNotificationPreferences(profileVisibility: visibility)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func unblock(_ block: BlockEntry) async {
        do {
            try await env.apiClient.moderationUnblock(userID: block.userId)
            blocks.removeAll { $0.userId == block.userId }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Export

struct SettingsExportSection: View {
    @Environment(AppEnvironment.self) private var env
    @State private var isExporting = false
    @State private var errorMessage: String?
    @State private var exportURL: URL?

    var body: some View {
        Form {
            Section("Export") {
                Text("Download a ZIP archive of your watchlist, watched, reviews, rewatches, shelves, and profile.")
                    .font(.subheadline)
                Button(isExporting ? "Preparing…" : "Download ZIP") {
                    Task { await runExport() }
                }
                .disabled(isExporting)
                if let exportURL {
                    ShareLink(item: exportURL) {
                        Label("Share ZIP", systemImage: "square.and.arrow.up")
                    }
                }
            }
            if let errorMessage { Text(errorMessage).foregroundStyle(.red) }
        }
        .navigationTitle("Export")
    }

    private func runExport() async {
        isExporting = true; defer { isExporting = false }
        errorMessage = nil
        do {
            let data = try await env.apiClient.exportZip()
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("releaseradar-export-\(Int(Date().timeIntervalSince1970)).zip")
            try data.write(to: url)
            exportURL = url
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Delete account

struct SettingsDeleteAccountSection: View {
    @Environment(AppEnvironment.self) private var env
    @State private var confirming = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section("This will permanently delete your account and all data.") {
                Button("Delete my account", role: .destructive) {
                    confirming = true
                }
            }
            if let errorMessage { Text(errorMessage).foregroundStyle(.red) }
        }
        .navigationTitle("Delete account")
        .alert("Are you sure?", isPresented: $confirming) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task { await runDelete() }
            }
        } message: {
            Text("This cannot be undone.")
        }
    }

    private func runDelete() async {
        do {
            _ = try await env.apiClient.userDeleteAccount()
            try? env.signOut()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
