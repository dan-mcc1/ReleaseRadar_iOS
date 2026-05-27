import SwiftUI

/// Matches the web app's SignIn page: logo, app name, mode tabs (Sign In / Register),
/// email + password fields, primary action, forgot password, OAuth row.
/// The form is fully interactive but submission goes through `AppEnvironment`,
/// which surfaces an "Auth not configured" error until Firebase is wired up.
struct SignInView: View {
    @Environment(AppEnvironment.self) private var env

    enum Mode { case signIn, register }

    @State private var mode: Mode = .signIn
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var isWorking = false
    @State private var errorMessage: String?
    @State private var infoMessage: String?

    var body: some View {
        ZStack {
            Color.brandBackground.ignoresSafeArea()
            RadarSweepBackground()
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    header
                    card
                    Spacer(minLength: 24)
                }
                .padding(.horizontal, 20)
                .padding(.top, 48)
                .frame(maxWidth: 480)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var header: some View {
        VStack(spacing: 16) {
            BrandLogoView(size: 80)
            Text("Release Radar")
                .font(.largeTitle.bold())
                .foregroundStyle(.white)
            Text(mode == .signIn
                 ? "Welcome back — sign in to continue"
                 : "Create your account to get started")
                .font(.subheadline)
                .foregroundStyle(Color.brandTextSecondary)
        }
    }

    private var card: some View {
        VStack(spacing: 16) {
            modeTabs
            emailField
            passwordField

            if let infoMessage {
                Text(infoMessage)
                    .font(.footnote)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(Color.brandPrimary.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                    .foregroundStyle(Color.brandPrimary)
            }
            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(Color.red.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                    .foregroundStyle(.red)
            }

            submitButton

            if mode == .signIn {
                Button("Forgot password?", action: sendPasswordReset)
                    .font(.footnote)
                    .foregroundStyle(Color.brandTextSecondary)
            }

            divider
            oauthButtons
        }
        .padding(20)
        .background(Color.brandSurface, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.brandBorder, lineWidth: 1)
        )
    }

    private var modeTabs: some View {
        HStack(spacing: 8) {
            tabButton(title: "Sign In", isSelected: mode == .signIn) { mode = .signIn }
            tabButton(title: "Register", isSelected: mode == .register) { mode = .register }
        }
        .padding(4)
        .background(Color.brandSurfaceElevated, in: RoundedRectangle(cornerRadius: 10))
    }

    private func tabButton(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .foregroundStyle(isSelected ? .white : Color.brandTextSecondary)
                .background(isSelected ? Color.brandPrimary : Color.clear,
                            in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private var emailField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Email")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.brandTextSecondary)
            TextField("you@example.com", text: $email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(12)
                .background(Color.brandSurfaceElevated, in: RoundedRectangle(cornerRadius: 8))
                .foregroundStyle(.white)
        }
    }

    private var passwordField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Password")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.brandTextSecondary)
            SecureField(mode == .signIn ? "Your password" : "Create a password", text: $password)
                .textContentType(mode == .signIn ? .password : .newPassword)
                .padding(12)
                .background(Color.brandSurfaceElevated, in: RoundedRectangle(cornerRadius: 8))
                .foregroundStyle(.white)
        }
    }

    private var submitButton: some View {
        Button(action: submit) {
            HStack {
                if isWorking { ProgressView().tint(.white) }
                Text(submitLabel)
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.brandPrimary, in: RoundedRectangle(cornerRadius: 8))
            .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
        .disabled(isWorking || email.isEmpty || password.isEmpty)
        .opacity((isWorking || email.isEmpty || password.isEmpty) ? 0.5 : 1)
    }

    private var submitLabel: String {
        switch (mode, isWorking) {
        case (.signIn, true): "Signing in…"
        case (.signIn, false): "Sign In"
        case (.register, true): "Creating account…"
        case (.register, false): "Create Account"
        }
    }

    private var divider: some View {
        HStack {
            Rectangle().fill(Color.brandBorder).frame(height: 1)
            Text("or")
                .font(.caption)
                .foregroundStyle(Color.brandTextSecondary)
                .padding(.horizontal, 8)
            Rectangle().fill(Color.brandBorder).frame(height: 1)
        }
    }

    private var oauthButtons: some View {
        VStack(spacing: 10) {
            oauthButton(provider: .google, systemImage: "g.circle.fill")
            oauthButton(provider: .microsoft, systemImage: "square.grid.2x2.fill")
            oauthButton(provider: .facebook, systemImage: "f.circle.fill")
        }
    }

    private func oauthButton(provider: OAuthProvider, systemImage: String) -> some View {
        Button {
            Task { await runAuth { try await env.signIn(with: provider) } }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                Text("Continue with \(provider.displayName)")
                    .font(.subheadline.weight(.medium))
                Spacer()
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(Color.brandSurfaceElevated, in: RoundedRectangle(cornerRadius: 8))
            .foregroundStyle(.white)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.brandBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(isWorking)
    }

    // MARK: - Actions

    private func submit() {
        Task {
            await runAuth {
                switch mode {
                case .signIn: try await env.signIn(email: email, password: password)
                case .register: try await env.register(email: email, password: password)
                }
            }
        }
    }

    private func sendPasswordReset() {
        guard !email.isEmpty else {
            errorMessage = "Enter your email above first, then tap Forgot password."
            return
        }
        Task {
            await runAuth {
                try await env.sendPasswordReset(to: email)
                infoMessage = "If an account exists for \(email), a reset link is on its way."
            }
        }
    }

    @MainActor
    private func runAuth(_ operation: @MainActor () async throws -> Void) async {
        isWorking = true
        errorMessage = nil
        infoMessage = nil
        defer { isWorking = false }
        do {
            try await operation()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    SignInView()
        .environment(AppEnvironment())
        .tint(.brandPrimary)
        .preferredColorScheme(.dark)
}
