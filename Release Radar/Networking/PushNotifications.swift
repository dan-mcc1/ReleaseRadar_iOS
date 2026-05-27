import Foundation
import UserNotifications
import FirebaseCore
import FirebaseMessaging
#if canImport(UIKit)
import UIKit
#endif

/// Foundation for in-app push notifications.
///
/// Architecture:
/// - `PushNotificationsAppDelegate` (below) handles the UIKit / UNUserNotification /
///   Firebase Messaging delegate plumbing. It's installed via
///   `@UIApplicationDelegateAdaptor` in `Release_RadarApp`.
/// - `PushNotificationManager.shared` is a thin wrapper for things the rest of the
///   app reaches for: requesting permission, scheduling local reminders, and
///   reading the latest FCM token.
@MainActor
final class PushNotificationManager: NSObject {
    static let shared = PushNotificationManager()

    private(set) var permissionGranted: Bool = false

    /// Most recent FCM registration token, populated by the
    /// `MessagingDelegate` callback in the AppDelegate.
    var fcmToken: String? { PushNotificationsAppDelegate.shared?.fcmToken }

    /// Raw APNs device token (hex), for diagnostics. FCM is the primary
    /// identifier — this is just here for completeness.
    var apnsTokenHex: String? { PushNotificationsAppDelegate.shared?.apnsTokenHex }

    /// Ask the user for notification permission. Idempotent.
    func requestAuthorization() async {
        let center = UNUserNotificationCenter.current()
        do {
            permissionGranted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            if permissionGranted {
                registerForRemoteNotifications()
            }
        } catch {
            permissionGranted = false
        }
    }

    func registerForRemoteNotifications() {
        #if canImport(UIKit)
        UIApplication.shared.registerForRemoteNotifications()
        #endif
    }

    /// Schedule a local notification reminder (no backend needed).
    func scheduleLocalRelease(id: String, title: String, body: String, at date: Date) async throws {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date),
            repeats: false
        )
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        try await UNUserNotificationCenter.current().add(request)
    }

    /// Cancel a previously-scheduled local notification.
    func cancelLocalRelease(id: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
    }
}

// MARK: - App delegate
//
// Owns the three delegate roles needed for end-to-end FCM push:
// - `UIApplicationDelegate` — to receive the APNs token from iOS and forward
//   it to Firebase Messaging.
// - `MessagingDelegate` — to capture the FCM registration token as it rotates.
// - `UNUserNotificationCenterDelegate` — to show banners while the app is
//   foregrounded and react to silent badge-refresh pushes.
//
// The class also posts a `Notification.Name.fcmTokenDidUpdate` on the default
// notification center whenever a fresh FCM token lands — `AppEnvironment`
// listens for that and uploads the token to the backend.

extension Notification.Name {
    /// Posted with `object: PushNotificationsAppDelegate` whenever a new FCM
    /// token is captured. The token can be read from `userInfo["token"]`.
    static let fcmTokenDidUpdate = Notification.Name("co.releaseradar.fcmTokenDidUpdate")

    /// Posted when a silent push arrives (e.g. badge sync). Listeners
    /// should re-fetch unread counts.
    static let pushDidRequestRefresh = Notification.Name("co.releaseradar.pushDidRequestRefresh")
}

final class PushNotificationsAppDelegate: NSObject, UIApplicationDelegate {
    /// Strong reference so the AppDelegate stays alive for the rest of the
    /// app to reach the live token via `PushNotificationManager.shared`.
    static var shared: PushNotificationsAppDelegate?

    private(set) var fcmToken: String?
    private(set) var apnsTokenHex: String?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        Self.shared = self
        // Firebase is normally configured in `Release_RadarApp.init()`. Re-
        // entrant calls are no-ops, so this is here as a safety net in case
        // the init order ever shifts.
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().delegate = self
        // Actively pull the current FCM token. The delegate also catches
        // future rotations, but if Firebase already had a cached token
        // (warm launch), this is the only way to surface it.
        Messaging.messaging().token { [weak self] token, error in
            guard error == nil, let token, !token.isEmpty else { return }
            Task { @MainActor in
                self?.fcmToken = token
                NotificationCenter.default.post(
                    name: .fcmTokenDidUpdate,
                    object: self,
                    userInfo: ["token": token]
                )
            }
        }
        return true
    }

    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        apnsTokenHex = deviceToken.map { String(format: "%02x", $0) }.joined()
        // Hand the raw APNs token to Firebase Messaging — FCM uses it as the
        // backing transport when sending us pushes.
        Messaging.messaging().apnsToken = deviceToken
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        apnsTokenHex = nil
    }

    /// Silent-push entry point. Backends send `content-available: 1` pushes
    /// to nudge us to refresh in the background — we broadcast a refresh
    /// notification that `NotificationsModel` picks up.
    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable: Any]) async
        -> UIBackgroundFetchResult {
        NotificationCenter.default.post(name: .pushDidRequestRefresh, object: self, userInfo: userInfo)
        return .newData
    }
}

extension PushNotificationsAppDelegate: MessagingDelegate {
    nonisolated func messaging(_ messaging: Messaging,
                               didReceiveRegistrationToken fcmToken: String?) {
        Task { @MainActor in
            guard let token = fcmToken, !token.isEmpty else { return }
            self.fcmToken = token
            NotificationCenter.default.post(
                name: .fcmTokenDidUpdate,
                object: self,
                userInfo: ["token": token]
            )
        }
    }
}

extension PushNotificationsAppDelegate: UNUserNotificationCenterDelegate {
    /// Show banner + sound + badge even when the app is in the foreground.
    /// By default iOS suppresses the alert UI when the app is open.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async
        -> UNNotificationPresentationOptions {
        NotificationCenter.default.post(name: .pushDidRequestRefresh, object: self)
        return [.banner, .sound, .badge, .list]
    }

    /// Tapping a notification. Hook for deep-linking in the future.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse) async {
        NotificationCenter.default.post(name: .pushDidRequestRefresh, object: self)
    }
}
