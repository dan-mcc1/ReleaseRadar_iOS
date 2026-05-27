import SwiftUI
import NukeUI

/// Detail page for a single TV season. Reached from the breadcrumb on
/// `EpisodeInfoView` and from the Seasons tab on `ShowInfoView`.
/// Mirrors the web app's SeasonInfoPage: breadcrumb + poster hero,
/// progress bar + "Mark season watched" toggle, your-rating + community
/// aggregate, synopsis, and a stacked list of episodes that link out to
/// `EpisodeInfoView`.
struct SeasonInfoView: View {
    let showID: Int
    let seasonNumber: Int
    /// Pre-populated show name so the breadcrumb reads immediately while
    /// the show payload loads in the background.
    var initialShowName: String? = nil

    @Environment(AppEnvironment.self) private var env

    @State private var details: SeasonDetails?
    @State private var showName: String?
    @State private var isLoading = true
    @State private var errorMessage: String?

    /// Set of `<season>-<episode>` keys the viewer has marked watched
    /// for this show. Used to drive the progress bar + the per-episode
    /// checkmarks + "Mark season watched" toggle's active state.
    @State private var watchedKeys: Set<String> = []
    @State private var seasonBusy = false

    @State private var myRating: SeasonRating?
    @State private var aggregate: SeasonRatingAggregate?
    @State private var ratingBusy = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if isLoading && details == nil {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, 64)
                } else if let errorMessage, details == nil {
                    InlineErrorBanner(message: errorMessage) { Task { await loadAll() } }
                        .padding(.horizontal, 16)
                } else if let details {
                    breadcrumb(details: details)
                    hero(details: details)
                    progressRow(details: details)
                    if isSeasonAllWatched(details) {
                        ratingRow
                    }
                    if let overview = details.overview, !overview.isEmpty {
                        synopsisSection(overview: overview)
                    }
                    episodesSection(details: details)
                }
            }
            .padding(.bottom, 32)
        }
        .pageBackground()
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadAll() }
    }

    // MARK: - Sections

    private func breadcrumb(details: SeasonDetails) -> some View {
        HStack(spacing: 6) {
            if let showName {
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
            Text(details.name ?? "Season \(seasonNumber)")
                .foregroundStyle(BrandTheme.text)
        }
        .font(BrandFont.mono(11, weight: .medium))
        .tracking(0.9)
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }

    @ViewBuilder
    private func hero(details: SeasonDetails) -> some View {
        HStack(alignment: .top, spacing: 14) {
            LazyImage(url: TMDBImage.poster(details.posterPath)) { state in
                if let image = state.image {
                    image.resizable().scaledToFill()
                } else {
                    BrandTheme.surface2
                }
            }
            .aspectRatio(2.0 / 3.0, contentMode: .fit)
            .frame(width: 110)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 6) {
                EyebrowLabel(text: "Season \(seasonNumber)")
                Text(details.name ?? "Season \(seasonNumber)")
                    .font(BrandFont.serif(26, italic: true))
                    .foregroundStyle(BrandTheme.text)
                    .lineLimit(3)
                if let dateRange = dateRangeText(details: details) {
                    Text(dateRange)
                        .font(BrandFont.mono(11, weight: .medium))
                        .tracking(0.9)
                        .foregroundStyle(BrandTheme.textDim)
                }
                Text("\(details.episodes.count) EPISODE\(details.episodes.count == 1 ? "" : "S")")
                    .font(BrandFont.mono(10, weight: .medium))
                    .tracking(1.2)
                    .foregroundStyle(BrandTheme.textDim)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
    }

    /// Thin emerald progress bar + count, plus a "Mark season watched"
    /// toggle pinned to the right.
    @ViewBuilder
    private func progressRow(details: SeasonDetails) -> some View {
        let total = details.episodes.count
        let watched = watchedEpisodeCount(details: details)
        let allWatched = total > 0 && watched == total

        if total > 0 {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center, spacing: 10) {
                    ProgressTrack(
                        fraction: Double(watched) / Double(total),
                        height: 6,
                        trackColor: BrandTheme.surface2,
                        fillColor: BrandTheme.primary
                    )
                    .frame(maxWidth: .infinity)

                    Text("\(watched)/\(total)")
                        .font(BrandFont.mono(11, weight: .medium))
                        .foregroundStyle(BrandTheme.textMuted)
                }

                Button {
                    Task { await toggleSeason(allWatched: allWatched) }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: allWatched ? "checkmark.circle.fill" : "checkmark.circle")
                            .font(.system(size: 13, weight: .semibold))
                        Text(allWatched ? "Season watched" : "Mark season watched")
                            .font(BrandFont.sans(13, weight: .semibold))
                    }
                    .foregroundStyle(allWatched ? BrandTheme.bg : BrandTheme.text)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .frame(maxWidth: .infinity)
                    .background(
                        allWatched ? BrandTheme.primary : BrandTheme.surface,
                        in: Capsule()
                    )
                    .overlay(
                        Capsule().stroke(allWatched ? Color.clear : BrandTheme.border, lineWidth: 1)
                    )
                    .opacity(seasonBusy ? 0.5 : 1)
                }
                .buttonStyle(.plain)
                .disabled(seasonBusy)
            }
            .padding(.horizontal, 16)
        }
    }

    /// Your rating (5-star tap selector) + community average. Both share a
    /// single row; either can be empty depending on backend state.
    private var ratingRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                EyebrowLabel(text: "Your rating")
                Spacer()
                if let aggregate, aggregate.count > 0, let avg = aggregate.average {
                    Text("COMMUNITY \(String(format: "%.1f", avg))/5 · \(aggregate.count)")
                        .font(BrandFont.mono(10, weight: .medium))
                        .tracking(1.0)
                        .foregroundStyle(BrandTheme.textDim)
                }
            }

            HStack(spacing: 4) {
                ForEach(1...5, id: \.self) { value in
                    starButton(value: Double(value))
                }
                if myRating != nil {
                    Button {
                        Task { await clearRating() }
                    } label: {
                        Text("Clear")
                            .font(BrandFont.mono(10, weight: .semibold))
                            .tracking(1.0)
                            .foregroundStyle(BrandTheme.textDim)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
                Spacer(minLength: 0)
                if ratingBusy {
                    ProgressView().controlSize(.small)
                }
            }
        }
        .padding(.horizontal, 16)
    }

    private func starButton(value: Double) -> some View {
        let active = (myRating?.rating ?? 0) >= value
        return Button {
            Task { await rate(value) }
        } label: {
            Image(systemName: active ? "star.fill" : "star")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(active ? Color(hex: 0xFBBF24) : BrandTheme.textDim)
                .frame(width: 32, height: 32)
        }
        .buttonStyle(.plain)
        .disabled(ratingBusy)
    }

    private func synopsisSection(overview: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                EyebrowLabel(text: "Synopsis")
                Rectangle().fill(BrandTheme.border).frame(height: 1)
            }
            Text(overview)
                .font(BrandFont.sans(15))
                .foregroundStyle(BrandTheme.text)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 16)
    }

    private func episodesSection(details: SeasonDetails) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    EyebrowLabel(text: "Episodes")
                    Spacer()
                    Text("\(details.episodes.count)")
                        .font(BrandFont.mono(10))
                        .foregroundStyle(BrandTheme.textDim)
                }
                Rectangle().fill(BrandTheme.border).frame(height: 1)
            }
            if details.episodes.isEmpty {
                Text("No episodes available yet.")
                    .font(BrandFont.sans(13))
                    .foregroundStyle(BrandTheme.textMuted)
            } else {
                VStack(spacing: 8) {
                    ForEach(details.episodes) { episode in
                        episodeRow(episode)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private func episodeRow(_ episode: EpisodeDTO) -> some View {
        let s = episode.seasonNumber ?? seasonNumber
        let e = episode.episodeNumber ?? 0
        let watched = watchedKeys.contains("\(s)-\(e)")

        NavigationLink {
            EpisodeInfoView(
                showID: showID,
                season: s,
                episode: e,
                initialShowName: showName
            )
        } label: {
            HStack(alignment: .top, spacing: 12) {
                // Larger episode still so it reads more like the web
                // app's two-column episode row. Both dimensions are set
                // explicitly so the 16:9 ratio is enforced regardless of
                // LazyImage's loading state.
                LazyImage(url: TMDBImage.still(episode.stillPath)) { state in
                    if let image = state.image {
                        image.resizable().scaledToFill()
                    } else {
                        BrandTheme.surface2
                    }
                }
                .frame(width: 120, height: 68)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 8))

                // Right column holds the title block + episode overview,
                // so the still stays a clean rectangle on the left and
                // text flows next to it instead of underneath the whole
                // row.
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("S\(String(format: "%02d", s)) · E\(String(format: "%02d", e))")
                            .font(BrandFont.mono(10, weight: .semibold))
                            .tracking(0.8)
                            .foregroundStyle(BrandTheme.textDim)
                        Spacer(minLength: 8)
                        Image(systemName: watched ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 16))
                            .foregroundStyle(watched ? BrandTheme.primary : BrandTheme.textDim)
                    }
                    Text(episode.name ?? "Episode \(e)")
                        .font(BrandFont.serif(15, italic: true))
                        .foregroundStyle(BrandTheme.text)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    if let overview = episode.overview, !overview.isEmpty {
                        Text(overview)
                            .font(BrandFont.sans(12))
                            .foregroundStyle(BrandTheme.textMuted)
                            .lineLimit(4)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(10)
            .background(BrandTheme.surface, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(BrandTheme.border, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func dateRangeText(details: SeasonDetails) -> String? {
        let start = parseDate(details.airDate)
        let end = details.episodes
            .compactMap { parseDate($0.airDate) }
            .max()
        let fmt: (Date) -> String = { $0.formatted(.dateTime.month(.abbreviated).day().year()) }
        if let start, let end, start != end { return "\(fmt(start)) – \(fmt(end))" }
        if let start { return fmt(start) }
        if let end { return fmt(end) }
        return nil
    }

    private func parseDate(_ raw: String?) -> Date? {
        guard let raw, !raw.isEmpty else { return nil }
        return MediaItem.tmdbDateFormatter.date(from: raw)
    }

    private func watchedEpisodeCount(details: SeasonDetails) -> Int {
        details.episodes.reduce(0) { count, ep in
            let s = ep.seasonNumber ?? seasonNumber
            let e = ep.episodeNumber ?? 0
            return watchedKeys.contains("\(s)-\(e)") ? count + 1 : count
        }
    }

    /// True only when every episode in the season is marked watched.
    /// Drives whether the rating selector appears — we hide it until the
    /// user has actually finished the season.
    private func isSeasonAllWatched(_ details: SeasonDetails) -> Bool {
        let total = details.episodes.count
        return total > 0 && watchedEpisodeCount(details: details) == total
    }

    // MARK: - Networking

    private func loadAll() async {
        isLoading = true
        defer { isLoading = false }
        if showName == nil { showName = initialShowName }

        async let detailsLoad: () = loadDetails()
        async let watchedLoad: () = loadWatched()
        async let myRatingLoad: () = loadMyRating()
        async let aggregateLoad: () = loadAggregate()
        async let showNameLoad: () = loadShowName()
        _ = await (detailsLoad, watchedLoad, myRatingLoad, aggregateLoad, showNameLoad)
    }

    private func loadDetails() async {
        do {
            details = try await env.apiClient.tvSeasonInfoDecoded(id: showID, seasonNumber: seasonNumber)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadWatched() async {
        let rows = (try? await env.apiClient.watchedEpisodesByShow(showID: showID)) ?? []
        watchedKeys = Set(rows.map { "\($0.seasonNumber)-\($0.episodeNumber)" })
    }

    private func loadShowName() async {
        guard showName == nil else { return }
        if let info = try? await env.apiClient.showInfo(id: showID) {
            showName = info.name
        }
    }

    private func loadMyRating() async {
        myRating = (try? await env.apiClient.mySeasonRating(showID: showID, seasonNumber: seasonNumber)) ?? nil
    }

    private func loadAggregate() async {
        aggregate = try? await env.apiClient.seasonRatingAggregate(showID: showID, seasonNumber: seasonNumber)
    }

    private func toggleSeason(allWatched: Bool) async {
        guard !seasonBusy else { return }
        seasonBusy = true
        defer { seasonBusy = false }
        do {
            if allWatched {
                _ = try await env.apiClient.watchedEpisodeRemoveSeason(showID: showID, seasonNumber: seasonNumber)
            } else {
                _ = try await env.apiClient.watchedEpisodeAddSeason(showID: showID, seasonNumber: seasonNumber)
            }
            await loadWatched()
        } catch {
            // No-op; the next refresh will reconcile.
        }
    }

    private func rate(_ value: Double) async {
        guard !ratingBusy else { return }
        ratingBusy = true
        defer { ratingBusy = false }
        do {
            myRating = try await env.apiClient.upsertSeasonRating(
                showID: showID,
                seasonNumber: seasonNumber,
                rating: value
            )
            await loadAggregate()
        } catch {
            // Leave existing state if the server rejects.
        }
    }

    private func clearRating() async {
        guard !ratingBusy else { return }
        ratingBusy = true
        defer { ratingBusy = false }
        do {
            _ = try await env.apiClient.deleteSeasonRating(showID: showID, seasonNumber: seasonNumber)
            myRating = nil
            await loadAggregate()
        } catch {
            // Leave existing state.
        }
    }
}
