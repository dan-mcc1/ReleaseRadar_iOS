import SwiftUI

// MARK: - Color tokens

extension Color {
    // Legacy aliases — point at the new BrandTheme tokens so existing
    // screens automatically pick up the redesigned palette.
    static var brandPrimary: Color        { BrandTheme.primary }
    static var brandPrimaryDark: Color    { Color(hex: 0x047857) }
    static var brandBackground: Color     { BrandTheme.bg }
    static var brandSurface: Color        { BrandTheme.surface }
    static var brandSurfaceElevated: Color { BrandTheme.surface2 }
    static var brandBorder: Color         { BrandTheme.border }
    static var brandTextSecondary: Color  { BrandTheme.textMuted }

    init(hex: UInt32, opacity: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: opacity)
    }
}

/// New design-language tokens. Use these for any screen redesigned to match the
/// editorial mock (Calendar, etc.). They sit alongside the legacy `brand*`
/// tokens so we can migrate screen-by-screen.
enum BrandTheme {
    // Backgrounds
    static let bg              = Color(hex: 0x0A0A0A) // page
    static let surface         = Color(hex: 0x141414) // card
    static let surface2        = Color(hex: 0x1F1F1F) // elevated card / track
    // Lines
    static let border          = Color(hex: 0x262626)
    static let borderStrong    = Color(hex: 0x3A3A3A)
    // Text
    static let text            = Color(hex: 0xF5F5F3) // primary
    static let textMuted       = Color(hex: 0xA3A3A3) // secondary
    static let textDim         = Color(hex: 0x6B6B6B) // tertiary / eyebrow
    // Accent (emerald)
    static let primary         = Color(hex: 0x10B981)
    static let primaryText     = Color(hex: 0x34D399) // foreground variant on dark bg
    static let primarySoft     = Color(hex: 0x10B981).opacity(0.14)
}

// MARK: - Typography

/// Centralized type ramp for the new design language.
///
/// Today these resolve to system fonts (SF Pro, .monospaced, .serif italic).
/// When IBM Plex Sans / Plex Mono .ttf files are added to the Xcode target
/// and listed in Info.plist's `UIAppFonts`, change the helpers below to
/// `Font.custom("IBMPlexSans-Regular", size: …)` etc. — every screen using
/// `BrandFont.*` will pick up the new face automatically.
enum BrandFont {
    /// Geist Mono stand-in — uppercase eyebrow labels, mono detail text.
    static func mono(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    /// Geist stand-in — sans-serif body / UI.
    static func sans(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }

    /// Instrument Serif stand-in — large editorial titles and italic accents.
    /// (System "New York" serif italic is the closest built-in match.)
    static func serif(_ size: CGFloat, italic: Bool = false) -> Font {
        let base = Font.system(size: size, weight: .regular, design: .serif)
        return italic ? base.italic() : base
    }
}
