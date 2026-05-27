import SwiftUI
import NukeUI

// MARK: - TMDB image URLs

enum TMDBImage {
    static func poster(_ path: String?, size: String = "w342") -> URL? {
        path.flatMap { URL(string: "https://image.tmdb.org/t/p/\(size)\($0)") }
    }
    static func backdrop(_ path: String?, size: String = "w780") -> URL? {
        path.flatMap { URL(string: "https://image.tmdb.org/t/p/\(size)\($0)") }
    }
    static func still(_ path: String?, size: String = "w300") -> URL? {
        path.flatMap { URL(string: "https://image.tmdb.org/t/p/\(size)\($0)") }
    }
    static func providerLogo(_ path: String?) -> URL? {
        path.flatMap { URL(string: "https://image.tmdb.org/t/p/original\($0)") }
    }
}

// MARK: - Username hue (matches web app's `hashHue` helper)

enum UsernameColor {
    static func hue(for username: String) -> Double {
        var hash = 0
        for char in username.unicodeScalars {
            hash = (hash &* 31) &+ Int(char.value)
        }
        return Double(abs(hash) % 360) / 360.0
    }

    static func color(for username: String, saturation: Double = 0.6, brightness: Double = 0.9) -> Color {
        Color(hue: hue(for: username), saturation: saturation, brightness: brightness)
    }

    /// Background gradient for a friend/profile hero, tinted by the user's name.
    static func gradient(for username: String) -> LinearGradient {
        LinearGradient(
            colors: [
                Color(hue: hue(for: username), saturation: 0.55, brightness: 0.55),
                Color(hue: hue(for: username), saturation: 0.45, brightness: 0.30)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Avatar

struct AvatarView: View {
    let username: String?
    let avatarKey: String?
    let size: CGFloat

    init(username: String?, avatarKey: String? = nil, size: CGFloat = 48) {
        self.username = username
        self.avatarKey = avatarKey
        self.size = size
    }

    var body: some View {
        ZStack {
            Circle().fill(background)
            Text(initial)
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
        .overlay(Circle().stroke(Color.white.opacity(0.1), lineWidth: 1))
    }

    private var initial: String {
        guard let username, !username.isEmpty else { return "?" }
        return String(username.prefix(1)).uppercased()
    }

    private var background: Color {
        if let key = avatarKey, let preset = AvatarPreset(rawValue: key) {
            return preset.color
        }
        return UsernameColor.color(for: username ?? "?")
    }
}

enum AvatarPreset: String, CaseIterable, Identifiable {
    case blue, purple, green, red, orange, teal, pink, yellow

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .blue:   Color(hex: 0x3B82F6)
        case .purple: Color(hex: 0x8B5CF6)
        case .green:  Color(hex: 0x10B981)
        case .red:    Color(hex: 0xEF4444)
        case .orange: Color(hex: 0xF97316)
        case .teal:   Color(hex: 0x14B8A6)
        case .pink:   Color(hex: 0xEC4899)
        case .yellow: Color(hex: 0xEAB308)
        }
    }
}

// MARK: - Poster card (smaller, reusable, similar to LibraryPosterCell but public)

struct SharedPosterCard: View {
    let posterPath: String?
    let title: String
    let subtitle: String?
    let width: CGFloat

    init(posterPath: String?, title: String, subtitle: String? = nil, width: CGFloat = 110) {
        self.posterPath = posterPath
        self.title = title
        self.subtitle = subtitle
        self.width = width
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            LazyImage(url: TMDBImage.poster(posterPath)) { state in
                if let image = state.image {
                    image.resizable().scaledToFill()
                } else if state.error != nil {
                    Color.brandSurfaceElevated.overlay(Image(systemName: "photo").foregroundStyle(.secondary))
                } else {
                    Color.brandSurfaceElevated.overlay(ProgressView())
                }
            }
            .aspectRatio(2.0 / 3.0, contentMode: .fit)
            .frame(width: width)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .frame(width: width, alignment: .leading)

            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(Color.brandTextSecondary)
                    .frame(width: width, alignment: .leading)
                    .lineLimit(1)
            }
        }
    }
}

// MARK: - Backdrop card (16:9, for upcoming etc.)

struct BackdropCard: View {
    let backdropPath: String?
    let title: String
    let badge: String?
    let subtitle: String?
    let width: CGFloat

