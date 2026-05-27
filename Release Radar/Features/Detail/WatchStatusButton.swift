import SwiftUI

/// Prominent action button on a movie/show detail page. Loads the user's
/// current watch status on appear and lets them switch between "not tracked",
/// "want to watch", "currently watching", and "watched" via a menu. Optimistic
/// state with rollback on failure.
struct WatchStatusButton: View {
    let item: MediaItem
    @Environment(AppEnvironment.self) private var env
    @State private var status: WatchStatus = .none
    @State private var isLoaded = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Group {
                if status == .none {
                    // Split CTA: tap left side → straight to Watchlist;
                    // tap chevron → menu with all status options.
                    splitButton
                } else {
                    fullMenuButton
                }
            }
            .disabled(isSaving || !isLoaded)
            .opacity((isSaving || !isLoaded) ? 0.6 : 1)

            if let errorMessage {
                Text(errorMessage)
                    .font(BrandFont.sans(12))
                    .foregroundStyle(.red)
            }
        }
        .padding(.horizontal, 16)
        // Re-fire load whenever the item identity changes (defensive — also
        // fires once on first appearance). Without the id, navigating between
        // detail pages of the same `MediaItem` type could re-use the view
        // without re-fetching.
        .task(id: "\(item.contentType.rawValue)-\(item.id)") {
            await load()
        }
    }

    // MARK: - Split button (empty state)

    /// Two tap targets sharing one emerald pill: the wide left side adds
    /// directly to Watchlist; the narrow right chevron opens the full
    /// status picker so users can jump straight to Watching / Watched.
    private var splitButton: some View {
        HStack(spacing: 0) {
            Button {
                Task { await setStatus(.wantToWatch) }
            } label: {
                HStack(spacing: 10) {
                    statusIcon
                    VStack(alignment: .leading, spacing: 1) {
                        Text(eyebrowText.uppercased())
                            .font(BrandFont.mono(9.5, weight: .semibold))
                            .tracking(1.3)
                            .opacity(0.85)
                        Text(primaryText)
                            .font(BrandFont.sans(15, weight: .semibold))
                    }
                    Spacer(minLength: 0)
                }
                .foregroundStyle(foreground)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Rectangle()
                .fill(Color.black.opacity(0.18))
                .frame(width: 1)
                .padding(.vertical, 8)

            Menu {
                ForEach(menuOptions, id: \.self) { option in
                    Button {
                        Task { await setStatus(option) }
                    } label: {
                        Label(option.buttonLabel, systemImage: option.icon)
                    }
                }
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(foreground)
                    .frame(width: 48, height: 48)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Choose status")
        }
        .background(background, in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Single menu button (tracked state)

    /// When the item is already tracked, the whole pill is one Menu — the
    /// user is more likely to want to change/remove status than to repeat
    /// an action, so a split button adds friction.
    private var fullMenuButton: some View {
        Menu {
            ForEach(menuOptions, id: \.self) { option in
                Button {
                    Task { await setStatus(option) }
                } label: {
                    Label(option.buttonLabel, systemImage: option.icon)
                }
            }
            Divider()
            Button(role: .destructive) {
                Task { await setStatus(.none) }
            } label: {
                Label("Remove from library", systemImage: "minus.circle")
            }
        } label: {
            HStack(spacing: 10) {
                statusIcon
                VStack(alignment: .leading, spacing: 1) {
                    Text(eyebrowText.uppercased())
                        .font(BrandFont.mono(9.5, weight: .semibold))
                        .tracking(1.3)
                    Text(primaryText)
                        .font(BrandFont.sans(15, weight: .semibold))
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .bold))
                    .opacity(0.7)
            }
            .foregroundStyle(foreground)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(background, in: RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(borderColor, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var statusIcon: some View {
        Image(systemName: status.icon)
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(iconForeground)
            .frame(width: 32, height: 32)
            .background(iconBackground, in: Circle())
    }

    /// Top eyebrow line — "Status" when tracked, "Track this" when empty.
    private var eyebrowText: String {
        if !isLoaded { return "Loading" }
        if isSaving { return "Updating" }
        return status == .none ? "Track this" : "Status"
    }

    /// Main label — primary action for empty state, current status for
    /// tracked state.
    private var primaryText: String {
        if !isLoaded { return "Loading…" }
        if isSaving { return "Updating…" }
        return status == .none ? "Add to library" : status.buttonLabel
    }

    private var menuOptions: [WatchStatus] {
        [.wantToWatch, .currentlyWatching, .watched]
    }

    private var background: Color {
        status == .none ? BrandTheme.primary : BrandTheme.surface
    }

    private var borderColor: Color {
        status == .none ? .clear : BrandTheme.border
    }

    private var foreground: Color {
        status == .none ? BrandTheme.bg : BrandTheme.text
    }

    private var iconBackground: Color {
        status == .none ? Color.black.opacity(0.15) : BrandTheme.primarySoft
    }

    private var iconForeground: Color {
        status == .none ? BrandTheme.bg : BrandTheme.primaryText
    }

    private func load() async {
        // Reset to .none while we re-fetch so we don't briefly display stale
        // state from a previous detail page.
        isLoaded = false
        do {
            let entry = try await env.apiClient.watchStatus(type: item.contentType, id: item.id)
            // Always overwrite from the server's answer — including "none", so
            // toggling off elsewhere is reflected here.
            status = WatchStatus(rawValue: entry.status) ?? .none
        } catch {
            // Fall back to .none if the server is unreachable; better than
            // leaving stale state from a previous fetch.
            status = .none
        }
        isLoaded = true
    }

    private func setStatus(_ target: WatchStatus) async {
        guard target != status else { return }
        let previous = status
        status = target
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            _ = try await env.apiClient.setWatchStatus(
                type: item.contentType,
                id: item.id,
                target: target.rawValue,
                current: previous.rawValue,
                notify: true
            )
        } catch {
            status = previous
            errorMessage = error.localizedDescription
        }
    }
}
