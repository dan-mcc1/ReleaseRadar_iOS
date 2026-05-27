import SwiftUI

/// Compact pair of overlay buttons used on poster cards in the Discover/Browse
/// surfaces. The bookmark toggles "Want To Watch", the checkmark toggles
/// "Watched". Both go through `/watch-status/set` so transitioning between
/// lists removes the item from its previous list (no double-listing).
struct MiniWatchButtons: View {
    let type: ContentType
    let id: Int

    @Environment(AppEnvironment.self) private var env
    @State private var status: WatchStatus = .none
    @State private var isLoaded = false
    @State private var isUpdating = false

    var body: some View {
        HStack(spacing: 6) {
            // Once something is watched or already in progress, the
            // watchlist button is redundant — leave just the watched
            // toggle so the viewer can mark it complete (which also
            // moves it off the currently-watching list).
            if status != .watched && status != .currentlyWatching {
                MiniWatchlistButton(
                    isActive: status == .wantToWatch,
                    isUpdating: isUpdating,
                    action: { Task { await toggle(.wantToWatch) } }
                )
            }
            MiniWatchedButton(
                isActive: status == .watched,
                isUpdating: isUpdating,
                action: { Task { await toggle(.watched) } }
            )
        }
        .task(id: "\(type.rawValue)-\(id)") { await load() }
    }

    private func load() async {
        do {
            let entry = try await env.apiClient.watchStatus(type: type, id: id)
            status = WatchStatus(rawValue: entry.status) ?? .none
        } catch {
            status = .none
        }
        isLoaded = true
    }

    /// Tapping a button that's already active clears the status (.none); tapping
    /// an inactive button transitions to that status. The backend's
    /// `/watch-status/set` handles the cross-list move atomically.
    private func toggle(_ target: WatchStatus) async {
        guard !isUpdating else { return }
        let previous = status
        let desired: WatchStatus = (status == target) ? .none : target
        status = desired
        isUpdating = true
        defer { isUpdating = false }
        do {
            _ = try await env.apiClient.setWatchStatus(
                type: type,
                id: id,
                target: desired.rawValue,
                current: previous.rawValue,
                notify: true
            )
        } catch {
            status = previous
        }
    }
}

// MARK: - Pieces

private struct MiniWatchlistButton: View {
    let isActive: Bool
    let isUpdating: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().fill(.black.opacity(0.55))
                Image(systemName: isActive ? "bookmark.fill" : "bookmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(isActive ? Color.brandPrimary : .white)
            }
            .frame(width: 28, height: 28)
            .overlay(Circle().stroke(.white.opacity(0.15), lineWidth: 0.5))
            .opacity(isUpdating ? 0.5 : 1)
        }
        .buttonStyle(.plain)
        .disabled(isUpdating)
    }
}

/// Tiny "in progress" pill that overlays a poster when the viewer has
/// the title marked as `Currently Watching`. Performs its own status
/// fetch — the cost is minimal and it keeps the call sites trivially
/// simple (`CurrentlyWatchingBadge(type:, id:)` in any overlay slot).
struct CurrentlyWatchingBadge: View {
    let type: ContentType
    let id: Int

    @Environment(AppEnvironment.self) private var env
    @State private var isCurrentlyWatching = false

    var body: some View {
        Group {
            if isCurrentlyWatching {
                HStack(spacing: 3) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 7, weight: .bold))
                    Text("WATCHING")
                        .font(BrandFont.mono(8.5, weight: .bold))
                        .tracking(0.8)
                }
                .foregroundStyle(BrandTheme.bg)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(BrandTheme.primary, in: Capsule())
                .shadow(color: .black.opacity(0.35), radius: 3, y: 1)
            }
        }
        .task(id: "\(type.rawValue)-\(id)") {
            do {
                let entry = try await env.apiClient.watchStatus(type: type, id: id)
                isCurrentlyWatching = entry.status == WatchStatus.currentlyWatching.rawValue
            } catch {
                isCurrentlyWatching = false
            }
        }
    }
}

private struct MiniWatchedButton: View {
    let isActive: Bool
    let isUpdating: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().fill(.black.opacity(0.55))
                Image(systemName: isActive ? "checkmark.circle.fill" : "checkmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(isActive ? .green : .white)
            }
            .frame(width: 28, height: 28)
            .overlay(Circle().stroke(.white.opacity(0.15), lineWidth: 0.5))
            .opacity(isUpdating ? 0.5 : 1)
        }
        .buttonStyle(.plain)
        .disabled(isUpdating)
    }
}
