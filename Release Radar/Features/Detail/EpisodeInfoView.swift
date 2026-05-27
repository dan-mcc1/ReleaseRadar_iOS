import SwiftUI
import NukeUI

/// Detail page for a single TV episode. Reached from the Calendar (when the
/// user taps an episode entry) and the Show Info page's seasons tab. Mirrors
/// the web app's EpisodeInfo page: hero still + breadcrumb + badge row +
/// title + watched panel + synopsis + crew + cast + prev/next nav.
struct EpisodeInfoView: View {
    let showID: Int
    let season: Int
    let episode: Int
    /// Pre-populated show name so the breadcrumb reads immediately while
    /// the show payload loads in the background.
    var initialShowName: String? = nil

    @Environment(AppEnvironment.self) private var env

    @State private var details: EpisodeDetails?
    @State private var showName: String?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var isWatched = false
    @State private var watchedBusy = false
    @State private var prevEpisode: EpisodeDetails?
    @State private var nextEpisode: EpisodeDetails?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if isLoading && details == nil {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, 64)
                } else if let errorMessage, details == nil {
                    InlineErrorBanner(message: errorMessage) { Task { await load() } }
                        .padding(.horizontal, 16)
                } else if let details {
                    breadcrumb(details: details)
                    heroStill(details: details)
                    titleBlock(details: details)
                    if let overview = details.overview, !overview.isEmpty {
                        synopsisSection(overview: overview)
                    }
                    let directors = details.crew.filter { $0.job == "Director" }
                    let writers = details.crew.filter { $0.job == "Writer" || $0.job == "Teleplay" }
                    if !directors.isEmpty || !writers.isEmpty {
                        crewSection(directors: directors, writers: writers)
                    }
                    let allCast = Array((details.guestStars + details.cast).prefix(12))
                    if !allCast.isEmpty {
                        castSection(allCast)
                    }
                    prevNextNav(details: details)
                }
            }
            .padding(.bottom, 32)
        }
        .pageBackground()
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    // MARK: - Sections

    private func breadcrumb(details: EpisodeDetails) -> some View {
        HStack(spacing: 6) {
            if let showName {
                // Tappable show-name pill — emerald text + subtle outline so
                // it reads as a link inside the otherwise-flat mono breadcrumb.
                NavigationLink {
                    MediaDetailView(
                        item: MediaItem(
                            id: showID,
                            contentType: .tv,
                            title: showName,
                            posterPath: nil
                        )
                    )
                } label: {
                    HStack(spacing: 3) {
                        Text(showName)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .font(BrandFont.mono(11, weight: .semibold))
                    .tracking(0.9)
                    .foregroundStyle(BrandTheme.primaryText)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(BrandTheme.primarySoft, in: Capsule())
                }
                .buttonStyle(.plain)

                Text("/").foregroundStyle(BrandTheme.borderStrong)
            }
            NavigationLink {
                SeasonInfoView(
                    showID: showID,
                    seasonNumber: details.seasonNumber,
                    initialShowName: showName
                )
            } label: {
                Text("Season \(details.seasonNumber)")
                    .foregroundStyle(BrandTheme.primaryText)
            }
            .buttonStyle(.plain)
            Text("/").foregroundStyle(BrandTheme.borderStrong)
            Text("Episode \(String(format: "%02d", details.episodeNumber))")
                .foregroundStyle(BrandTheme.text)
        }
        .font(BrandFont.mono(11, weight: .medium))
        .tracking(0.9)
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }

    @ViewBuilder
    private func heroStill(details: EpisodeDetails) -> some View {
        if let url = details.stillURL {
            ZStack(alignment: .bottom) {
                LazyImage(url: url) { state in
                    if let image = state.image {
                        image.resizable().scaledToFill()
                    } else {
                        BrandTheme.surface2
                    }
                }
                .aspectRatio(16.0 / 9.0, contentMode: .fill)
                .frame(maxWidth: .infinity)
                .clipped()
                LinearGradient(
                    colors: [.clear, .clear, .black.opacity(0.5)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .allowsHitTesting(false)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16).stroke(BrandTheme.border, lineWidth: 1)
            )
            .padding(.horizontal, 16)
        }
    }

    private func titleBlock(details: EpisodeDetails) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Chips + air date live in the left column; the watched toggle
            // sits on the right but is anchored to the top of the column so
            // its 44pt height doesn't stretch the chip row's spacing.
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    badgeRow(details: details)
                    if let air = details.airDate {
                        Text(air.formatted(.dateTime.month(.wide).day().year()).uppercased())
                            .font(BrandFont.mono(11, weight: .medium))
                            .tracking(1.1)
                            .foregroundStyle(BrandTheme.textDim)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                watchedToggle
            }
            EyebrowLabel(text: "Episode title")
            Text(details.name)
                .font(BrandFont.serif(38, italic: true))
                .foregroundStyle(BrandTheme.text)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 16)
    }

    /// Mark-as-watched checkmark — sits at the trailing edge of the
    /// badge row alongside the season/episode/runtime/date chips. Tapping
    /// flips the state optimistically and rolls back on API failure.
    private var watchedToggle: some View {
        Button(action: { Task { await toggleWatched() } }) {
            ZStack {
                Circle()
                    .fill(isWatched ? BrandTheme.primary : BrandTheme.surface)
                    .frame(width: 44, height: 44)
                if watchedBusy {
                    ProgressView()
                        .controlSize(.small)
                        .tint(isWatched ? BrandTheme.bg : BrandTheme.text)
                } else {
                    Image(systemName: "checkmark")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(isWatched ? BrandTheme.bg : BrandTheme.textMuted)
                }
            }
            .overlay(
                Circle().stroke(isWatched ? .clear : BrandTheme.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(watchedBusy)
        .accessibilityLabel(isWatched ? "Mark as unwatched" : "Mark as watched")
    }

    private func badgeRow(details: EpisodeDetails) -> some View {
        // Wrap horizontally — episodes can have multiple chips.
        FlowLayout(spacing: 8) {
            // Season/Episode code
            chip(
                text: "\(details.seasonCode) · \(details.episodeCode)",
                fg: BrandTheme.primaryText,
                bg: BrandTheme.primarySoft,
                mono: true
            )
            // Premiere / Finale tag
            if let tag = episodeTag(for: details) {
                chip(text: tag.label, fg: tag.fg, bg: tag.bg, mono: false, uppercase: true)
            }
            // TMDb rating
            if let avg = details.voteAverage, avg > 0 {
                chip(
                    text: String(format: "★ %.1f", avg),
                    fg: Color(hex: 0xFBBF24),
                    bg: Color(hex: 0xFBBF24).opacity(0.12),
                    mono: false
                )
            }
            // Runtime
            if let runtime = details.runtime, runtime > 0 {
                chip(
                    text: formatRuntime(runtime).uppercased(),
                    fg: BrandTheme.textMuted,
                    bg: BrandTheme.surface,
                    mono: true,
                    bordered: true
                )
            }
        }
    }

    private func chip(
        text: String,
        fg: Color,
        bg: Color,
        mono: Bool,
        uppercase: Bool = false,
        bordered: Bool = false
    ) -> some View {
        Text(uppercase ? text.uppercased() : text)
            .font(mono ? BrandFont.mono(11, weight: .semibold) : BrandFont.sans(11, weight: .semibold))
            .tracking(mono ? 1.4 : 0.4)
            .foregroundStyle(fg)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(bg, in: RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(bordered ? BrandTheme.border : .clear, lineWidth: 1)
            )
    }

    private func synopsisSection(overview: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                EyebrowLabel(text: "Synopsis")
                Rectangle().fill(BrandTheme.border).frame(height: 1)
            }
            Text(overview)
                .font(BrandFont.sans(16))
                .foregroundStyle(BrandTheme.text)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 16)
    }

    private func crewSection(directors: [EpisodeCrewMember], writers: [EpisodeCrewMember]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            EyebrowLabel(text: "Crew")
            if !directors.isEmpty {
                crewLine(label: "Directed by", names: directors.map(\.name))
            }
            if !writers.isEmpty {
                crewLine(label: "Written by", names: writers.map(\.name))
            }
        }
        .padding(.horizontal, 16)
    }

    private func crewLine(label: String, names: [String]) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label.uppercased())
                .font(BrandFont.mono(10, weight: .medium))
                .tracking(0.9)
                .foregroundStyle(BrandTheme.textDim)
            Text(names.joined(separator: ", "))
                .font(BrandFont.serif(17, italic: true))
                .foregroundStyle(BrandTheme.text)
        }
    }

    private func castSection(_ cast: [CastMember]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    EyebrowLabel(text: "Cast")
                    Spacer()
                    Text("\(cast.count)")
                        .font(BrandFont.mono(10))
                        .foregroundStyle(BrandTheme.textDim)
                }
                Rectangle().fill(BrandTheme.border).frame(height: 1)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 14) {
                    ForEach(cast) { member in
                        NavigationLink {
                            PersonInfoView(personID: member.id, initialName: member.name)
                        } label: {
                            castCell(member)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
    }

    private func castCell(_ member: CastMember) -> some View {
        VStack(spacing: 6) {
            LazyImage(url: member.profileURL) { state in
                if let image = state.image {
                    image.resizable().scaledToFill()
                } else {
                    ZStack {
                        BrandTheme.surface2
                        Image(systemName: "person.fill").foregroundStyle(BrandTheme.textDim)
                    }
                }
            }
            .frame(width: 72, height: 72)
            .clipShape(Circle())
            .overlay(Circle().stroke(BrandTheme.border, lineWidth: 1))
            VStack(spacing: 1) {
                Text(member.name)
                    .font(BrandFont.sans(12, weight: .semibold))
                    .foregroundStyle(BrandTheme.text)
                    .lineLimit(1)
                if let character = member.character, !character.isEmpty {
                    Text("as \(character)")
                        .font(BrandFont.sans(10.5))
                        .foregroundStyle(BrandTheme.textDim)
                        .lineLimit(1)
                }
            }
            .frame(width: 84)
        }
    }

    private func prevNextNav(details: EpisodeDetails) -> some View {
        VStack(spacing: 14) {
            Rectangle().fill(BrandTheme.border).frame(height: 1)
            HStack(spacing: 12) {
                navCard(direction: .previous, target: prevEpisode, currentSeason: details.seasonNumber)
                navCard(direction: .next, target: nextEpisode, currentSeason: details.seasonNumber)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }

    private enum NavDirection { case previous, next }

    @ViewBuilder
    private func navCard(direction: NavDirection, target: EpisodeDetails?, currentSeason: Int) -> some View {
        let isNext = direction == .next
        if let target {
            NavigationLink {
                EpisodeInfoView(
                    showID: showID,
                    season: target.seasonNumber,
                    episode: target.episodeNumber,
                    initialShowName: showName
                )
            } label: {
                navCardContents(target: target, isNext: isNext, currentSeason: currentSeason)
            }
            .buttonStyle(.plain)
        } else {
            navCardContents(target: nil, isNext: isNext, currentSeason: currentSeason)
                .opacity(0.4)
        }
    }

    private func navCardContents(target: EpisodeDetails?, isNext: Bool, currentSeason: Int) -> some View {
        let label = isNext ? "Next" : "Previous"
        let arrow = isNext ? "arrow.right" : "arrow.left"
        let bg = isNext ? BrandTheme.primarySoft : BrandTheme.surface

        return HStack(spacing: 12) {
            if !isNext {
                Image(systemName: arrow)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(BrandTheme.textDim)
            }
            VStack(alignment: isNext ? .trailing : .leading, spacing: 4) {
                Text((label + (target.map { " · S\(String(format: "%02d", $0.seasonNumber)) E\(String(format: "%02d", $0.episodeNumber))" } ?? "")).uppercased())
                    .font(BrandFont.mono(10, weight: .medium))
                    .tracking(1.0)
                    .foregroundStyle(isNext ? BrandTheme.primaryText : BrandTheme.textDim)
                Text(target?.name ?? "—")
                    .font(BrandFont.serif(15, italic: true))
                    .foregroundStyle(BrandTheme.text)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: isNext ? .trailing : .leading)
            if isNext {
                Image(systemName: arrow)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(BrandTheme.primaryText)
            }
        }
        .padding(14)
        .background(bg, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isNext ? .clear : BrandTheme.border, lineWidth: 1)
        )
    }

    // MARK: - Helpers

    private struct EpisodeTag {
        let label: String
        let fg: Color
        let bg: Color
    }

    private func episodeTag(for details: EpisodeDetails) -> EpisodeTag? {
        if details.episodeNumber == 1 {
            return EpisodeTag(
                label: "Season Premiere",
                fg: BrandTheme.primaryText,
                bg: BrandTheme.primarySoft
            )
        }
        switch details.episodeType {
        case "finale":
            return EpisodeTag(
                label: "Season Finale",
                fg: Color(hex: 0xFBBF24),
                bg: Color(hex: 0xFBBF24).opacity(0.15)
            )
        case "mid_season":
            return EpisodeTag(
                label: "Mid-Season Finale",
                fg: Color(hex: 0xFBBF24),
                bg: Color(hex: 0xFBBF24).opacity(0.15)
            )
        default:
            return nil
        }
    }

    private func formatRuntime(_ mins: Int) -> String {
        let h = mins / 60
        let m = mins % 60
        if h == 0 { return "\(m)m" }
        if m == 0 { return "\(h)h" }
        return "\(h)h \(m)m"
    }

    // MARK: - Networking

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        if showName == nil { showName = initialShowName }

        await loadDetails()
        async let watched: () = loadWatched()
        async let neighbors: () = loadNeighbors()
        async let show: () = loadShowName()
        _ = await (watched, neighbors, show)
    }

    private func loadDetails() async {
        do {
            details = try await env.apiClient.tvEpisodeInfoDecoded(
                id: showID,
                seasonNumber: season,
                episodeNumber: episode
            )
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadShowName() async {
        guard showName == nil else { return }
        if let info = try? await env.apiClient.showInfo(id: showID) {
            showName = info.name
        }
    }

    /// Determine watched state for this specific episode. Uses the existing
    /// per-show watched-episodes endpoint so we don't add a new round trip.
    private func loadWatched() async {
        let rows = (try? await env.apiClient.watchedEpisodesByShow(showID: showID)) ?? []
        isWatched = rows.contains {
            $0.seasonNumber == season && $0.episodeNumber == episode
        }
    }

    /// Best-effort fetch of the previous and next episodes in the same
    /// season. Failures are silently dropped (we just disable the nav card
    /// when no neighbor is available).
    private func loadNeighbors() async {
        async let prev: EpisodeDetails? = (episode > 1)
            ? try? env.apiClient.tvEpisodeInfoDecoded(id: showID, seasonNumber: season, episodeNumber: episode - 1)
            : nil
        async let next: EpisodeDetails? = try? env.apiClient.tvEpisodeInfoDecoded(
            id: showID, seasonNumber: season, episodeNumber: episode + 1
        )
        prevEpisode = await prev
        nextEpisode = await next
    }

    private func toggleWatched() async {
        guard !watchedBusy else { return }
        watchedBusy = true
        defer { watchedBusy = false }
        let wantsWatched = !isWatched
        // Optimistic flip
        isWatched = wantsWatched
        do {
            if wantsWatched {
                _ = try await env.apiClient.watchedEpisodeAdd(
                    showID: showID,
                    seasonNumber: season,
                    episodeNumber: episode
                )
            } else {
                _ = try await env.apiClient.watchedEpisodeRemove(
                    showID: showID,
                    seasonNumber: season,
                    episodeNumber: episode
                )
            }
        } catch {
            // Roll back
            isWatched = !wantsWatched
        }
    }
}

// MARK: - Flow layout (wraps chips to next line when they overflow)

/// Minimal flow layout — used by the episode badge row so the S01·E01,
/// Premiere, rating, runtime, air date chips wrap naturally on narrow
/// devices instead of being clipped by a single HStack.
private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
