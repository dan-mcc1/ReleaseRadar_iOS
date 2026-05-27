import SwiftUI
import NukeUI
import SafariServices

/// Reusable building blocks used by both `MovieInfoView` and `ShowInfoView`.

struct DetailHero: View {
    let backdropURL: URL?
    let posterURL: URL?
    let title: String
    let subtitle: String
    let metaLine: String?

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Backdrop. `scaledToFill` makes the loaded image overflow the
            // intended frame; reading the viewport width via GeometryReader and
            // clipping at this level prevents the parent ScrollView from
            // adopting the image's natural width (the "page got really wide
            // once it loaded" bug).
            GeometryReader { geo in
                LazyImage(url: backdropURL) { state in
                    if let image = state.image {
                        image.resizable().scaledToFill()
                    } else {
                        Color.secondary.opacity(0.2)
                    }
                }
                .frame(width: geo.size.width, height: 320)
                .clipped()
            }
            .frame(height: 320)

            LinearGradient(
                colors: [.black.opacity(0.0), .black.opacity(0.55), .black.opacity(0.85)],
                startPoint: .top,
                endPoint: .bottom
            )

            HStack(alignment: .bottom, spacing: 14) {
                LazyImage(url: posterURL) { state in
                    if let image = state.image {
                        image.resizable().scaledToFill()
                    } else {
                        Color.secondary.opacity(0.2)
                    }
                }
                .frame(width: 96, height: 144)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(.white.opacity(0.15), lineWidth: 1))
                .shadow(radius: 8)

                VStack(alignment: .leading, spacing: 8) {
                    Text(subtitle.uppercased())
                        .font(BrandFont.mono(10, weight: .semibold))
                        .tracking(1.6)
                        .foregroundStyle(.white.opacity(0.78))
                        .lineLimit(1)
                    Text(title)
                        .font(BrandFont.serif(28))
                        .foregroundStyle(.white)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                        .shadow(color: .black.opacity(0.5), radius: 12, x: 0, y: 1)
                    if let metaLine, !metaLine.isEmpty {
                        Text(metaLine)
                            .font(BrandFont.sans(12))
                            .foregroundStyle(.white.opacity(0.85))
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 320)
        .clipped()
    }
}

struct DetailSectionHeader: View {
    let title: String
    let accent: String?

    init(title: String, accent: String? = nil) {
        self.title = title
        self.accent = accent
    }

    var body: some View {
        SectionTitle(title, accent: accent)
            .padding(.horizontal, 16)
    }
}

struct KeyFactsCard: View {
    struct Fact: Identifiable {
        let id = UUID()
        let label: String
        let value: String
    }

    let facts: [Fact]

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(facts) { fact in
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text(fact.label.uppercased())
                            .font(BrandFont.mono(10, weight: .medium))
                            .tracking(1.4)
                            .foregroundStyle(BrandTheme.textDim)
                            .frame(width: 100, alignment: .leading)
                        Text(fact.value)
                            .font(BrandFont.sans(14, weight: .medium))
                            .foregroundStyle(BrandTheme.text)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(BrandTheme.surface, in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14).stroke(BrandTheme.border, lineWidth: 1)
        )
        .padding(.horizontal, 16)
    }
}

struct ProvidersRow: View {
    let title: String
    let providers: [WatchProvider]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(providers) { provider in
                        ProviderBadge(provider: provider)
                    }
                }
            }
        }
    }
}

struct ProviderBadge: View {
    let provider: WatchProvider

    var body: some View {
        LazyImage(url: provider.logoURL) { state in
            if let image = state.image {
                image.resizable().scaledToFit()
            } else {
                Color.secondary.opacity(0.15)
            }
        }
        .frame(width: 46, height: 46)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(.white.opacity(0.1), lineWidth: 1))
    }
}

