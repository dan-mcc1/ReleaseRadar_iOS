import SwiftUI

struct FeedbackView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var category = "bug"
    @State private var subject = ""
    @State private var description = ""
    @State private var submitting = false
    @State private var submitted = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            if submitted {
                Section {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green).font(.title)
                        VStack(alignment: .leading) {
                            Text("Thanks for the feedback").font(.headline)
                            Text("We'll read it as soon as we can.").font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                }
                Section {
                    Button("Send another") {
                        subject = ""; description = ""; submitted = false
                    }
                }
            } else {
                Section("Category") {
                    Picker("Category", selection: $category) {
                        Text("Bug").tag("bug")
                        Text("Feature").tag("feature")
                        Text("General").tag("general")
                    }
                    .pickerStyle(.segmented)
                }
                Section("Subject") {
                    TextField("Short summary", text: $subject)
                }
                Section("Details") {
                    TextField("What happened? What did you expect?", text: $description, axis: .vertical)
                        .lineLimit(5...12)
                }
                Section {
                    Button(submitting ? "Sending…" : "Send feedback") {
                        Task { await send() }
                    }
                    .disabled(subject.isEmpty || description.isEmpty || submitting)
                }
                if let errorMessage { Text(errorMessage).foregroundStyle(.red) }
            }
        }
        .navigationTitle("Feedback")
    }

    private func send() async {
        submitting = true; defer { submitting = false }
        do {
            _ = try await env.apiClient.feedbackSubmit(category: category, subject: subject, description: description)
            submitted = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
