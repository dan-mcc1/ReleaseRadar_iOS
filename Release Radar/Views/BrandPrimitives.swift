import SwiftUI
import NukeUI

// MARK: - Eyebrow label
//
// Uppercase monospaced caption used above large titles and section headers.

struct EyebrowLabel: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(BrandFont.mono(10.5, weight: .medium))
            .tracking(1.6)
            .foregroundStyle(BrandTheme.textDim)
    }
}

// MARK: - Smaller section header with italic emerald accent

struct SectionTitle: View {
    let title: String
    let accent: String?
    let trailing: String?

    init(_ title: String, accent: String? = nil, trailing: String? = nil) {
        self.title = title
        self.accent = accent
        self.trailing = trailing
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(attributed)
            Spacer(minLength: 0)
            if let trailing {
                Text(trailing)
                    .font(BrandFont.sans(12))
                    .foregroundStyle(BrandTheme.textMuted)
            }
        }
    }

    private var attributed: AttributedString {
        var result = AttributedString(title)
        result.font = BrandFont.serif(22)
        result.foregroundColor = BrandTheme.text
        if let accent {
            var accentPart = AttributedString(" \(accent)")
            accentPart.font = BrandFont.serif(22, italic: true)
            accentPart.foregroundColor = BrandTheme.primaryText
            result.append(accentPart)
        }
        return result
    }
}

// MARK: - Filter chip + chip row

struct FilterChip: View {
    let label: String
    let count: Int?
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(label)
                    .font(BrandFont.sans(12.5, weight: .medium))
                if let count {
                    Text("\(count)")
                        .font(BrandFont.mono(10))
                        .opacity(0.6)
                }
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 7)
            .foregroundStyle(isActive ? BrandTheme.bg : BrandTheme.text)
            .background(
                Capsule().fill(isActive ? BrandTheme.text : BrandTheme.surface)
            )
            .overlay(
                Capsule().stroke(isActive ? .clear : BrandTheme.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Progress track — thin emerald progress bar (0…1)
//
// Use the larger height for "progress card" surfaces and the small variant
// for incidental overlays (poster thumbnails, list rows, etc.).

struct ProgressTrack: View {
    let fraction: Double
    var height: CGFloat = 6
    /// Subtle dark base used in cards. Pass `.clear` when the track is
    /// laid on top of an image and you want the unfilled portion invisible.
    var trackColor: Color = BrandTheme.surface2
    var fillColor: Color = BrandTheme.primary

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(trackColor)
                Capsule()
                    .fill(fillColor)
                    .frame(width: max(0, min(1, fraction)) * geo.size.width)
            }
        }
        .frame(height: height)
    }
}

// MARK: - Page background — apply to root VStacks of redesigned screens

struct PageBackground: ViewModifier {
    func body(content: Content) -> some View {
        content.background(BrandTheme.bg.ignoresSafeArea())
    }
}

extension View {
    func pageBackground() -> some View {
        modifier(PageBackground())
    }

    /// Installs a window-level tap recognizer that dismisses the keyboard
    /// whenever the user taps outside a text input or other UIControl.
    /// Apply once at the root of the app — the gesture lives on the
    /// `UIWindow`, so it covers every screen including pushed views and
    /// presented sheets.
    func dismissKeyboardOnOutsideTap() -> some View {
        background {
            KeyboardDismissTapInstaller()
                .frame(width: 0, height: 0)
        }
    }
}

private struct KeyboardDismissTapInstaller: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView { UIView() }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            guard let window = uiView.window else { return }
            Self.install(on: window)
        }
    }

    private static let recognizerName = "ReleaseRadarKeyboardDismiss"

    private static func install(on window: UIWindow) {
        if window.gestureRecognizers?.contains(where: { $0.name == recognizerName }) == true {
            return
        }
        let tap = UITapGestureRecognizer(
            target: window,
            action: #selector(UIView.endEditing)
        )
        tap.name = recognizerName
        tap.cancelsTouchesInView = false
        tap.delegate = KeyboardDismissTapDelegate.shared
        window.addGestureRecognizer(tap)
    }
}

private final class KeyboardDismissTapDelegate: NSObject, UIGestureRecognizerDelegate {
    static let shared = KeyboardDismissTapDelegate()

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
    ) -> Bool {
        true
    }

    /// Skip the dismiss when the user tapped on a `UIControl` (text field,
    /// button, segmented control). Without this guard, tapping an
    /// already-focused field would re-fire `endEditing`, and tapping any
    /// other button could fight with the button's tap.
    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldReceive touch: UITouch
    ) -> Bool {
        var view: UIView? = touch.view
        while let v = view {
            if v is UIControl { return false }
            view = v.superview
        }
        return true
    }
}

