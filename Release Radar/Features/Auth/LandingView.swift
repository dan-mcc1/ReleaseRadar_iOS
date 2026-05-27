import SwiftUI

/// First-launch onboarding screen. Editorial promise layout (eyebrow +
/// serif title + three feature rows + two CTAs) over the same radar
/// sweep visual the web app uses on its public landing page.
///
/// Both CTAs land the user on `SignInView` — the difference is purely
/// expectational ("Get started" implies new account, "I already have an
/// account" implies returning user). Tapping either flips the
/// `hasSeenLanding` flag (owned by the caller) so subsequent sign-outs
/// skip this screen.
struct LandingView: View {
    /// Invoked when the user taps either CTA. Caller is responsible for
    /// persisting the "has seen landing" state and switching the root
    /// view to the sign-in screen.
    var onContinue: () -> Void

    var body: some View {
        ZStack {
            BrandTheme.bg.ignoresSafeArea()
            RadarSweepBackground()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top brand mark + mono caption
                HStack(spacing: 10) {
                    BrandLogoView(size: 28)
                    // Two pieces with an explicit visible gap between
                    // them — a single space inside a mono `tracking`
                    // run can look like "RELEASERADAR" because the
                    // letter-spacing dwarfs the space character.
                    HStack(spacing: 6) {
                        Text("RELEASE")
                            .font(BrandFont.mono(11, weight: .medium))
                            .tracking(1.8)
                        Text("RADAR")
                            .font(BrandFont.mono(11, weight: .medium))
                            .tracking(1.8)
                    }
                    .foregroundStyle(BrandTheme.textMuted)
                    Spacer(minLength: 0)
                }
                .padding(.top, 6)

                Spacer(minLength: 0)
                    .frame(height: 48)

                // Headline block
                VStack(alignment: .leading, spacing: 14) {
                    Text("ON THE HORIZON")
                        .font(BrandFont.mono(10.5, weight: .semibold))
                        .tracking(1.6)
                        .foregroundStyle(BrandTheme.primaryText)

                    headline

                    Text("Track movies and TV across every streaming service. Build a watchlist that doesn't feel like homework.")
                        .font(BrandFont.sans(15))
                        .foregroundStyle(BrandTheme.textMuted)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: 300, alignment: .leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: 0)
                    .frame(height: 40)

                // Three promise rows
                VStack(alignment: .leading, spacing: 22) {
                    ForEach(Self.promises) { promise in
                        promiseRow(promise)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: 24)

                // CTAs
                VStack(spacing: 10) {
                    Button(action: onContinue) {
                        HStack(spacing: 8) {
                            Text("Get started")
                                .font(BrandFont.sans(15, weight: .semibold))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 13, weight: .bold))
                        }
                        .foregroundStyle(BrandTheme.bg)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(BrandTheme.primary, in: RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)

                    Button(action: onContinue) {
                        Text("I already have an account")
                            .font(BrandFont.sans(14, weight: .medium))
                            .foregroundStyle(BrandTheme.text)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, 14)
            }
            .padding(.horizontal, 28)
            .padding(.top, 8)
        }
    }

    private var headline: some View {
        (
            Text("Never miss\n")
                .font(BrandFont.serif(46))
                .foregroundColor(BrandTheme.text)
            + Text("what's coming.")
                .font(BrandFont.serif(46, italic: true))
                .foregroundColor(BrandTheme.primaryText)
        )
        .lineSpacing(-4)
        .multilineTextAlignment(.leading)
        .frame(maxWidth: 300, alignment: .leading)
    }

    private func promiseRow(_ p: Promise) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: p.icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(BrandTheme.primaryText)
                .frame(width: 38, height: 38)
                .background(BrandTheme.primarySoft, in: RoundedRectangle(cornerRadius: 11))

