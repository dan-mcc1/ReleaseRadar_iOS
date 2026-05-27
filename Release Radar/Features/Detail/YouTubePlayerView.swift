import SwiftUI
import SafariServices

/// Sheet-style trailer player. Wraps `SFSafariViewController` so the video
/// runs inside in-app Safari (the real YouTube mobile page) rather than the
/// embed iframe, which gets blocked with error 152/153 in WKWebView for many
/// YouTube videos.
///
/// UX: a button labeled "Watch Trailer" that slides up a Safari sheet on tap.
/// Dismiss returns to the detail page; the user never leaves the app.
struct TrailerButton: View {
    let videoID: String
    @State private var showingSheet = false

    var body: some View {
        Button {
            showingSheet = true
        } label: {
            Label("Watch Trailer", systemImage: "play.rectangle.fill")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .sheet(isPresented: $showingSheet) {
            if let url = URL(string: "https://www.youtube.com/watch?v=\(videoID)") {
                SafariView(url: url)
                    .ignoresSafeArea()
            }
        }
    }
}

private struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = false
        let vc = SFSafariViewController(url: url, configuration: config)
        vc.preferredControlTintColor = UIColor(named: "AccentColor")
        return vc
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
