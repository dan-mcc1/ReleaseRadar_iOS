import SwiftUI
import UniformTypeIdentifiers

/// Unified import flow. Pick the source up top (Letterboxd or TV Time),
/// follow the source-specific export instructions, then upload the CSV or
/// ZIP. The backend exposes a separate endpoint per source — this view
/// just routes the upload to the right one.
struct ImportView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var source: Source = .letterboxd
    @State private var pickerShown = false
    @State private var phase: Phase = .idle
    @State private var pickedFile: URL?
    @State private var response: ImportResponse?
    @State private var errorMessage: String?
    @State private var filter: ResultFilter = .all

    enum Source: String, CaseIterable, Identifiable {
        case letterboxd, tvtime
        var id: String { rawValue }
        var label: String {
            switch self {
            case .letterboxd: "Letterboxd"
            case .tvtime: "TV Time"
            }
        }
        var instructions: String {
            switch self {
            case .letterboxd:
                "In Letterboxd, go to Settings → Import & Export → Export your data. Upload the resulting CSV or ZIP file here."
            case .tvtime:
                "Request your data export from TV Time → Settings → Personal Data. They email a ZIP — upload it here (or a single CSV from inside that ZIP)."
            }
        }
    }

    enum Phase { case idle, uploading, done }
    enum ResultFilter: String, CaseIterable, Identifiable {
        case all, watched, watchlisted, skipped, failed
        var id: String { rawValue }
    }

    var body: some View {
        Form {
            // Hide the source picker once the import has finished — the
            // summary + results are tied to whichever source was used.
            if phase != .done {
                Section {
                    Picker("Source", selection: $source) {
                        ForEach(Source.allCases) { s in
                            Text(s.label).tag(s)
                        }
                    }
                    .pickerStyle(.segmented)
                } footer: {
                    Text(source.instructions)
                }
            }

            if phase == .done, let response {
                Section("Summary") {
                    LabeledContent("Total", value: "\(response.summary.total)")
                    LabeledContent("Imported", value: "\(response.summary.imported)")
                    LabeledContent("Watchlisted", value: "\(response.summary.watchlisted)")
                    LabeledContent("Skipped", value: "\(response.summary.skipped)")
                    LabeledContent("Failed", value: "\(response.summary.failed)")
                }
                Section {
                    Picker("Filter", selection: $filter) {
                        ForEach(ResultFilter.allCases) { f in
                            Text(f.rawValue.capitalized).tag(f)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                Section("Results") {
                    ForEach(filteredResults(response: response)) { row in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(row.title ?? "—").font(.subheadline.weight(.semibold))
                            HStack(spacing: 6) {
                                Text(row.status.capitalized).font(.caption.weight(.medium))
                                if let rating = row.rating { Text("★ \(rating, specifier: "%.1f")").font(.caption) }
                                if let reason = row.reason { Text(reason).font(.caption).foregroundStyle(.secondary) }
                            }
                        }
                    }
                }
                Section {
                    Button("Import another file") {
                        pickedFile = nil
                        phase = .idle
                        self.response = nil
                    }
                }
            } else {
                Section("File") {
                    if let pickedFile {
                        LabeledContent("Selected", value: pickedFile.lastPathComponent)
                    }
                    Button("Pick file…") {
                        pickerShown = true
                    }
                }
                Section {
                    Button(phase == .uploading ? "Uploading…" : "Import") {
                        Task { await upload() }
                    }
                    .disabled(pickedFile == nil || phase == .uploading)
                }
                if let errorMessage { Text(errorMessage).foregroundStyle(.red) }
            }
        }
        .navigationTitle("Import data")
        .fileImporter(
            isPresented: $pickerShown,
            allowedContentTypes: [.commaSeparatedText, .zip, .data],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls): pickedFile = urls.first
            case .failure(let error): errorMessage = error.localizedDescription
            }
        }
    }

    private func filteredResults(response: ImportResponse) -> [ImportResultRow] {
        switch filter {
        case .all: response.results
        case .watched: response.results.filter { $0.status == "imported" || $0.status == "watched" }
        case .watchlisted: response.results.filter { $0.status == "watchlisted" }
        case .skipped: response.results.filter { $0.status == "skipped" }
        case .failed: response.results.filter { $0.status == "failed" }
        }
    }

    private func upload() async {
        guard let pickedFile else { return }
        phase = .uploading
        errorMessage = nil
        defer { if response == nil { phase = .idle } }
        do {
            let needsAccess = pickedFile.startAccessingSecurityScopedResource()
            defer { if needsAccess { pickedFile.stopAccessingSecurityScopedResource() } }
            response = try await {
                switch source {
                case .letterboxd: try await env.apiClient.importLetterboxdDecoded(fileURL: pickedFile)
                case .tvtime: try await env.apiClient.importTVTimeDecoded(fileURL: pickedFile)
                }
            }()
            phase = .done
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
