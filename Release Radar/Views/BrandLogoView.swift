import SwiftUI

/// Renders the Release Radar logo (radar dish + play triangle) from the
/// AppLogo image set in Assets.xcassets.
struct BrandLogoView: View {
    var size: CGFloat = 96

    var body: some View {
        Image("AppLogo")
            .resizable()
            .interpolation(.high)
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
    }
}

#Preview {
    VStack(spacing: 24) {
        BrandLogoView(size: 128)
        BrandLogoView(size: 64)
        BrandLogoView(size: 32)
    }
    .padding()
    .background(Color.brandBackground)
}