// MARK: - Large editorial title (eyebrow + serif title + optional italic accent + trailing slot)

struct LargeTitleHeader<Trailing: View>: View {
    let eyebrow: String?
    let title: String
    /// Optional italic accent rendered in emerald serif italic after the title.
    let accent: String?
    @ViewBuilder var trailing: () -> Trailing

    init(
        eyebrow: String? = nil,
        title: String,
        accent: String? = nil,
        @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }
    ) {
        self.eyebrow = eyebrow
        self.title = title
        self.accent = accent
        self.trailing = trailing
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let eyebrow {
                EyebrowLabel(text: eyebrow)
            }
            HStack(alignment: .lastTextBaseline, spacing: 12) {
                Text(attributedTitle)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 8)
                trailing()
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 14)
    }

    private var attributedTitle: AttributedString {
        var result = AttributedString(title)
        result.font = BrandFont.serif(38)
        result.foregroundColor = BrandTheme.text
        if let accent {
            var accentPart = AttributedString(" \(accent)")
            accentPart.font = BrandFont.serif(38, italic: true)
            accentPart.foregroundColor = BrandTheme.primaryText
            result.append(accentPart)
        }
        return result
    }
}

// MARK: - Icon buttons (soft = neutral surface, accent = emerald soft)

struct SoftIconButton: View {
    let systemName: String
    var size: CGFloat = 38
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(BrandTheme.text)
                .frame(width: size, height: size)
                .background(BrandTheme.surface, in: RoundedRectangle(cornerRadius: size / 2.8))
                .overlay(
                    RoundedRectangle(cornerRadius: size / 2.8)
                        .stroke(BrandTheme.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

struct AccentIconButton: View {
    let systemName: String
    var size: CGFloat = 38
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(BrandTheme.primaryText)
                .frame(width: size, height: size)
                .background(BrandTheme.primarySoft, in: RoundedRectangle(cornerRadius: size / 2.8))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Day cell used inside the week strip

struct WeekStripDay: View {
    let date: Date
    let isToday: Bool
    let isSelected: Bool
    /// Number of releases on this date (used to render up to 3 indicator dots).
    let releaseCount: Int
    let onTap: () -> Void

    private static let dowFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEEE" // narrow, single letter
        return f
    }()
    private static let dayNumberFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d"
        return f
    }()

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 3) {
                Text(Self.dowFormatter.string(from: date))
                    .font(BrandFont.mono(9.5, weight: .medium))
                    .tracking(1.2)
                    .foregroundStyle(isToday ? BrandTheme.bg.opacity(0.6) : BrandTheme.textDim)
                Text(Self.dayNumberFormatter.string(from: date))
                    .font(BrandFont.sans(16, weight: .semibold))
                    .foregroundStyle(isToday ? BrandTheme.bg : BrandTheme.text)
                HStack(spacing: 2) {
                    ForEach(0..<min(3, releaseCount), id: \.self) { _ in
                        Circle()
                            .fill(isToday ? BrandTheme.bg.opacity(0.55) : BrandTheme.primary)
                            .frame(width: 3, height: 3)
                    }
                }
                .frame(height: 4)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 13)
                    .fill(backgroundFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 13)
                    .stroke(strokeColor, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var backgroundFill: Color {
        if isToday { return BrandTheme.text }
        if isSelected { return BrandTheme.surface2 }
        return .clear
    }

    private var strokeColor: Color {
        if isToday { return .clear }
        if isSelected { return BrandTheme.borderStrong }
        return BrandTheme.border
    }
}

// MARK: - Hero release card (big backdrop with gradient + chip + title)
//
// The card itself navigates to `destination` when tapped. The checkmark pill
// in the top-right is its own Button — tapping it fires `onWatchedToggle`
// without triggering navigation, so users can mark watched / unwatched
// in-line without leaving the calendar.

struct HeroReleaseCard<Destination: View>: View {
    let backdropURL: URL?
    let chipText: String
    /// Color of the chip's text — `nil` falls back to the emerald accent.
    var chipColor: Color? = nil
    /// Optional secondary tag (Season Premiere, Finale, etc.) shown below the
    /// main chip in the top-left of the backdrop.
    var tagText: String? = nil
    var tagColor: Color? = nil
    let title: String
    let metadata: [String]
    let isWatched: Bool
    let onWatchedToggle: () -> Void
    @ViewBuilder let destination: () -> Destination

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Background NavigationLink covers the full card area so taps
            // anywhere (except on the checkmark Button) push detail.
            NavigationLink(destination: destination) {
                cardBody
            }
            .buttonStyle(.plain)

            // Foreground checkmark Button — owns its own hit area, so it
            // intercepts taps before they reach the NavigationLink below.
            VStack {
                HStack {
                    Spacer()
                    watchedButton
                }
                Spacer()
            }
            .padding(12)
            .allowsHitTesting(true)
        }
    }