struct CastStrip: View {
    let cast: [CastMember]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 12) {
                ForEach(cast.prefix(20)) { member in
                    NavigationLink {
                        PersonInfoView(personID: member.id, initialName: member.name)
                    } label: {
                        VStack(spacing: 6) {
                            LazyImage(url: member.profileURL) { state in
                                if let image = state.image {
                                    image.resizable().scaledToFill()
                                } else {
                                    ZStack {
                                        Color.secondary.opacity(0.2)
                                        Image(systemName: "person.fill")
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .frame(width: 80, height: 80)
                            .clipShape(Circle())
                            VStack(spacing: 2) {
                                Text(member.name)
                                    .font(.caption.weight(.semibold))
                                    .lineLimit(1)
                                    .foregroundStyle(.primary)
                                if let character = member.character, !character.isEmpty {
                                    Text(character)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                            .frame(width: 84)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }
}

/// Ratings row shown on the movie/show overview tab — TMDb, IMDb, Rotten Tomatoes,
/// Metacritic (from OMDB) and Release Radar users' aggregate rating.
/// Loads external scores + aggregate lazily; hides itself entirely if nothing is
/// available.
struct RatingsRow: View {
    let tmdbAverage: Double?
    let imdbID: String?
    let type: ContentType
    let contentID: Int

    @Environment(AppEnvironment.self) private var env
    @State private var external: ExternalScores?
    @State private var aggregate: ReviewAggregate?

    var body: some View {
        let hasTMDb = (tmdbAverage ?? 0) > 0
        let hasExternal = external?.isEmpty == false
        let hasAggregate = (aggregate?.average ?? 0) > 0

        if hasTMDb || hasExternal || hasAggregate {
            VStack(alignment: .leading, spacing: 8) {
                DetailSectionHeader(title: "Ratings")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        if let v = tmdbAverage, v > 0 {
                            RatingBadge(label: "TMDb", value: String(format: "%.1f/10", v), tint: Color.brandPrimary)
                        }
                        if let imdb = external?.imdb {
                            RatingBadge(label: "IMDb", value: imdb, tint: imdbTint(imdb))
                        }
                        if let rt = external?.rottenTomatoes {
                            RatingBadge(label: "Rotten Tomatoes", value: rt, tint: rtTint(rt))
                        }
                        if let mc = external?.metacritic {
                            RatingBadge(label: "Metacritic", value: mc.replacingOccurrences(of: "/100", with: ""), tint: .orange)
                        }
                        if let agg = aggregate, let avg = agg.average, avg > 0 {
                            RatingBadge(
                                label: "Users (\(agg.count))",
                                value: String(format: "%.1f ★", avg),
                                tint: .pink
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            .task { await load() }
        }
    }

    private func load() async {
        async let externalTask: ExternalScores? = {
            guard let id = imdbID, !id.isEmpty else { return nil }
            return try? await env.apiClient.reviewsExternalScoresDecoded(imdbID: id)
        }()
        async let aggregateTask: ReviewAggregate? = try? await env.apiClient.reviewsAggregate(type: type, id: contentID)
        external = await externalTask
        aggregate = await aggregateTask
    }

    private func imdbTint(_ raw: String) -> Color {
        let value = Double(raw.split(separator: "/").first.map(String.init) ?? raw) ?? 0
        return value >= 6.0 ? .green : .red
    }

    private func rtTint(_ raw: String) -> Color {
        let digits = raw.compactMap { $0.isNumber ? $0 : nil }
        let value = Int(String(digits)) ?? 0
        return value >= 60 ? .green : .red
    }
}

struct RatingBadge: View {
    let label: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label.uppercased())
                .font(BrandFont.mono(9.5, weight: .medium))
                .tracking(1.4)
                .foregroundStyle(BrandTheme.textDim)
            Text(value)
                .font(BrandFont.sans(14, weight: .semibold))
                .foregroundStyle(BrandTheme.text)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(BrandTheme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(tint.opacity(0.55), lineWidth: 2)
        )
    }
}

// MARK: - Show progress card
//
// Mirrors the web app's BingePlanWidget — shown on the Show Info page when
// the user has watched some (but not all) episodes. Hides itself when the
// user is caught up.

struct ShowProgressCard: View {
    let progress: ShowProgress
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "clock")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(BrandTheme.primaryText)
                    Text("Progress")
                        .font(BrandFont.sans(13, weight: .semibold))
                        .foregroundStyle(BrandTheme.text)
                    Spacer(minLength: 8)
                    Text("\(progress.watchedEpisodes) / \(progress.totalEpisodes)")
                        .font(BrandFont.mono(11, weight: .medium))
                        .foregroundStyle(BrandTheme.textMuted)
                    Text("\(Int((progress.fraction * 100).rounded()))%")
                        .font(BrandFont.mono(11, weight: .medium))
                        .foregroundStyle(BrandTheme.textMuted)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(BrandTheme.textMuted)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 14) {
                    ProgressTrack(fraction: progress.fraction, height: 8)
                    statsRow
                }
                .padding(.top, 14)
            } else {
                ProgressTrack(fraction: progress.fraction, height: 4)
                    .padding(.top, 10)
            }
        }
        .padding(16)
        .background(BrandTheme.surface, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(BrandTheme.border, lineWidth: 1))
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private var statsRow: some View {
        let cells = buildStats()
        if !cells.isEmpty {
            HStack(alignment: .top, spacing: 16) {
                ForEach(Array(cells.enumerated()), id: \.offset) { _, cell in
                    stat(label: cell.label, value: cell.value, accent: cell.accent)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private struct StatCell {
        let label: String
        let value: String
        let accent: Bool
    }

    private func buildStats() -> [StatCell] {
        var result: [StatCell] = []
        result.append(.init(label: "Time left", value: formatMinutes(progress.remainingMinutes), accent: false))
        result.append(.init(label: "Eps left", value: "\(progress.remainingEpisodes)", accent: false))
        if let pace = progress.epsPerWeekRecent, pace > 0 {
            result.append(.init(label: "Your pace", value: "\(Int(pace)) ep/wk", accent: false))
        }
        if let est = progress.completionEstimate, !est.isEmpty {
            result.append(.init(label: "At this pace", value: est, accent: true))
        }
        return result
    }

    private func stat(label: String, value: String, accent: Bool) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label.uppercased())
                .font(BrandFont.mono(9.5, weight: .medium))
                .tracking(1.2)
                .foregroundStyle(BrandTheme.textDim)
            Text(value)
                .font(BrandFont.sans(13, weight: .semibold))
                .foregroundStyle(accent ? BrandTheme.primaryText : BrandTheme.text)
        }
    }

    private func formatMinutes(_ mins: Int) -> String {
        let h = mins / 60
        let m = mins % 60
        if h == 0 { return "\(m)m" }
        if m == 0 { return "\(h)h" }
        return "\(h)h \(m)m"
    }
}

// MARK: - Episode ratings heat-map
//
// Two-axis grid: seasons down the left, episode numbers across the top.
// Each cell is colored by TMDb vote average (red ➝ orange ➝ yellow ➝
// lime ➝ emerald). Tapping a cell shows the episode's name in a small
// caption below the grid. Hides itself entirely if no episodes have a
// non-zero vote average.

struct EpisodeRatingChart: View {
    let showID: Int

    @Environment(AppEnvironment.self) private var env
    @State private var seasons: [SeasonRatings] = []
    @State private var hasLoaded = false
    @State private var selected: (season: Int, episode: Int, name: String)?

    private static let cellSize: CGFloat = 32
    private static let cellSpacing: CGFloat = 2
    private static let labelWidth: CGFloat = 28

    var body: some View {
        if hasLoaded, !validSeasons.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                DetailSectionHeader(title: "Episode", accent: "ratings")
                grid
                    .padding(.horizontal, 16)
                if let sel = selected {
                    Text("S\(sel.season) · E\(sel.episode) — \(sel.name)")
                        .font(BrandFont.sans(12))
                        .foregroundStyle(BrandTheme.textMuted)
                        .padding(.horizontal, 16)
                        .lineLimit(1)
                }
            }
            .task { await load() }
        } else {
            // Render an empty view but kick off the fetch so it can appear
            // once data arrives.
            Color.clear
                .frame(height: 0)
                .task { await load() }
        }
    }

    private var validSeasons: [SeasonRatings] {
        seasons.filter { season in
            season.episodes.contains { ($0.voteAverage ?? 0) > 0 }
        }
    }

    private var maxEpisodes: Int {
        validSeasons.map(\.episodes.count).max() ?? 0
    }

    private var grid: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            VStack(alignment: .leading, spacing: Self.cellSpacing) {
                episodeNumberHeader
                ForEach(validSeasons) { season in
                    seasonRow(season)
                }
            }
            .padding(10)
            .background(BrandTheme.surface, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(BrandTheme.border, lineWidth: 1))
        }
    }

    private var episodeNumberHeader: some View {
        HStack(spacing: Self.cellSpacing) {
            Color.clear.frame(width: Self.labelWidth, height: 14)
            ForEach(1...max(maxEpisodes, 1), id: \.self) { ep in
                Text("\(ep)")
                    .font(BrandFont.mono(9, weight: .medium))
                    .foregroundStyle(BrandTheme.textDim)
                    .frame(width: Self.cellSize, height: 14)
            }
        }
    }

    private func seasonRow(_ season: SeasonRatings) -> some View {
        let byNumber = Dictionary(uniqueKeysWithValues: season.episodes.map { ($0.episodeNumber, $0) })
        return HStack(spacing: Self.cellSpacing) {
            Text("S\(season.seasonNumber)")
                .font(BrandFont.mono(11, weight: .semibold))
                .foregroundStyle(BrandTheme.textMuted)
                .frame(width: Self.labelWidth, alignment: .trailing)
            ForEach(1...max(maxEpisodes, 1), id: \.self) { epNum in
                let ep = byNumber[epNum]
                cell(season: season.seasonNumber, episodeNumber: epNum, episode: ep)
            }
        }
    }

    private func cell(season: Int, episodeNumber: Int, episode: EpisodeRatingPoint?) -> some View {
        let rating = episode?.voteAverage ?? 0
        let hasRating = rating > 0
        return Button {
            guard let ep = episode, hasRating else { return }
            selected = (season, episodeNumber, ep.name ?? "")
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(hasRating ? Self.ratingColor(rating) : BrandTheme.surface2)
                    .opacity(episode == nil ? 0.15 : 1.0)
                if hasRating {
                    Text(String(format: "%.1f", rating))
                        .font(BrandFont.mono(9, weight: .bold))
                        .foregroundStyle(.white.opacity(0.95))
                }
            }
            .frame(width: Self.cellSize, height: Self.cellSize)
        }
        .buttonStyle(.plain)
        .disabled(!hasRating)
    }

    private func load() async {
        guard !hasLoaded else { return }
        seasons = (try? await env.apiClient.tvEpisodeRatingsDecoded(showID: showID)) ?? []
        hasLoaded = true
    }

    /// Web app's `ratingToColor` — interpolated red → orange → yellow →
    /// lime → emerald gradient anchored at 0/4/5/6/7/8/10.
    private static func ratingColor(_ raw: Double) -> Color {
        let r = max(0, min(10, raw))
        // (anchor, R, G, B)
        let stops: [(Double, Double, Double, Double)] = [
            (0, 127, 29, 29),    // red-900
            (4, 185, 28, 28),    // red-700
            (5, 234, 88, 12),    // orange-600
            (6, 202, 138, 4),    // yellow-600
            (7, 101, 163, 13),   // lime-600
            (8, 16, 185, 129),   // emerald-500
            (10, 6, 95, 70)      // emerald-900
        ]
        var lo = stops[0]
        var hi = stops.last!
        for i in 0..<(stops.count - 1) where r >= stops[i].0 && r <= stops[i + 1].0 {
            lo = stops[i]
            hi = stops[i + 1]
            break
        }
        let t = (r - lo.0) / max(0.001, hi.0 - lo.0)
        let red = (lo.1 + t * (hi.1 - lo.1)) / 255.0
        let grn = (lo.2 + t * (hi.2 - lo.2)) / 255.0
        let blu = (lo.3 + t * (hi.3 - lo.3)) / 255.0
        return Color(.sRGB, red: red, green: grn, blue: blu, opacity: 1)
    }
}

