import SwiftUI

/// Top-of-Discover navigation grid — gives access to the drill-down
/// surfaces (For You, Upcoming, Browse Genres, Box Office, Collections,
/// Groups, News). Tiles wrap into multiple rows so nothing is hidden
/// off-screen. Each hub is a vertical tile (icon badge + label).
struct DiscoverHubMenu: View {
    private let columns = [GridItem(.adaptive(minimum: 72), spacing: 14, alignment: .top)]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .center, spacing: 14) {
            hubLink(title: "For You", icon: "sparkles") { ForYouView() }
            hubLink(title: "Upcoming", icon: "calendar") { UpcomingView() }
            hubLink(title: "Genres", icon: "tag") { BrowseGenresView() }
            hubLink(title: "Box Office", icon: "dollarsign.circle") { BoxOfficeView() }
            hubLink(title: "Collections", icon: "rectangle.stack") { BrowseCollectionsView() }
            hubLink(title: "Groups", icon: "person.3") { BrowseGroupsView() }
            hubLink(title: "News", icon: "newspaper") { NewsView() }
        }
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private func hubLink<Destination: View>(
        title: String,
        icon: String,
        @ViewBuilder destination: @escaping () -> Destination
    ) -> some View {
        NavigationLink(destination: destination()) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(BrandTheme.primaryText)
                    .frame(width: 44, height: 44)
                    .background(BrandTheme.primarySoft, in: Circle())
                    .overlay(Circle().stroke(BrandTheme.border, lineWidth: 1))
                Text(title)
                    .font(BrandFont.sans(11, weight: .medium))
                    .foregroundStyle(BrandTheme.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
