import SwiftUI
import UserNotifications

/// Root view. While the user is signed out we always start on the
/// editorial landing screen — tapping either CTA flips a transient
/// in-memory flag and pushes the sign-in form. On sign-out, the flag
/// resets so the next launch (or sign-in attempt) comes back to the
/// landing page.
struct ContentView: View {
    @Environment(AppEnvironment.self) private var env
    /// Transient state — only true between "user tapped a landing CTA"
    /// and "user signs in or backs out". Sign-out resets this to false
    /// (see `.onChange` below), so subsequent signed-out states
    /// always start on the landing page again.
    @State private var showSignIn = false

    var body: some View {
        Group {
            if env.isSignedIn {
                MainTabView()
            } else if showSignIn {
                SignInView()
            } else {
                LandingView { showSignIn = true }
            }
        }
        .dismissKeyboardOnOutsideTap()
        .onChange(of: env.isSignedIn) { _, newValue in
            // Sign-out: clear the SignInView passthrough so the next
            // signed-out state lands on the landing page again.
            if !newValue { showSignIn = false }
        }
    }
}

/// Cross-tab coordinator. Lets one tab tell another to become active and
/// optionally pass a small "intent" (e.g. open Library scrolled to the
/// Watched segment). Lives in the environment as an `@Observable`, so any
/// child view can grab it and mutate.
@Observable
@MainActor
final class TabNavigationCoordinator {
    enum Tab: Hashable {
        case calendar, discover, library, social, profile
    }

    var selectedTab: Tab = .calendar
    /// When non-nil, the Library tab snaps to this segment on its next
    /// appearance and then clears the value.
    var pendingLibrarySegment: LibraryViewModel.Segment?

    func openLibrary(segment: LibraryViewModel.Segment) {
        pendingLibrarySegment = segment
        selectedTab = .library
    }
}

private struct MainTabView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.scenePhase) private var scenePhase
    @State private var notifications = NotificationsModel()
    @State private var coordinator = TabNavigationCoordinator()

    var body: some View {
        @Bindable var coordinator = coordinator
        TabView(selection: $coordinator.selectedTab) {
            CalendarView()
                .tag(TabNavigationCoordinator.Tab.calendar)
                .tabItem { Label("Calendar", systemImage: "calendar") }
            DiscoverView()
                .tag(TabNavigationCoordinator.Tab.discover)
                .tabItem { Label("Discover", systemImage: "sparkles") }
            LibraryView()
                .tag(TabNavigationCoordinator.Tab.library)
                .tabItem { Label("Library", systemImage: "books.vertical") }
            SocialTabView()
                .tag(TabNavigationCoordinator.Tab.social)
                .tabItem { Label("Social", systemImage: "person.2") }
            ProfileView()
                .tag(TabNavigationCoordinator.Tab.profile)
                .tabItem { Label("Profile", systemImage: "person.crop.circle") }
                .badge(notifications.total)
        }
        .environment(notifications)
        .environment(coordinator)
        .task {
            // Permission first — `setBadgeCount` silently no-ops when the
            // `.badge` authorization is missing.
            await PushNotificationManager.shared.requestAuthorization()
            await notifications.refresh(client: env.apiClient)
            // If FirebaseMessaging already had a cached token by the time we
            // got here (warm launch), upload it immediately so the backend
            // can start targeting this device.
            if let token = PushNotificationManager.shared.fcmToken {
                await uploadDeviceToken(token)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await notifications.refresh(client: env.apiClient) }
            }
        }
        // Re-upload whenever Firebase rotates the FCM token.
        .onReceive(NotificationCenter.default.publisher(for: .fcmTokenDidUpdate)) { notif in
            guard let token = notif.userInfo?["token"] as? String else { return }
            Task { await uploadDeviceToken(token) }
        }
        // Silent push (or foreground banner) → re-fetch unread counts so the
        // in-app tab badge tracks the home-screen icon badge.
        .onReceive(NotificationCenter.default.publisher(for: .pushDidRequestRefresh)) { _ in
            Task { await notifications.refresh(client: env.apiClient) }
        }
    }

    /// Upload the FCM token to the backend so it can target this device.
    /// Safe to call repeatedly — backend upserts by token. We use the
    /// response's `badge` to sync the in-app + icon badge in one shot,
    /// avoiding a follow-up `/notifications/badge` call.
    private func uploadDeviceToken(_ token: String) async {
        let info = Bundle.main.infoDictionary
        let appVersion = info?["CFBundleShortVersionString"] as? String
        do {
            let response = try await env.apiClient.registerDevice(
                token: token,
                platform: "ios",
                appVersion: appVersion
            )
            notifications.apply(badge: response.badge)
        } catch {
            // Backend will retry on next launch / token rotation.
        }
    }
}

/// Cross-tab notification badge state. The backend's `/notifications/badge`
/// endpoint is the single source of truth — it already aggregates
/// everything the user hasn't dealt with (recommendations, friend
/// requests, season premieres, etc.) into one unread count.
@Observable
@MainActor
final class NotificationsModel {
    /// Server-authoritative unread count. Drives both the Social tab badge
    /// and the home-screen icon badge.
    var total: Int = 0

    func refresh(client: APIClient) async {
        do {
            let response = try await client.notificationsBadge()
            total = response.badge
        } catch {
            // Stale total is better than wiping it — try again on next refresh.
        }
        await syncAppIconBadge()
    }

    /// Update the badge from a value the server hands us directly (e.g.
    /// the response to `/devices/register` or `/inbox/read`) — skips the
    /// extra round trip.
    func apply(badge: Int) {
        total = badge
        Task { await syncAppIconBadge() }
    }

    /// Push the aggregate count to the home-screen icon badge. Needs
    /// notification permission (already requested in `MainTabView.task`)
    /// to actually display.
    private func syncAppIconBadge() async {
        try? await UNUserNotificationCenter.current().setBadgeCount(total)
    }
}

/// Wrapper tab for the Social hub (Activity feed, Friends, and Groups
/// entry points).
private struct SocialTabView: View {
    @State private var segment: Segment = .activity

    enum Segment: String, CaseIterable, Identifiable {
        case activity, friends, groups
        var id: String { rawValue }
        var title: String { rawValue.capitalized }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                LargeTitleHeader(
                    eyebrow: "Your circle",
                    title: "Social",
                    accent: nil
                ) { EmptyView() }

                HStack(spacing: 8) {
                    ForEach(Segment.allCases) { s in
                        FilterChip(
                            label: s.title,
                            count: nil,
                            isActive: segment == s,
                            action: { segment = s }
                        )
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 14)

                Group {
                    switch segment {
                    case .activity: ActivityFeedView()
                    case .friends: FriendsView()
                    case .groups: MyGroupsView()
                    }
                }
            }
            .pageBackground()
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

#Preview("Signed Out") {
    ContentView()
        .environment(AppEnvironment())
        .tint(.brandPrimary)
        .preferredColorScheme(.dark)
}