// MARK: - Recommend to a friend
//
// A secondary action button on the show/movie detail page that opens a
// sheet listing the user's friends. The user can tap one or more friends,
// optionally type a message, and fire `recommendationsSend` for each
// selected recipient — landing in their inbox.

struct RecommendButton: View {
    let item: MediaItem
    @State private var showingSheet = false

    var body: some View {
        Button { showingSheet = true } label: {
            HStack(spacing: 8) {
                Image(systemName: "paperplane")
                    .font(.system(size: 14, weight: .semibold))
                Text("Recommend to a friend")
                    .font(BrandFont.sans(14, weight: .semibold))
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .opacity(0.5)
            }
            .foregroundStyle(BrandTheme.primaryText)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(BrandTheme.primarySoft, in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(BrandTheme.primary.opacity(0.25), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .sheet(isPresented: $showingSheet) {
            RecommendSheet(item: item)
                .presentationDetents([.medium, .large])
        }
    }
}

// MARK: - Videos gallery
//
// Horizontal scroll strip of YouTube videos attached to a movie or show —
// trailers, teasers, clips, featurettes, behind-the-scenes, bloopers.
// Mirrors the web app's two-tier strip (trailers/teasers first, then
// everything else by priority). Tapping a card opens the YouTube page in
// an in-app Safari sheet — same approach as the legacy TrailerButton.

struct VideoGallery: View {
    let videos: [MediaVideo]
    @State private var selected: MediaVideo?

    private static let typePriority: [String: Int] = [
        "Trailer": 0,
        "Teaser": 1,
        "Clip": 2,
        "Featurette": 3,
        "Behind the Scenes": 4,
        "Bloopers": 5,
    ]

    private var sortedYouTube: [MediaVideo] {
        videos
            .filter { $0.site.lowercased() == "youtube" }
            .sorted { a, b in
                (Self.typePriority[a.type] ?? 99) < (Self.typePriority[b.type] ?? 99)
            }
    }

    var body: some View {
        let yt = sortedYouTube
        if !yt.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                DetailSectionHeader(title: "Videos")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(yt) { video in
                            Button { selected = video } label: {
                                videoCard(video)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            .sheet(item: $selected) { video in
                if let url = URL(string: "https://www.youtube.com/watch?v=\(video.key)") {
                    VideoSafariView(url: url).ignoresSafeArea()
                }
            }
        }
    }

    private func videoCard(_ video: MediaVideo) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .topLeading) {
                LazyImage(url: URL(string: "https://img.youtube.com/vi/\(video.key)/mqdefault.jpg")) { state in
                    if let image = state.image {
                        image.resizable().scaledToFill()
                    } else {
                        BrandTheme.surface2
                    }
                }
                .frame(width: 208, height: 117)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 12))

                LinearGradient(
                    colors: [Color.black.opacity(0.45), .clear, .clear, Color.black.opacity(0.25)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(width: 208, height: 117)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .allowsHitTesting(false)

                Text(video.type.uppercased())
                    .font(BrandFont.mono(9, weight: .semibold))
                    .tracking(0.8)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.black.opacity(0.65), in: Capsule())
                    .padding(8)

                Image(systemName: "play.circle.fill")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(.white.opacity(0.92))
                    .shadow(color: .black.opacity(0.45), radius: 4)
                    .frame(width: 208, height: 117)
                    .allowsHitTesting(false)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(BrandTheme.border, lineWidth: 1)
            )

            Text(video.name)
                .font(BrandFont.sans(12, weight: .medium))
                .foregroundStyle(BrandTheme.text)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(width: 208, alignment: .leading)
        }
    }
}