            VStack(alignment: .leading, spacing: 2) {
                (
                    Text(p.title + " ")
                        .font(BrandFont.sans(15, weight: .medium))
                        .foregroundColor(BrandTheme.text)
                    + Text(p.accent)
                        .font(BrandFont.serif(17, italic: true))
                        .foregroundColor(BrandTheme.text)
                )
                Text(p.detail)
                    .font(BrandFont.sans(12.5))
                    .foregroundStyle(BrandTheme.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: - Content

    private struct Promise: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let accent: String
        let detail: String
    }

    private static let promises: [Promise] = [
        .init(
            icon: "calendar",
            title: "A calendar",
            accent: "for what you watch",
            detail: "Every release date for every show you follow."
        ),
        .init(
            icon: "sparkles",
            title: "Recommendations",
            accent: "worth your time",
            detail: "No infinite scroll. Just things you might love."
        ),
        .init(
            icon: "person.2.fill",
            title: "A circle",
            accent: "of taste",
            detail: "See what your friends rated, send the good ones."
        ),
    ]
}

// MARK: - Radar sweep background
//
// Direct port of the web app's `RadarSVG` from
// `frontend/src/pages/LandingPage.tsx`: 7 concentric emerald rings, four
// faint reference lines, a single sweep wedge filled with a horizontal
// emerald gradient, and 9 scatter dots in oklch-derived hues. Rendered
// via SwiftUI's `Canvas` so it scales to any screen and stays cheap.

struct RadarSweepBackground: View {
    var body: some View {
        GeometryReader { geo in
            Canvas { context, size in
                let primary = BrandTheme.primary
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                // SVG was built in a 600x600 viewBox; scale uniformly so
                // ring radii and dot positions translate to whatever the
                // device gives us.
                let scale = max(size.width, size.height) / 600

                // Concentric rings — radii + per-radius opacity ramp
                // mirrors the web component exactly.
                let radii: [Double] = [60, 110, 165, 220, 278, 338, 400]
                for r in radii {
                    let radius = CGFloat(r) * scale
                    let opacity = 0.5 - r / 1400
                    let rect = CGRect(
                        x: center.x - radius,
                        y: center.y - radius,
                        width: radius * 2,
                        height: radius * 2
                    )
                    context.stroke(
                        Path(ellipseIn: rect),
                        with: .color(primary.opacity(opacity)),
                        lineWidth: 0.7
                    )
                }

                // Reference lines — horizontal, vertical, two diagonals.
                func line(_ a: CGPoint, _ b: CGPoint, _ op: Double) {
                    var p = Path()
                    p.move(to: a)
                    p.addLine(to: b)
                    context.stroke(p, with: .color(primary.opacity(op)), lineWidth: 1)
                }
                line(CGPoint(x: 0, y: center.y), CGPoint(x: size.width, y: center.y), 0.10)
                line(CGPoint(x: center.x, y: 0), CGPoint(x: center.x, y: size.height), 0.10)
                line(.zero, CGPoint(x: size.width, y: size.height), 0.06)
                line(CGPoint(x: size.width, y: 0), CGPoint(x: 0, y: size.height), 0.06)

                // Sweep wedge — upper-right quadrant only, filled with a
                // linear gradient that fades from transparent at center
                // to emerald at the wedge's outer edge.
                let sweepRadius: CGFloat = 400 * scale
                let endRight = CGPoint(x: center.x + sweepRadius, y: center.y)
                let cornerUpRight = CGPoint(
                    x: center.x + cos(-.pi / 4) * sweepRadius,
                    y: center.y + sin(-.pi / 4) * sweepRadius
                )
                var wedge = Path()
                wedge.move(to: center)
                wedge.addLine(to: endRight)
                wedge.addArc(
                    center: center,
                    radius: sweepRadius,
                    startAngle: .radians(0),
                    endAngle: .radians(-.pi / 4),
                    clockwise: true
                )
                wedge.closeSubpath()
                context.fill(
                    wedge,
                    with: .linearGradient(
                        Gradient(stops: [
                            .init(color: primary.opacity(0), location: 0),
                            .init(color: primary.opacity(0.4), location: 1),
                        ]),
                        startPoint: center,
                        endPoint: cornerUpRight
                    )
                )

                // Scatter dots — colorful inner disc + soft emerald halo.
                let dots: [(CGFloat, CGFloat, Double)] = [
                    (430, 220, 90),
                    (375, 385, 128),
                    (240, 178, 166),
                    (182, 358, 204),
                    (460, 378, 242),
                    (205, 480, 280),
                    (410, 132, 318),
                    (320, 460, 356),
                    (150, 250, 34),
                ]
                for (x, y, hue) in dots {
                    let cx = (x / 600) * size.width
                    let cy = (y / 600) * size.height
                    let haloR: CGFloat = 10 * scale
                    let dotR: CGFloat = 5 * scale

                    let halo = Path(ellipseIn: CGRect(
                        x: cx - haloR, y: cy - haloR,
                        width: haloR * 2, height: haloR * 2
                    ))
                    context.fill(halo, with: .color(primary.opacity(0.1)))

                    let dot = Path(ellipseIn: CGRect(
                        x: cx - dotR, y: cy - dotR,
                        width: dotR * 2, height: dotR * 2
                    ))
                    let color = Color(hue: hue.truncatingRemainder(dividingBy: 360) / 360,
                                      saturation: 0.45,
                                      brightness: 0.7)
                    context.fill(dot, with: .color(color))
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .opacity(0.35)
        .allowsHitTesting(false)
    }
}

#Preview {
    LandingView(onContinue: {})
        .environment(AppEnvironment())
        .tint(.brandPrimary)
        .preferredColorScheme(.dark)
}
