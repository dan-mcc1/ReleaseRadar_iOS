import SwiftUI

/// Modal sheet for spinning up a brand-new community. Captures the four
/// fields the backend's `POST /communities/` requires: name, optional
/// description, visibility (public/private), and an optional banner colour.
struct CreateGroupSheet: View {
    var onCreated: (Community) -> Void

    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var description: String = ""
    @State private var visibility: String = "public"
    @State private var bannerColor: String = "#10B981"
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private let palette: [String] = [
        "#10B981", // emerald
        "#60A5FA", // blue
        "#F472B6", // pink
        "#FBBF24", // amber
        "#A78BFA", // purple
        "#F87171"  // red
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("e.g. Sunday Sci-Fi Club", text: $name)
                        .textInputAutocapitalization(.words)
                }
                Section("Description") {
                    TextField("Optional — what's this group about?", text: $description, axis: .vertical)
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
                if let errorMessage {
                    Section { Text(errorMessage).foregroundStyle(.red) }
                }
            }
            .navigationTitle("New group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Create") { Task { await submit() } }
                        .disabled(isSubmitting || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func submit() async {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        let trimmedDesc = description.trimmingCharacters(in: .whitespacesAndNewlines)
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }
        do {
            let community = try await env.apiClient.communityCreate(
                name: trimmedName,
                description: trimmedDesc.isEmpty ? nil : trimmedDesc,
                visibility: visibility,
                bannerColor: bannerColor
            )
            onCreated(community)
            dismiss()
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