/// Compact paperplane variant for use as a navigation-bar trailing item.
/// Same RecommendSheet, no full-width row taking up vertical space.
struct RecommendToolbarButton: View {
    let item: MediaItem
    @State private var showingSheet = false

    var body: some View {
        Button { showingSheet = true } label: {
            Image(systemName: "paperplane")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(BrandTheme.primaryText)
        }
        .sheet(isPresented: $showingSheet) {
            RecommendSheet(item: item)
                .presentationDetents([.medium, .large])
        }
    }
}

private struct RecommendSheet: View {
    let item: MediaItem
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    @State private var friends: [FriendEntry] = []
    @State private var selected: Set<String> = []     // usernames
    @State private var sent: Set<String> = []         // confirmed sent
    @State private var message: String = ""
    @State private var isLoading = true
    @State private var isSending = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            content
                .background(BrandTheme.bg.ignoresSafeArea())
                .navigationTitle("Recommend")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(sendButtonLabel) { Task { await sendRecommendations() } }
                            .fontWeight(.semibold)
                            .disabled(selected.isEmpty || isSending)
                    }
                }
                .task { await loadFriends() }
        }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading && friends.isEmpty {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if friends.isEmpty {
            ContentUnavailableView(
                "No friends yet",
                systemImage: "person.2",
                description: Text("Add some friends and you'll be able to recommend titles to them.")
            )
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if let error = errorMessage {
                        InlineErrorBanner(message: error) { errorMessage = nil }
                            .padding(.horizontal, 16)
                    }
                    EyebrowLabel(text: "Send to")
                        .padding(.horizontal, 20)
                    friendsList
                    EyebrowLabel(text: "Message (optional)")
                        .padding(.horizontal, 20)
                        .padding(.top, 6)
                    TextField("\"You'll love this\"", text: $message, axis: .vertical)
                        .lineLimit(2...6)
                        .font(BrandFont.sans(14))
                        .foregroundStyle(BrandTheme.text)
                        .padding(12)
                        .background(BrandTheme.surface, in: RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(BrandTheme.border, lineWidth: 1))
                        .padding(.horizontal, 16)
                }
                .padding(.vertical, 16)
            }
        }
    }

    private var friendsList: some View {
        VStack(spacing: 6) {
            ForEach(friends) { friend in
                friendRow(friend)
            }
        }
        .padding(.horizontal, 16)
    }

    private func friendRow(_ friend: FriendEntry) -> some View {
        let username = friend.username ?? ""
        let isSelected = selected.contains(username)
        let wasSent = sent.contains(username)
        return Button {
            guard !wasSent, !username.isEmpty else { return }
            if isSelected {
                selected.remove(username)
            } else {
                selected.insert(username)
            }
        } label: {
            HStack(spacing: 12) {
                AvatarView(username: friend.username, avatarKey: friend.avatarKey, size: 38)
                VStack(alignment: .leading, spacing: 1) {
                    Text(friend.username ?? "—")
                        .font(BrandFont.sans(14, weight: .semibold))
                        .foregroundStyle(BrandTheme.text)
                    if let name = friend.username {
                        Text("@\(name)")
                            .font(BrandFont.mono(11))
                            .foregroundStyle(BrandTheme.textDim)
                    }
                }
                Spacer()
                checkmarkIndicator(isSelected: isSelected, wasSent: wasSent)
            }
            .padding(12)
            .background(
                (isSelected || wasSent ? BrandTheme.primarySoft : BrandTheme.surface),
                in: RoundedRectangle(cornerRadius: 12)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12).stroke(
                    isSelected || wasSent ? .clear : BrandTheme.border,
                    lineWidth: 1
                )
            )
        }
        .buttonStyle(.plain)
        .disabled(wasSent)
        .opacity(wasSent ? 0.7 : 1)
    }

    private func checkmarkIndicator(isSelected: Bool, wasSent: Bool) -> some View {
        let fill: Color = wasSent ? BrandTheme.primary : (isSelected ? BrandTheme.primary : BrandTheme.surface2)
        let symbol = wasSent ? "checkmark.circle.fill" : (isSelected ? "checkmark" : "plus")
        let fg: Color = (isSelected || wasSent) ? BrandTheme.bg : BrandTheme.textMuted
        return Image(systemName: symbol)
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(fg)
            .frame(width: 26, height: 26)
            .background(Circle().fill(fill))
    }

    // MARK: - Networking

    private func loadFriends() async {
        isLoading = true
        defer { isLoading = false }
        let raw = (try? await env.apiClient.friendsListDecoded()) ?? []
        friends = raw.filter { $0.username != nil && !($0.username ?? "").isEmpty }
    }

    private func sendRecommendations() async {
        guard !selected.isEmpty, !isSending else { return }
        isSending = true
        defer { isSending = false }
        errorMessage = nil
        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        var failedAny = false
        for username in selected {
            do {
                _ = try await env.apiClient.recommendationsSend(
                    recipientUsername: username,
                    type: item.contentType,
                    id: item.id,
                    title: item.title,
                    posterPath: item.posterPath,
                    message: trimmedMessage.isEmpty ? nil : trimmedMessage
                )
                sent.insert(username)
            } catch {
                failedAny = true
            }
        }
        if failedAny {
            errorMessage = "Some recommendations couldn't be sent. Try again."
        }
        // Clear selection for anything we successfully sent.
        selected.subtract(sent)
        // Auto-dismiss if everything went through and nothing's left.
        if !failedAny, selected.isEmpty {
            try? await Task.sleep(for: .milliseconds(450))
            dismiss()
        }
    }

    private var sendButtonLabel: String {
        if isSending { return "Sending…" }
        if selected.isEmpty { return "Send" }
        return "Send (\(selected.count))"
    }
}

