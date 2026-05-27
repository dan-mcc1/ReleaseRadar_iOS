import SwiftUI

/// Settings panel on the group detail page. Owners and admins can edit
/// the name, description, banner color, visibility, and member-edit
/// permission. Owners additionally get a delete-group action.
struct GroupSettingsView: View {
    let community: Community
    /// Called after a successful edit so the parent detail view can
    /// re-render its header with the new values.
    var onUpdated: (Community) -> Void
    /// Called after a successful delete so the parent can pop the stack.
    var onDeleted: () -> Void

    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var description: String
    @State private var visibility: String
    @State private var bannerColor: String
    @State private var membersCanEditMedia: Bool
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var showDeleteConfirm = false

    private let palette: [String] = [
        "#10B981", "#60A5FA", "#F472B6", "#FBBF24", "#A78BFA", "#F87171"
    ]

    init(
        community: Community,
        onUpdated: @escaping (Community) -> Void,
        onDeleted: @escaping () -> Void
    ) {
        self.community = community
        self.onUpdated = onUpdated
        self.onDeleted = onDeleted
        _name = State(initialValue: community.name)
        _description = State(initialValue: community.description ?? "")
        _visibility = State(initialValue: community.visibility)
        _bannerColor = State(initialValue: community.bannerColor ?? "#10B981")
        _membersCanEditMedia = State(initialValue: community.membersCanEditMedia)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Form {
                Section("Name") {
                    TextField("Group name", text: $name)
                        .textInputAutocapitalization(.words)
                }
                Section("Description") {
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }
                Section("Visibility") {
                    Picker("Visibility", selection: $visibility) {
                        Text("Public").tag("public")
                        Text("Private").tag("private")
                    }
                    .pickerStyle(.segmented)
                }
                Section("Banner colour") {
                    HStack(spacing: 10) {
                        ForEach(palette, id: \.self) { hex in
                            Button { bannerColor = hex } label: {
                                Circle()
                                    .fill(Color(hexString: hex) ?? .gray)
                                    .frame(width: 28, height: 28)
                                    .overlay(
                                        Circle()
                                            .stroke(.white, lineWidth: bannerColor == hex ? 3 : 0)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                Section {
                    Toggle("Members can add titles", isOn: $membersCanEditMedia)
                } footer: {
                    Text("When off, only owners and admins can add or remove movies and shows.")
                }
                Section {
                    Button {
                        Task { await save() }
                    } label: {
                        if isSubmitting {
                            ProgressView()
                        } else {
                            Text("Save changes").frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(isSubmitting || !hasChanges)
                }
                if community.viewerRole == "owner" {
                    Section {
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            Text("Delete group").frame(maxWidth: .infinity)
                        }
                    } footer: {
                        Text("This permanently removes the group and all posts, replies, and shared titles.")
                    }
                }
                if let errorMessage {
                    Section { Text(errorMessage).foregroundStyle(.red) }
                }
            }
            .scrollContentBackground(.hidden)
        }
        .alert("Delete this group?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { Task { await delete() } }
        } message: {
            Text("This can't be undone.")
        }
    }

    private var hasChanges: Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDesc = description.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedName != community.name
            || trimmedDesc != (community.description ?? "")
            || visibility != community.visibility
            || bannerColor != (community.bannerColor ?? "#10B981")
            || membersCanEditMedia != community.membersCanEditMedia
    }

    private func save() async {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDesc = description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            errorMessage = "Name can't be empty."
            return
        }
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }
        do {
            let updated = try await env.apiClient.communityUpdate(
                id: community.id,
                name: trimmedName,
                description: trimmedDesc.isEmpty ? nil : trimmedDesc,
                visibility: visibility,
                bannerColor: bannerColor,
                membersCanEditMedia: membersCanEditMedia
            )
            onUpdated(updated)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func delete() async {
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }
        do {
            _ = try await env.apiClient.communityDelete(id: community.id)
            onDeleted()
        } catch {
            errorMessage = error.localizedDescription
        }
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
