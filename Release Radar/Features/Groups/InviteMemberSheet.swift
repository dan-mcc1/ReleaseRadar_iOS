import SwiftUI

/// Modal that lets owners and admins invite a single user to a community
/// by username. Successful submission triggers the backend's email +
/// push notification flow.
struct InviteMemberSheet: View {
    let community: Community

    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    @State private var username: String = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var didSend = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("username", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .disabled(didSend)
                } header: {
                    Text("Invite to \(community.name)")
                } footer: {
                    Text("They'll get a push notification and an in-app invitation they can accept or decline.")
                }

                if didSend {
                    Section {
                        Label("Invitation sent", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(BrandTheme.primaryText)
                    }
                }
                if let errorMessage {
                    Section { Text(errorMessage).foregroundStyle(.red) }
                }
            }
            .navigationTitle("Invite member")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Send") { Task { await submit() } }
                        .disabled(isSubmitting || didSend || username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func submit() async {
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }
        do {
            _ = try await env.apiClient.communityInvite(id: community.id, username: trimmed)
            didSend = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