    init(
        backdropPath: String?,
        title: String,
        badge: String? = nil,
        subtitle: String? = nil,
        width: CGFloat = 260
    ) {
        self.backdropPath = backdropPath
        self.title = title
        self.badge = badge
        self.subtitle = subtitle
        self.width = width
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topLeading) {
                LazyImage(url: TMDBImage.backdrop(backdropPath)) { state in
                    if let image = state.image {
                        image.resizable().scaledToFill()
                    } else {
                        Color.brandSurfaceElevated
                    }
                }
                .aspectRatio(16.0 / 9.0, contentMode: .fill)
                .frame(width: width)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 12))

                if let badge {
                    Text(badge.uppercased())
                        .font(.system(.caption2, design: .monospaced))
                        .tracking(1.3)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.7), in: Capsule())
                        .foregroundStyle(.white)
                        .padding(10)
                }
            }
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .frame(width: width, alignment: .leading)
            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(Color.brandTextSecondary)
                    .frame(width: width, alignment: .leading)
            }
        }
    }
}

// MARK: - State helpers

/// Inline error banner shown above content sections.
struct InlineErrorBanner: View {
    let message: String
    var onRetry: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            Text(message)
                .font(.footnote)
                .foregroundStyle(.white)
            Spacer()
            if let onRetry {
                Button("Retry", action: onRetry)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.brandPrimary)
            }
        }
        .padding(12)
        .background(Color.brandSurface, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.brandBorder, lineWidth: 1))
    }
}

// MARK: - Section header

struct SectionHeader: View {
    let eyebrow: String?
    let title: String
    let subtitle: String?

    init(eyebrow: String? = nil, title: String, subtitle: String? = nil) {
        self.eyebrow = eyebrow
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let eyebrow {
                Text(eyebrow.uppercased())
                    .font(.system(.caption2, design: .monospaced))
                    .tracking(1.5)
                    .foregroundStyle(Color.brandTextSecondary)
            }
            Text(title)
                .font(.system(.title2, design: .serif))
                .foregroundStyle(.white)
            if let subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(Color.brandTextSecondary)
            }
        }
    }
}

// MARK: - Stat pill

struct StatPill: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(.title3, design: .serif).weight(.semibold))
                .foregroundStyle(.white)
            Text(label.uppercased())
                .font(.system(.caption2, design: .monospaced))
                .tracking(1.2)
                .foregroundStyle(Color.brandTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color.brandSurface, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.brandBorder, lineWidth: 1))
    }
}

// MARK: - Time-ago formatter

enum TimeAgo {
    static func format(_ iso: String?) -> String? {
        guard let iso, let date = parse(iso) else { return nil }
        let diff = -date.timeIntervalSinceNow
        if diff < 60 { return "just now" }
        if diff < 3600 { return "\(Int(diff / 60))m" }
        if diff < 86400 { return "\(Int(diff / 3600))h" }
        if diff < 604800 { return "\(Int(diff / 86400))d" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }

    private static func parse(_ iso: String) -> Date? {
        ISO8601DateFormatter().date(from: iso) ??
            ISO8601DateFormatter.fractional.date(from: iso)
    }
}

extension ISO8601DateFormatter {
    static let fractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
}

// MARK: - Loading placeholder

struct ShimmerBlock: View {
    let width: CGFloat?
    let height: CGFloat

    init(width: CGFloat? = nil, height: CGFloat) {
        self.width = width
        self.height = height
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(Color.brandSurface)
            .frame(width: width, height: height)
    }
}
