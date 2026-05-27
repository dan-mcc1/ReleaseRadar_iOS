import Foundation
import UIKit
import FirebaseAuth
import FirebaseCore
import GoogleSignIn

/// `AuthProvider` backed by Firebase Auth.
/// - Email/password: native Firebase.
/// - Google: GoogleSignIn SDK → Firebase credential.
/// - Microsoft / Facebook: Firebase's generic OAuth web flow.
final class FirebaseAuthProvider: AuthProvider {
    func currentIDToken() async throws -> String? {
        guard let user = Auth.auth().currentUser else { return nil }
        return try await user.getIDToken()
    }

    var isSignedIn: Bool {
        Auth.auth().currentUser != nil
    }

    func signIn(email: String, password: String) async throws {
        _ = try await Auth.auth().signIn(withEmail: email, password: password)
    }

    func register(email: String, password: String) async throws {
        _ = try await Auth.auth().createUser(withEmail: email, password: password)
    }

    func signIn(with provider: OAuthProvider) async throws {
        switch provider {
        case .google:
            try await signInWithGoogle()
        case .microsoft:
            try await signInWithFirebaseOAuth(providerID: "microsoft.com")
        case .facebook:
            try await signInWithFirebaseOAuth(providerID: "facebook.com")
        }
    }

    func sendPasswordReset(to email: String) async throws {
        try await Auth.auth().sendPasswordReset(withEmail: email)
    }

    func signOut() throws {
        GIDSignIn.sharedInstance.signOut()
        try Auth.auth().signOut()
    }

    // MARK: - Google

    @MainActor
    private func signInWithGoogle() async throws {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            throw AuthError.notConfigured
        }
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)

        guard let presenter = Self.topViewController() else {
            throw OAuthPresentationError()
        }

        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenter)
        guard let idToken = result.user.idToken?.tokenString else {
            throw OAuthMissingTokenError()
        }
        let accessToken = result.user.accessToken.tokenString
        let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)
        _ = try await Auth.auth().signIn(with: credential)
    }

    // MARK: - Microsoft / Facebook (web flow)

    @MainActor
    private func signInWithFirebaseOAuth(providerID: String) async throws {
        let provider = FirebaseAuth.OAuthProvider(providerID: providerID)
        _ = try await Auth.auth().signIn(with: provider, uiDelegate: nil)
    }

    // MARK: - Helpers

    @MainActor
    private static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
        let keyWindow = scene?.windows.first(where: \.isKeyWindow) ?? scene?.windows.first
        var topVC = keyWindow?.rootViewController
        while let presented = topVC?.presentedViewController {
            topVC = presented
        }
        return topVC
    }
}

private struct OAuthPresentationError: LocalizedError {
    var errorDescription: String? { "Couldn't find a window to present the sign-in flow." }
}

private struct OAuthMissingTokenError: LocalizedError {
    var errorDescription: String? { "Sign-in completed but no ID token was returned." }
}
