import SwiftUI
import NukeUI

/// Detail page for a TV show. Loads `/tv/{id}/full` and renders hero + tabbed
/// sections mirroring the web app's Overview / Seasons / Cast / Related layout.
struct ShowInfoView: View {
    let item: MediaItem

    enum Tab: String, CaseIterable, Identifiable {
        case overview, seasons, cast, related
        var id: String { rawValue }
        var title: String {
            switch self {
            case .overview: "Overview"
            case .seasons: "Seasons"
            case .cast: "Cast"
            case .related: "Related"
            }
        }
    }

    @Environment(AppEnvironment.self) private var env
    @Environment(\.openURL) private var openURL
    @State private var details: ShowDetails?
    @State private var progress: ShowProgress?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedTab: Tab = .overview
    @State private var expandedSeasons: Set<Int> = []
    @State private var seasonCache: [Int: SeasonDetails] = [:]
    @State private var loadingSeasons: Set<Int> = []
    /// `"<season>-<episode>"` keys for episodes the user has marked watched.
    @State private var watchedKeys: Set<String> = []
    @State private var busyKeys: Set<String> = []
    /// User's current rating for each fully-watched season. Populated
    /// lazily — only loaded once a season is detected as fully watched.
    @State private var seasonRatings: [Int: Double] = [:]
    /// Seasons whose rating fetch is in-flight, so the row doesn't
    /// double-fetch on every redraw.
    @State private var loadingSeasonRatings: Set<Int> = []
    /// Seasons whose star tap is currently being persisted. Used to
    /// disable the row while the network call resolves.
    @State private var ratingBusySeasons: Set<Int> = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                hero
                if details != nil {
                    WatchStatusButton(item: item)

                    if let progress, progress.watchedEpisodes > 0, !progress.isCaughtUp {
                        ShowProgressCard(progress: progress)
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Tab.allCases) { tab in
                                FilterChip(
                                    label: tab.title,
                                    count: nil,
                                    isActive: selectedTab == tab,
                                    action: { selectedTab = tab }
                                )
                            }
                        }
                        .padding(.horizontal, 16)
                    }

                    if let details {
                        tabContent(details: details)
                    }
                }
            }
            .padding(.bottom, 32)
        }
        .pageBackground()
        .navigationTitle(details?.name ?? item.title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .overlay(loadingOverlay)
        .task { await load() }
    }

    @ViewBuilder
    private func tabContent(details: ShowDetails) -> some View {
        switch selectedTab {
        case .overview: overviewTab(details: details)
        case .seasons: seasonsTab(details: details)
        case .cast: castTab(details: details)
        case .related: relatedTab(details: details)
        }
    }

    @ViewBuilder
    private func overviewTab(details: ShowDetails) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            if let overview = details.overview, !overview.isEmpty {
                Text(overview)
                    .font(.body)
                    .padding(.horizontal, 16)
            }
            RatingsRow(
                tmdbAverage: details.voteAverage ?? item.voteAverage,
                imdbID: details.externalIDs?.imdbID,
                type: .tv,
                contentID: details.id
            )
            keyFacts(for: details)
            EpisodeRatingChart(showID: details.id)
            if let providers = details.watchProviders, !providers.isEmpty {
                whereToWatch(providers: providers)
            }
            VideoGallery(videos: details.videos)
            ReviewsSection(type: .tv, contentID: details.id)
        }
    }

    @ViewBuilder
    private func seasonsTab(details: ShowDetails) -> some View {
        let filtered = details.seasons.filter { $0.seasonNumber > 0 || $0.episodeCount ?? 0 > 0 }
        if filtered.isEmpty {
            ContentUnavailableView("No seasons info", systemImage: "tv.slash")
                .padding(.top, 24)
        } else {
            VStack(spacing: 8) {
                ForEach(filtered) { season in
                    seasonRow(season)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    @ViewBuilder
    private func castTab(details: ShowDetails) -> some View {
        if details.cast.isEmpty {
            ContentUnavailableView("No cast info", systemImage: "person.2.slash")
                .padding(.top, 24)
        } else {
            CastStrip(cast: details.cast)
        }
    }

    @ViewBuilder
    private func relatedTab(details: ShowDetails) -> some View {
        if details.recommendations.isEmpty {
            ContentUnavailableView("No related shows", systemImage: "tv.slash")
                .padding(.top, 24)
        } else {
            RecommendationsStrip(items: details.recommendations)
        }
    }

    @ViewBuilder
    private func seasonRow(_ season: ShowSeason) -> some View {
        let isExpanded = expandedSeasons.contains(season.seasonNumber)
        let fullyWatched = isSeasonFullyWatched(season)
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 8) {
                // Tapping the poster + title block navigates to the
                // standalone SeasonInfoView. Replaces the previous
                // expand-on-tap behavior so users can drill into the
                // dedicated season page (with rating, full episode
                // descriptions, etc.).
                NavigationLink {
                    SeasonInfoView(
                        showID: item.id,
                        seasonNumber: season.seasonNumber,
                        initialShowName: details?.name ?? item.title
                    )
                } label: {
                    HStack(alignment: .top, spacing: 12) {
                        LazyImage(url: season.posterURL) { state in
                            if let image = state.image {
                                image.resizable().scaledToFill()
                            } else {
                                Color.secondary.opacity(0.15)
                            }
                        }
                        .frame(width: 56, height: 84)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(season.name)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                                .lineLimit(2)
                            if let count = season.episodeCount, count > 0 {
                                Text("\(count) episode\(count == 1 ? "" : "s")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if let range = seasonDateRange(season) {
                                Text(range)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                // Right column: watched + dropdown buttons on top,
                // tap-to-rate stars (when fully watched) directly below
                // so they sit beside the poster rather than the full
                // width of the card.
                VStack(alignment: .trailing, spacing: 6) {
                    HStack(spacing: 0) {
                        Button {
                            Task { await toggleSeason(season) }
                        } label: {
                            Image(systemName: fullyWatched ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                                .foregroundStyle(fullyWatched ? Color.brandPrimary : Color.brandTextSecondary)
                                .frame(width: 32, height: 32)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(busyKeys.contains("season-\(season.seasonNumber)"))

                        // Compact dropdown chevron — toggles the inline
                        // episode list for the season without leaving
                        // the show page.
                        Button {
                            toggle(season: season)
                        } label: {
                            Image(systemName: "chevron.down")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.brandTextSecondary)
                                .rotationEffect(.degrees(isExpanded ? 180 : 0))
                                .animation(.easeInOut(duration: 0.15), value: isExpanded)
                                .frame(width: 32, height: 32)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }

                    if fullyWatched {
                        seasonStars(season: season)
                            .onAppear { ensureSeasonRatingLoaded(season.seasonNumber) }
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, 10)

            if isExpanded {
                Divider()
                    .padding(.top, 10)
                episodesBody(seasonNumber: season.seasonNumber)
                    .padding(.horizontal, 10)
                    .padding(.bottom, 10)
            } else {
                Color.clear.frame(height: 10)
            }
        }
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.secondary.opacity(0.1)))
    }

    @ViewBuilder
    private func episodesBody(seasonNumber: Int) -> some View {
        if loadingSeasons.contains(seasonNumber) {
            HStack {
                Spacer()
                ProgressView()
                Spacer()
            }
            .padding(.vertical, 16)
        } else if let cached = seasonCache[seasonNumber] {
            if cached.episodes.isEmpty {
                Text("No episodes found.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 12)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(cached.episodes) { episode in
                        episodeRow(episode)
                    }
                }
                .padding(.top, 8)
            }
        } else {
            Color.clear.frame(height: 1)
        }
    }

    @ViewBuilder
    private func episodeRow(_ episode: EpisodeDTO) -> some View {
        let s = episode.seasonNumber ?? 0
        let e = episode.episodeNumber ?? 0
        let watched = isWatched(season: s, episode: e)
        HStack(alignment: .top, spacing: 10) {
            // Tapping the still + text block pushes the per-episode
            // detail page. The watched toggle stays outside the link so
            // its tap doesn't trigger navigation.
            NavigationLink {
                EpisodeInfoView(
                    showID: item.id,
                    season: s,
                    episode: e,
                    initialShowName: details?.name ?? item.title
                )
            } label: {
                HStack(alignment: .top, spacing: 10) {
                    LazyImage(url: TMDBImage.still(episode.stillPath)) { state in
                        if let image = state.image {
                            image.resizable().scaledToFill()
                        } else {
                            Color.secondary.opacity(0.15)
                        }
                    }
                    .frame(width: 88, height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            if let ep = episode.episodeNumber {
                                Text("E\(ep)")
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundStyle(Color.brandPrimary)
                            }
                            Text(episode.name ?? "—")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                        }
                        if let air = episode.airDate, !air.isEmpty {
                            // Re-format `YYYY-MM-DD` from the backend into a
                            // human-readable `Month DD, YYYY` via the shared
                            // medium-style formatter.
                            Text(formattedEpisodeDate(air) ?? air)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        if let overview = episode.overview, !overview.isEmpty {
                            Text(overview)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(s == 0 || e == 0)

            Button {
                Task { await toggleEpisode(season: s, episode: e) }
            } label: {
                Image(systemName: watched ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(watched ? Color.brandPrimary : Color.brandTextSecondary)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(s == 0 || e == 0 || busyKeys.contains(key(season: s, episode: e)))
        }
    }

    private func toggle(season: ShowSeason) {
        let n = season.seasonNumber
        if expandedSeasons.contains(n) {
            expandedSeasons.remove(n)
            return
        }
        expandedSeasons.insert(n)
        guard seasonCache[n] == nil, !loadingSeasons.contains(n) else { return }
        loadingSeasons.insert(n)
        Task {
            defer { loadingSeasons.remove(n) }
            do {
                let details = try await env.apiClient.tvSeasonInfoDecoded(id: item.id, seasonNumber: n)
                seasonCache[n] = details
            } catch {
                // On failure, collapse so the user can retry.
                expandedSeasons.remove(n)
            }
        }
    }

    @ViewBuilder
    private var hero: some View {
        DetailHero(
            backdropURL: details?.backdropURL ?? item.backdropURL,
            posterURL: details?.posterURL ?? item.posterURL,
            title: details?.name ?? item.title,
            subtitle: subtitleLine,
            metaLine: metaLine
        )
    }

    private var subtitleLine: String {
        guard let seasons = details?.numberOfSeasons, seasons > 0 else { return "Series" }
        return "Series · \(seasons) Season\(seasons == 1 ? "" : "s")"
    }

    private var metaLine: String {
        var parts: [String] = []
        if let rating = details?.voteAverage ?? item.voteAverage, rating > 0 {
            parts.append(String(format: "★ %.1f", rating))
        }
        if let range = yearRange { parts.append(range) }
        let genres = (details?.genres ?? []).prefix(3).map(\.name)
        if !genres.isEmpty { parts.append(genres.joined(separator: " · ")) }
        if let cert = details?.certification, !cert.isEmpty { parts.append(cert) }
        return parts.joined(separator: "  ·  ")
    }

    private var yearRange: String? {
        guard let first = details?.firstAirDate else { return nil }
        let startYear = Calendar.current.component(.year, from: first)
        let ongoing = details?.status == "Returning Series" || details?.inProduction == true
        if ongoing { return "\(startYear) – present" }
        if let last = details?.lastAirDate {
            let endYear = Calendar.current.component(.year, from: last)
            return endYear == startYear ? "\(startYear)" : "\(startYear) – \(endYear)"
        }
        return "\(startYear)"
    }

    @ViewBuilder
    private func keyFacts(for details: ShowDetails) -> some View {
        let facts = buildFacts(for: details)
        if !facts.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                DetailSectionHeader(title: "Key facts")
                KeyFactsCard(facts: facts)
            }
        }
    }

    private func buildFacts(for details: ShowDetails) -> [KeyFactsCard.Fact] {
        var facts: [KeyFactsCard.Fact] = []
        if let status = details.status, !status.isEmpty {
            facts.append(.init(label: "Status", value: status))
        }
        if let first = details.firstAirDate {
            facts.append(.init(label: "First aired", value: Self.fullDateFormatter.string(from: first)))
        }
        if let last = details.lastAirDate, details.inProduction != true {
            facts.append(.init(label: "Last aired", value: Self.fullDateFormatter.string(from: last)))
        }
        if let seasons = details.numberOfSeasons, seasons > 0 {
            facts.append(.init(label: "Seasons", value: "\(seasons)"))
        }
        if let episodes = details.numberOfEpisodes, episodes > 0 {
            facts.append(.init(label: "Episodes", value: "\(episodes)"))
        }
        if let gap = averageGapBetweenSeasons(details.seasons) {
            facts.append(.init(label: "Avg between seasons", value: gap))
        }
        return facts
    }

    /// Mean gap between consecutive season premieres, expressed as a
    /// human-readable string ("11 months", "1 yr 2 mo"). Returns nil
    /// unless at least two non-special seasons have a known `airDate`.
    private func averageGapBetweenSeasons(_ seasons: [ShowSeason]) -> String? {
        let dates = seasons
            .filter { $0.seasonNumber > 0 }
            .compactMap { $0.airDate }
            .sorted()
        guard dates.count >= 2 else { return nil }

        var totalDays: Double = 0
        for i in 1..<dates.count {
            totalDays += dates[i].timeIntervalSince(dates[i - 1]) / 86_400
        }
        let avgDays = totalDays / Double(dates.count - 1)
        return formatGap(days: avgDays)
    }

    private func formatGap(days: Double) -> String {
        let totalDays = Int(days.rounded())
        if totalDays < 14 { return "\(totalDays) day\(totalDays == 1 ? "" : "s")" }
        if totalDays < 60 {
            let weeks = Int((days / 7).rounded())
            return "\(weeks) wk\(weeks == 1 ? "" : "s")"
        }
        let months = Int((days / 30.4375).rounded())
        if months < 18 { return "\(months) mo" }
        let years = months / 12
        let remMonths = months % 12
        if remMonths == 0 { return "\(years) yr\(years == 1 ? "" : "s")" }
        return "\(years) yr\(years == 1 ? "" : "s") \(remMonths) mo"
    }

    @ViewBuilder
    private func whereToWatch(providers: WatchProvidersUS) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            DetailSectionHeader(title: "Where to watch")
            VStack(alignment: .leading, spacing: 12) {
                if !providers.flatrate.isEmpty {
                    ProvidersRow(title: "Stream", providers: providers.flatrate)
                }
                if !providers.rent.isEmpty {
                    ProvidersRow(title: "Rent", providers: providers.rent)
                }
                if !providers.buy.isEmpty {
                    ProvidersRow(title: "Buy", providers: providers.buy)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    @ViewBuilder
    private var loadingOverlay: some View {
        if isLoading && details == nil {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.opacity(0.001))
        } else if let errorMessage, details == nil {
            ContentUnavailableView(
                "Couldn't load show",
                systemImage: "exclamationmark.triangle",
                description: Text(errorMessage)
            )
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            details = try await env.apiClient.showInfo(id: item.id)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        await loadWatchedEpisodes()
        await loadProgress()
    }

    /// Loads binge progress for this show. Best-effort — silently swallows
    /// errors (e.g. show not on watchlist, server issue) since the card
    /// is purely additive and hides itself when no progress is available.
    private func loadProgress() async {
        progress = try? await env.apiClient.watchlistProgressDecoded(showID: item.id)
    }

    private func loadWatchedEpisodes() async {
        do {
            let rows = try await env.apiClient.watchedEpisodesByShow(showID: item.id)
            watchedKeys = Set(rows.map(\.key))
        } catch {
            // Silent — toggle still works, the icons just default to unwatched.
        }
    }

    private func key(season: Int, episode: Int) -> String {
        "\(season)-\(episode)"
    }

    private func isWatched(season: Int, episode: Int) -> Bool {
        watchedKeys.contains(key(season: season, episode: episode))
    }

    private func isSeasonFullyWatched(_ season: ShowSeason) -> Bool {
        // Prefer the cached episode list if we have one; otherwise fall back to
        // the season's declared `episodeCount` and count from the watched set.
        if let cached = seasonCache[season.seasonNumber], !cached.episodes.isEmpty {
            return cached.episodes.allSatisfy { ep in
                guard let n = ep.episodeNumber else { return false }
                return isWatched(season: season.seasonNumber, episode: n)
            }
        }
        guard let total = season.episodeCount, total > 0 else { return false }
        let watchedInSeason = watchedKeys.filter { $0.hasPrefix("\(season.seasonNumber)-") }.count
        return watchedInSeason >= total
    }

    private func toggleEpisode(season: Int, episode: Int) async {
        let k = key(season: season, episode: episode)
        guard !busyKeys.contains(k) else { return }
        busyKeys.insert(k)
        defer { busyKeys.remove(k) }
        let wasWatched = watchedKeys.contains(k)
        if wasWatched { watchedKeys.remove(k) } else { watchedKeys.insert(k) }
        do {
            if wasWatched {
                _ = try await env.apiClient.watchedEpisodeRemove(showID: item.id, seasonNumber: season, episodeNumber: episode)
            } else {
                _ = try await env.apiClient.watchedEpisodeAdd(showID: item.id, seasonNumber: season, episodeNumber: episode)
            }
        } catch {
            if wasWatched { watchedKeys.insert(k) } else { watchedKeys.remove(k) }
        }
    }

    private func toggleSeason(_ season: ShowSeason) async {
        let n = season.seasonNumber
        let key = "season-\(n)"
        guard !busyKeys.contains(key) else { return }
        busyKeys.insert(key)
        defer { busyKeys.remove(key) }
        let wasFullyWatched = isSeasonFullyWatched(season)
        do {
            if wasFullyWatched {
                _ = try await env.apiClient.watchedEpisodeRemoveSeason(showID: item.id, seasonNumber: n)
                // Drop every watched key for this season.
                watchedKeys = watchedKeys.filter { !$0.hasPrefix("\(n)-") }
            } else {
                _ = try await env.apiClient.watchedEpisodeAddSeason(showID: item.id, seasonNumber: n)
                // If we know the episode list, mark them all watched. Otherwise
                // re-fetch the watched set to reflect what the backend stored.
                if let cached = seasonCache[n] {
                    for ep in cached.episodes {
                        if let num = ep.episodeNumber {
                            watchedKeys.insert(self.key(season: n, episode: num))
                        }
                    }
                } else {
                    await loadWatchedEpisodes()
                }
            }
        } catch {
            // Resync from server on failure.
            await loadWatchedEpisodes()
        }
    }

    private static let fullDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    /// Parse the backend's `YYYY-MM-DD` air-date string and re-render it
    /// in the medium `Month DD, YYYY` format. Returns nil for malformed
    /// inputs so callers can fall back to the raw string.
    private func formattedEpisodeDate(_ raw: String) -> String? {
        guard let date = MediaItem.tmdbDateFormatter.date(from: raw) else { return nil }
        return Self.fullDateFormatter.string(from: date)
    }

    // MARK: - Season rating

    /// 5 tap-to-rate stars laid out horizontally below the watched/dropdown row.
    /// Tapping a star upserts the rating; tapping the currently-selected
    /// star clears it.
    @ViewBuilder
    private func seasonStars(season: ShowSeason) -> some View {
        let current = seasonRatings[season.seasonNumber] ?? 0
        let busy = ratingBusySeasons.contains(season.seasonNumber)

        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { value in
                Button {
                    Task { await rateSeason(season.seasonNumber, value: Double(value)) }
                } label: {
                    Image(systemName: current >= Double(value) ? "star.fill" : "star")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(current >= Double(value) ? Color(hex: 0xFBBF24) : Color.brandTextSecondary)
                        .frame(width: 16, height: 18)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(busy)
            }
        }
    }

    private func ensureSeasonRatingLoaded(_ seasonNumber: Int) {
        guard seasonRatings[seasonNumber] == nil,
              !loadingSeasonRatings.contains(seasonNumber) else { return }
        loadingSeasonRatings.insert(seasonNumber)
        Task {
            defer { loadingSeasonRatings.remove(seasonNumber) }
            let rating = (try? await env.apiClient.mySeasonRating(
                showID: item.id,
                seasonNumber: seasonNumber
            ))?.rating
            // Use 0 as a sentinel for "fetched, none set" so we don't
            // re-fetch on every render. Real ratings start at 1.
            seasonRatings[seasonNumber] = rating ?? 0
        }
    }

    /// Tap-to-rate: a tap on the currently-selected value clears it,
    /// any other tap upserts to that value.
    private func rateSeason(_ seasonNumber: Int, value: Double) async {
        guard !ratingBusySeasons.contains(seasonNumber) else { return }
        ratingBusySeasons.insert(seasonNumber)
        defer { ratingBusySeasons.remove(seasonNumber) }

        let current = seasonRatings[seasonNumber] ?? 0
        do {
            if current == value {
                _ = try await env.apiClient.deleteSeasonRating(
                    showID: item.id,
                    seasonNumber: seasonNumber
                )
                seasonRatings[seasonNumber] = 0
            } else {
                let updated = try await env.apiClient.upsertSeasonRating(
                    showID: item.id,
                    seasonNumber: seasonNumber,
                    rating: value
                )
                seasonRatings[seasonNumber] = updated.rating
            }
        } catch {
            // Leave existing state if the server rejected.
        }
    }

    /// `Sep 17, 2026 – Dec 10, 2026` when both dates are known and
    /// distinct; just the start date when the season hasn't finished
    /// airing (or is a single-episode special); nil when neither end
    /// of the range is known.
    private func seasonDateRange(_ season: ShowSeason) -> String? {
        let fmt = Self.fullDateFormatter
        switch (season.airDate, season.endDate) {
        case let (start?, end?) where start != end:
            return "\(fmt.string(from: start)) – \(fmt.string(from: end))"
        case let (start?, _):
            return fmt.string(from: start)
        case let (nil, end?):
            return fmt.string(from: end)
        default:
            return nil
        }
    }
}
