import SwiftUI

/// Top-level container injected via `.environment` for screens and view models.
/// Owns the API client, auth provider, and observable auth state.
@Observable
@MainActor
final class AppEnvironment {
    let apiClient: APIClient
    private let auth: AuthProvider

    /// True once the user has successfully authenticated. Observed by the root
    /// view to decide between sign-in and the main tab interface.
    private(set) var isSignedIn: Bool

    init(auth: AuthProvider = UnauthenticatedAuthProvider()) {
        self.auth = auth
        self.apiClient = APIClient(auth: auth)
        self.isSignedIn = auth.isSignedIn
    }

    func signIn(email: String, password: String) async throws {
        try await auth.signIn(email: email, password: password)
        isSignedIn = auth.isSignedIn
    }

    func register(email: String, password: String) async throws {
        try await auth.register(email: email, password: password)
        isSignedIn = auth.isSignedIn
    }

    func signIn(with provider: OAuthProvider) async throws {
        try await auth.signIn(with: provider)
        isSignedIn = auth.isSignedIn
    }

    func sendPasswordReset(to email: String) async throws {
        try await auth.sendPasswordReset(to: email)
    }

    func signOut() throws {
        try auth.signOut()
        isSignedIn = false
    }
}
