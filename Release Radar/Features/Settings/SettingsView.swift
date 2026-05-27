import SwiftUI

struct SettingsView: View {
    @Environment(AppEnvironment.self) private var env

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                LargeTitleHeader(
                    eyebrow: "Preferences",
                    title: "Settings",
                    accent: nil
                ) { EmptyView() }

                accountGroup
                discoveryGroup
                dataGroup

                signOutCard
                deleteAccountLink
                versionLabel
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .pageBackground()
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Groups

    private var accountGroup: some View {
        settingsGroup(label: "Account") {
            settingsRow(title: "Profile", icon: "person.crop.circle", subtitle: "Username, avatar") {
                SettingsProfileSection()
            }
            rowDivider
            settingsRow(title: "Privacy", icon: "lock", subtitle: "Visibility, blocks") {
                SettingsPrivacySection()
            }
        }
    }

    private var discoveryGroup: some View {
        settingsGroup(label: "Discovery") {
            settingsRow(title: "Notifications", icon: "bell", subtitle: "Push and email") {
                SettingsNotificationsSection()
            }
            rowDivider
            settingsRow(title: "Streaming", icon: "tv", subtitle: "Pick your services") {
                SettingsStreamingSection()
            }
            rowDivider
            settingsRow(title: "Calendar sync", icon: "calendar.badge.clock", subtitle: "ICS feed") {
                SettingsCalendarSyncSection()
            }
        }
    }

    private var dataGroup: some View {
        settingsGroup(label: "Data") {
            settingsRow(title: "Import", icon: "square.and.arrow.down", subtitle: "Letterboxd, IMDb, Trakt") {
                ImportView()
            }
            rowDivider
            settingsRow(title: "Export your data", icon: "square.and.arrow.up", subtitle: "Download CSV") {
                SettingsExportSection()
            }
            rowDivider
            settingsRow(title: "Send feedback", icon: "envelope", subtitle: "Bugs and requests") {
                FeedbackView()
            }
        }
    }

    // MARK: - Building blocks

    /// 1pt hairline that sits between rows inside a settings group. Indented
    /// to start past the glyph square so it visually anchors to the text
    /// column — same trick UIKit's UITableView uses by default.
    private var rowDivider: some View {
        Rectangle()
            .fill(BrandTheme.border)
            .frame(height: 1)
            .padding(.leading, 62)
    }

    /// Editorial section: mono uppercase eyebrow + a rounded surface card
    /// hosting the rows.
    private func settingsGroup<Content: View>(
        label: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label.uppercased())
                .font(BrandFont.mono(10, weight: .medium))
                .tracking(1.4)
                .foregroundStyle(BrandTheme.textDim)
                .padding(.leading, 4)
            VStack(spacing: 0) {
                content()
            }
            .background(BrandTheme.surface, in: RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(BrandTheme.border, lineWidth: 1)
            )
        }
    }

    /// 34pt emerald-soft glyph square + title (optional subtitle) + chevron.
    /// Pushes onto the navigation stack with the provided destination.
    private func settingsRow<Destination: View>(
        title: String,
        icon: String,
        subtitle: String? = nil,
        @ViewBuilder destination: @escaping () -> Destination
    ) -> some View {
        NavigationLink {
            destination()
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(BrandTheme.primarySoft)
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(BrandTheme.primaryText)
                }
                .frame(width: 34, height: 34)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(BrandFont.sans(14.5, weight: .medium))
                        .foregroundStyle(BrandTheme.text)
                    if let subtitle {
                        Text(subtitle)
                            .font(BrandFont.sans(12))
                            .foregroundStyle(BrandTheme.textMuted)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(BrandTheme.textDim)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Footer actions

    /// Centered destructive sign-out card. Mirrors the row chrome but
    /// trades the chevron for a centered label and an emerald-free
    /// destructive color so it reads as terminal.
    private var signOutCard: some View {
        Button {
            try? env.signOut()
        } label: {
            Text("Sign out")
                .font(BrandFont.sans(14.5, weight: .medium))
                .foregroundStyle(Color(hex: 0xF43F5E))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(BrandTheme.surface, in: RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(BrandTheme.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    /// Small, unobtrusive Delete-account link below sign-out — kept
    /// reachable but de-emphasized since it's an irreversible action.
    private var deleteAccountLink: some View {
        NavigationLink {
            SettingsDeleteAccountSection()
        } label: {
            Text("Delete account")
                .font(BrandFont.sans(12, weight: .medium))
                .foregroundStyle(BrandTheme.textDim)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }

    /// `RELEASE RADAR · V1.2 (45)` mono caption pulled from the bundle's
    /// CFBundle{ShortVersionString,Version}.
    private var versionLabel: some View {
        let info = Bundle.main.infoDictionary
        let version = (info?["CFBundleShortVersionString"] as? String) ?? "—"
        let build = (info?["CFBundleVersion"] as? String) ?? "—"
        return Text("RELEASE RADAR · V\(version) (\(build))")
            .font(BrandFont.mono(10, weight: .medium))
            .tracking(1.4)
            .foregroundStyle(BrandTheme.textDim)
            .frame(maxWidth: .infinity)
            .padding(.top, 6)
    }
}