    private var cardBody: some View {
        ZStack(alignment: .bottomLeading) {
            LazyImage(url: backdropURL) { state in
                if let image = state.image {
                    image.resizable().scaledToFill()
                } else {
                    BrandTheme.surface2
                }
            }
            .frame(height: 180)
            .frame(maxWidth: .infinity)
            .clipped()

            LinearGradient(
                colors: [
                    Color.black.opacity(0.05),
                    Color.black.opacity(0.15),
                    Color.black.opacity(0.78)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        chip
                        if let tagText {
                            tagChip(text: tagText, color: tagColor ?? BrandTheme.primaryText)
                        }
                    }
                    Spacer()
                }
                Spacer()
            }
            .padding(12)

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(BrandFont.serif(24))
                    .foregroundStyle(Color(hex: 0xF5F5F3))
                    .lineLimit(2)
                    .shadow(color: .black.opacity(0.5), radius: 12, x: 0, y: 1)
                if !metadata.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(Array(metadata.enumerated()), id: \.offset) { idx, value in
                            if idx > 0 {
                                Text("·").opacity(0.5)
                            }
                            Text(value)
                        }
                    }
                    .font(BrandFont.sans(11.5))
                    .foregroundStyle(Color(hex: 0xF5F5F3).opacity(0.85))
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity)
        .background(BrandTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(BrandTheme.border, lineWidth: 1)
        )
    }

    private var chip: some View {
        Text(chipText.uppercased())
            .font(BrandFont.mono(9.5, weight: .semibold))
            .tracking(1.4)
            .foregroundStyle(chipColor ?? BrandTheme.primaryText)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(Color.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 6))
    }

    /// Secondary tag chip — colored fill instead of the primary chip's dark
    /// translucent style, so the two read as distinct categories of info.
    private func tagChip(text: String, color: Color) -> some View {
        Text(text.uppercased())
            .font(BrandFont.mono(9.5, weight: .bold))
            .tracking(1.4)
            .foregroundStyle(.white)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(color.opacity(0.85), in: RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(color, lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 1)
    }

    private var watchedButton: some View {
        Button(action: onWatchedToggle) {
            Image(systemName: "checkmark")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isWatched ? BrandTheme.primaryText : .black)
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(isWatched
                              ? Color.black.opacity(0.55)
                              : Color.white.opacity(0.92))
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Agenda poster row (used for non-hero releases under each day)
//
// Like the hero card, the whole row is one NavigationLink — the checkmark
// pill on the right is a visual indicator, not a separate tap target.

struct AgendaPosterRow<Destination: View>: View {
    let posterURL: URL?
    let title: String
    let line1: String?  // e.g. "S2 E5 · Episode title"
    let line2: String?  // e.g. "Movie release"
    let isWatched: Bool
    @ViewBuilder let destination: () -> Destination

    var body: some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 12) {
                LazyImage(url: posterURL) { state in
                    if let image = state.image {
                        image.resizable().scaledToFill()
                    } else {
                        BrandTheme.surface2
                    }
                }
                .frame(width: 56, height: 84)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 7))

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(BrandFont.sans(14.5, weight: .semibold))
                        .foregroundStyle(BrandTheme.text)
                        .lineLimit(1)
                    if let line1 {
                        Text(line1)
                            .font(BrandFont.sans(11.5))
                            .foregroundStyle(BrandTheme.textMuted)
                            .lineLimit(1)
                    }
                    if let line2 {
                        Text(line2)
                            .font(BrandFont.mono(11, weight: .medium))
                            .tracking(0.6)
                            .foregroundStyle(BrandTheme.textDim)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                checkmarkIndicator
            }
            .padding(10)
            .background(BrandTheme.surface, in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(BrandTheme.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var checkmarkIndicator: some View {
        Image(systemName: "checkmark")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(isWatched ? BrandTheme.primaryText : BrandTheme.textMuted)
            .frame(width: 34, height: 34)
            .background(
                (isWatched ? BrandTheme.primarySoft : BrandTheme.surface2)
                    .clipShape(RoundedRectangle(cornerRadius: 9))
            )
    }
}
