import SwiftUI
import FirebaseCore
import GoogleSignIn
import Nuke

@main
struct Release_RadarApp: App {
    @State private var environment: AppEnvironment
    /// Installs the AppDelegate that owns the UIKit / FCM / UNUserNotification
    /// delegate roles. Has to be present for APNs token callbacks to fire.
    @UIApplicationDelegateAdaptor(PushNotificationsAppDelegate.self) private var pushDelegate

    init() {
        FirebaseApp.configure()
        Self.configureImagePipeline()
        _environment = State(initialValue: AppEnvironment(auth: FirebaseAuthProvider()))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(environment)
                .tint(.brandPrimary)
                .preferredColorScheme(.dark)
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
    }

    /// Tunes Nuke's shared image pipeline for our use:
    /// - 50 MB in-memory cache for decoded images (fast scrolling)
    /// - Disk-backed data cache so posters persist across launches
    /// - Default request deduplication is already on, so the same URL across
    ///   multiple rows is only fetched once.
    private static func configureImagePipeline() {
        let pipeline = ImagePipeline {
            $0.imageCache = ImageCache(costLimit: 50 * 1024 * 1024)
            $0.dataCache = try? DataCache(name: "co.releaseradar.images")
            $0.isProgressiveDecodingEnabled = false
        }
        ImagePipeline.shared = pipeline
    }
}
