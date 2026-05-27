import Foundation

enum OAuthProvider: String, Sendable {
    case google
    case microsoft
    case facebook

    var displayName: String {
        switch self {
        case .google: "Google"
        case .microsoft: "Microsoft"
        case .facebook: "Facebook"
        }
    }
}

enum AuthError: LocalizedError {
    case notConfigured

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Firebase Auth is not configured yet. Add the firebase-ios-sdk Swift Package and drop GoogleService-Info.plist into the project, then replace UnauthenticatedAuthProvider with a real implementation."
        }
    }
}

/// Abstracts how the app obtains a bearer token for the backend and performs
/// auth operations. In production this is backed by Firebase Auth.
protocol AuthProvider: Sendable {
    /// Returns a fresh Firebase ID token, or nil if the user is not signed in.
    func currentIDToken() async throws -> String?

    /// Synchronous read of current auth state.
    var isSignedIn: Bool { get }

    func signIn(email: String, password: String) async throws
    func register(email: String, password: String) async throws
    func signIn(with provider: OAuthProvider) async throws
    func sendPasswordReset(to email: String) async throws
    func signOut() throws
}

/// Used until Firebase SDK is wired up. All sign-in attempts throw a clear
/// "not configured" error so the UI surfaces the integration gap.
struct UnauthenticatedAuthProvider: AuthProvider {
    func currentIDToken() async throws -> String? { nil }
    var isSignedIn: Bool { false }

    func signIn(email: String, password: String) async throws { throw AuthError.notConfigured }
    func register(email: String, password: String) async throws { throw AuthError.notConfigured }
    func signIn(with provider: OAuthProvider) async throws { throw AuthError.notConfigured }
    func sendPasswordReset(to email: String) async throws { throw AuthError.notConfigured }
    func signOut() throws { throw AuthError.notConfigured }
}
