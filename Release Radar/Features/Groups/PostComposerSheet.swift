import SwiftUI

/// Modal used to create a new top-level post in a community. Title is
/// optional (a body-only post still works); on submit we hand the created
/// post back to the parent so it can prepend without a refetch.
struct PostComposerSheet: View {
    let community: Community
    var onPosted: (CommunityPost) -> Void

    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    @State private var title: String = ""
    @State private var bodyText: String = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Title (optional)") {
                    TextField("Add a headline", text: $title)
                }
                Section("Post") {
                    TextField("What's on your mind?", text: $bodyText, axis: .vertical)
                        .lineLimit(5...12)
                }
                if let errorMessage {
                    Section { Text(errorMessage).foregroundStyle(.red) }
                }
            }
            .navigationTitle("New post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Post") { Task { await submit() } }
                        .disabled(isSubmitting || bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func submit() async {
        let trimmedBody = bodyText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedBody.isEmpty else { return }
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }
        do {
            let post = try await env.apiClient.communityCreatePost(
                id: community.id,
                title: trimmedTitle.isEmpty ? nil : trimmedTitle,
                body: trimmedBody
            )
            onPosted(post)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