// MARK: - Reviews section
//
// Inline list of community reviews for a given show/movie, plus a write/
// edit composer for the signed-in user. Wraps the existing /reviews API
// (`client.reviews`, `reviewCreateOrUpdate`, `reviewDelete`,
// `reviewToggleLike`). Auto-hides until the first fetch resolves.

struct ReviewsSection: View {
    let type: ContentType
    let contentID: Int

    @Environment(\.openURL) private var openURL
    @Environment(AppEnvironment.self) private var env
    @State private var reviews: [ReviewEntry] = []
    @State private var currentUsername: String?
    @State private var hasLoaded = false
    @State private var isComposing = false
    @State private var composerText: String = ""
    @State private var isSubmitting = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            DetailSectionHeader(title: "Reviews", accent: reviews.isEmpty ? nil : "from the community")
            VStack(spacing: 10) {
                composerCard
                ForEach(reviews) { review in
                    reviewCard(review)
                }
                if reviews.isEmpty && hasLoaded {
                    Text("Be the first to write a review.")
                        .font(BrandFont.sans(13).italic())
                        .foregroundStyle(BrandTheme.textDim)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 12)
                }
            }
            .padding(.horizontal, 16)
        }
        .task { await load() }
    }

    // MARK: - Composer

    /// "Write / edit your review" card. Collapses to a CTA pill when not
    /// composing, expands to a multiline TextEditor with Save / Cancel
    /// when the user taps in. If the user already has a review, the
    /// composer starts pre-populated and the CTA reads "Edit".
    private var composerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            if isComposing {
                TextField("What did you think?", text: $composerText, axis: .vertical)
                    .lineLimit(3...8)
                    .font(BrandFont.sans(14))
                    .foregroundStyle(BrandTheme.text)
                    .padding(12)
                    .background(BrandTheme.surface2, in: RoundedRectangle(cornerRadius: 10))
                HStack {
                    Spacer()
                    Button("Cancel") { cancelCompose() }
                        .buttonStyle(.plain)
                        .foregroundStyle(BrandTheme.textMuted)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                    Button {
                        Task { await submit() }
                    } label: {
                        Text(isSubmitting ? "Saving…" : "Save review")
                            .font(BrandFont.sans(13, weight: .semibold))
                            .foregroundStyle(BrandTheme.bg)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(BrandTheme.primary, in: RoundedRectangle(cornerRadius: 9))
                    }
                    .buttonStyle(.plain)
                    .disabled(isSubmitting || composerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .opacity(composerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.4 : 1)
                }
            } else {
                Button {
                    if let existing = ownReview {
                        composerText = existing.reviewText
                    }
                    isComposing = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: ownReview == nil ? "square.and.pencil" : "pencil")
                            .font(.system(size: 13, weight: .semibold))
                        Text(ownReview == nil ? "Write a review" : "Edit your review")
                            .font(BrandFont.sans(13, weight: .semibold))
                    }
                    .foregroundStyle(BrandTheme.primaryText)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(BrandTheme.primarySoft, in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(BrandTheme.surface, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(BrandTheme.border, lineWidth: 1))
    }

    private var ownReview: ReviewEntry? {
        guard let me = currentUsername else { return nil }
        return reviews.first { $0.username.caseInsensitiveCompare(me) == .orderedSame }
    }

    // MARK: - Review row

    private func reviewCard(_ review: ReviewEntry) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                AvatarView(username: review.username, size: 32)
                VStack(alignment: .leading, spacing: 1) {
                    Text(review.username)
                        .font(BrandFont.sans(13, weight: .semibold))
                        .foregroundStyle(BrandTheme.text)
                    if let when = TimeAgo.format(review.createdAt) {
                        Text(when)
                            .font(BrandFont.mono(10))
                            .foregroundStyle(BrandTheme.textDim)
                    }
                }
                Spacer()
                if isOwnReview(review) {
                    Menu {
                        Button("Edit") {
                            composerText = review.reviewText
                            isComposing = true
                        }
                        Button("Delete", role: .destructive) {
                            Task { await delete() }
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(BrandTheme.textMuted)
                            .frame(width: 30, height: 30)
                    }
                }
            }
            Text(review.reviewText)
                .font(BrandFont.sans(14))
                .foregroundStyle(BrandTheme.text)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer()
                likeButton(review)
            }
        }
        .padding(12)
        .background(BrandTheme.surface, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(BrandTheme.border, lineWidth: 1))
    }

    private func likeButton(_ review: ReviewEntry) -> some View {
        Button {
            Task { await toggleLike(review) }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: review.userHasLiked ? "heart.fill" : "heart")
                    .font(.system(size: 12, weight: .semibold))
                Text("\(review.likeCount)")
                    .font(BrandFont.mono(11, weight: .medium))
            }
            .foregroundStyle(review.userHasLiked ? BrandTheme.primaryText : BrandTheme.textMuted)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                (review.userHasLiked ? BrandTheme.primarySoft : BrandTheme.surface2),
                in: Capsule()
            )
        }
        .buttonStyle(.plain)
        .disabled(isOwnReview(review))
        .opacity(isOwnReview(review) ? 0.5 : 1)
    }

    private func isOwnReview(_ review: ReviewEntry) -> Bool {
        guard let me = currentUsername else { return false }
        return review.username.caseInsensitiveCompare(me) == .orderedSame
    }

    // MARK: - Networking

    private func load() async {
        async let reviewsTask: [ReviewEntry] = (try? await env.apiClient.reviews(type: type, id: contentID)) ?? []
        async let meTask: ProfileSummary? = try? await env.apiClient.userProfileSummaryDecoded()
        let fetched = await reviewsTask
        let me = await meTask
        reviews = fetched
        if let username = me?.user.username { currentUsername = username }
        hasLoaded = true
    }

    private func submit() async {
        let text = composerText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isSubmitting else { return }
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            let saved = try await env.apiClient.reviewCreateOrUpdate(type: type, id: contentID, text: text)
            // Replace or insert at the top
            if let idx = reviews.firstIndex(where: { $0.id == saved.id }) {
                reviews[idx] = saved
            } else {
                reviews.insert(saved, at: 0)
            }
            isComposing = false
            composerText = ""
        } catch {
            // Leave composer open with the text so the user can retry.
        }
    }

    private func delete() async {
        do {
            _ = try await env.apiClient.reviewDelete(type: type, id: contentID)
            if let me = currentUsername {
                reviews.removeAll { $0.username.caseInsensitiveCompare(me) == .orderedSame }
            }
            composerText = ""
            isComposing = false
        } catch {
            // No-op; user can retry.
        }
    }

    private func toggleLike(_ review: ReviewEntry) async {
        // Optimistic flip
        guard let idx = reviews.firstIndex(where: { $0.id == review.id }) else { return }
        let before = reviews[idx]
        reviews[idx] = ReviewEntry(
            id: before.id,
            userId: before.userId,
            username: before.username,
            reviewText: before.reviewText,
            rating: before.rating,
            createdAt: before.createdAt,
            updatedAt: before.updatedAt,
            likeCount: before.likeCount + (before.userHasLiked ? -1 : 1),
            userHasLiked: !before.userHasLiked
        )
        do {
            let response = try await env.apiClient.reviewToggleLike(reviewID: review.id)
            // Reconcile with server's true count
            if let i = reviews.firstIndex(where: { $0.id == review.id }) {
                reviews[i] = ReviewEntry(
                    id: before.id,
                    userId: before.userId,
                    username: before.username,
                    reviewText: before.reviewText,
                    rating: before.rating,
                    createdAt: before.createdAt,
                    updatedAt: before.updatedAt,
                    likeCount: response.likeCount,
                    userHasLiked: response.liked
                )
            }
        } catch {
            reviews[idx] = before
        }
    }

    private func cancelCompose() {
        isComposing = false
        composerText = ""
    }
}

struct RecommendationsStrip: View {
    let items: [MediaItem]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 12) {
                ForEach(items.prefix(20)) { item in
                    NavigationLink {
                        MediaDetailView(item: item)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            LazyImage(url: item.posterURL) { state in
                                if let image = state.image {
                                    image.resizable().scaledToFill()
                                } else {
                                    Color.secondary.opacity(0.2)
                                }
                            }
                            .frame(width: 110, height: 165)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            Text(item.title)
                                .font(.caption.weight(.semibold))
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                                .foregroundStyle(.primary)
                                .frame(width: 110, alignment: .leading)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }
}

/// In-app Safari wrapper used by `VideoGallery` to open a YouTube video
/// page inside a sheet. Other files (`YouTubePlayerView`, `NewsView`)
/// already declare their own file-private SafariView wrappers — keeping
/// this one file-scoped avoids module-level redeclaration conflicts.
private struct VideoSafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = false
        let vc = SFSafariViewController(url: url, configuration: config)
        vc.preferredControlTintColor = UIColor(named: "AccentColor")
        return vc
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
