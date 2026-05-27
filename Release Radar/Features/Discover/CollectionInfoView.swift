import SwiftUI
import NukeUI

/// Detail page for a TMDb collection (i.e. a film franchise). Renders the
/// hero/poster header, optional user-progress card, favorite toggle, list
/// of films, and a small stats panel sourced from `/collections/{id}/stats`.
struct CollectionInfoView: View {
    let collectionID: Int
    @Environment(AppEnvironment.self) private var env
    @State private var collection: TMDBCollection?
    @State private var status: CollectionStatus?
    @State private var stats: CollectionStats?
    @State private var isFavorite: Bool = false
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if isLoading {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, 64)
                } else if let error = errorMessage {
                    InlineErrorBanner(message: error) { Task { await load() } }
                        .padding(.horizontal, 16)
                } else if let collection {
                    header(for: collection)

                    actionRow

                    if let status {
                        progressCard(status: status)
                            .padding(.horizontal, 16)
                    }

                    if let overview = collection.overview, !overview.isEmpty {
                        Text(overview)
                            .font(BrandFont.sans(14))
                            .foregroundStyle(BrandTheme.text.opacity(0.85))
                            .padding(.horizontal, 16)
                    }

                    if let parts = collection.parts, !parts.isEmpty {
                        partsGrid(parts: parts)
                    }

                    if let stats {
                        statsCard(stats: stats)
                            .padding(.horizontal, 16)
                    }
                }
            }
            .padding(.vertical, 16)
        }
        .pageBackground()
        .navigationTitle(collection?.name ?? "Collection")
        .task { await load() }
    }

    // MARK: - Header

    private func header(for collection: TMDBCollection) -> some View {
        ZStack(alignment: .bottomLeading) {
            LazyImage(url: TMDBImage.backdrop(collection.backdropPath, size: "w1280")) { state in
                if let image = state.image { image.resizable().scaledToFill() }
                else { Color.brandSurfaceElevated }
            }
            .aspectRatio(16.0 / 9.0, contentMode: .fill)
            .frame(maxWidth: .infinity)
            .clipped()

            LinearGradient(
                colors: [Color.black.opacity(0.9), .clear],
                startPoint: .bottom,
                endPoint: .top
            )

            HStack(alignment: .bottom, spacing: 12) {
                LazyImage(url: TMDBImage.poster(collection.posterPath)) { state in
                    if let image = state.image { image.resizable().scaledToFill() }
                    else { Color.brandSurfaceElevated }
                }
                .frame(width: 80, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                Text(collection.name)
                    .font(BrandFont.serif(24))
                    .foregroundStyle(.white)
                    .lineLimit(3)
                    .shadow(color: .black.opacity(0.5), radius: 12, x: 0, y: 1)
                Spacer()
            }
            .padding(16)
        }
    }

    // MARK: - Action row

    private var actionRow: some View {
        HStack(spacing: 10) {
            Button {
                Task { await toggleFavorite() }
            } label: {
                Label(
                    isFavorite ? "Favorited" : "Favorite",
                    systemImage: isFavorite ? "heart.fill" : "heart"
                )
                .font(BrandFont.sans(13, weight: .semibold))
                .foregroundStyle(isFavorite ? .white : BrandTheme.primaryText)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(
                    isFavorite ? BrandTheme.primary : BrandTheme.primarySoft,
                    in: Capsule()
                )
            }
            .buttonStyle(.plain)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Progress card

    private func progressCard(status: CollectionStatus) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Your progress")
                    .font(BrandFont.mono(10, weight: .semibold))
                    .tracking(1.0)
                    .foregroundStyle(BrandTheme.textMuted)
                Spacer()
                if status.finished {
                    Label("Caught up", systemImage: "checkmark.circle.fill")
                        .font(BrandFont.mono(10, weight: .semibold))
                        .foregroundStyle(BrandTheme.primaryText)
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(status.watchedParts)")
                    .font(BrandFont.serif(32))
                    .foregroundStyle(BrandTheme.text)
                Text("of \(status.releasedParts) released")
                    .font(BrandFont.sans(13))
                    .foregroundStyle(BrandTheme.textMuted)
                Spacer()
                if status.totalParts > status.releasedParts {
                    Text("\(status.totalParts - status.releasedParts) unreleased")
                        .font(BrandFont.mono(10, weight: .medium))
                        .foregroundStyle(BrandTheme.textDim)
                }
            }

            ProgressTrack(fraction: status.fraction, height: 6)
        }
        .padding(14)
        .background(BrandTheme.surface, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(BrandTheme.border, lineWidth: 1))
    }

    // MARK: - Parts grid

    private func partsGrid(parts: [MediaItem]) -> some View {
        let sorted = parts.sorted {
            ($0.releaseDate ?? .distantFuture) < ($1.releaseDate ?? .distantFuture)
        }
        // No outer NavigationLink — the part cell wires its own inner links
        // around the poster and title so the mini watch/watchlist buttons stay
        // tappable instead of being swallowed by a parent link.
        return VStack(alignment: .leading, spacing: 10) {
            SectionTitle("Films in this", accent: "collection", trailing: "\(parts.count) titles")
                .padding(.horizontal, 16)
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 12, alignment: .top),
                    GridItem(.flexible(), spacing: 12, alignment: .top),
                    GridItem(.flexible(), spacing: 12, alignment: .top)
                ],
                spacing: 16
            ) {
                ForEach(sorted) { item in
                    partCell(for: item)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    @ViewBuilder
    private func partCell(for item: MediaItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            // Poster, with mini watch/watchlist buttons floating bottom-right.
            // Wrapping the link around just the poster keeps the buttons tap-
            // routable instead of being eaten by the surrounding NavigationLink.
            ZStack(alignment: .topLeading) {
                Color.clear
                    .aspectRatio(2.0 / 3.0, contentMode: .fit)
                    .overlay(
                        NavigationLink {
                            MediaDetailView(item: item)
                        } label: {
                            LazyImage(url: TMDBImage.poster(item.posterPath)) { state in
                                if let image = state.image { image.resizable().scaledToFill() }
                                else { BrandTheme.surface2 }
                            }
                        }
                        .buttonStyle(.plain)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        MiniWatchButtons(type: .movie, id: item.id)
                    }
                }
                .padding(6)
            }
            NavigationLink {
                MediaDetailView(item: item)
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(BrandFont.sans(12.5, weight: .semibold))
                        .foregroundStyle(BrandTheme.text)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    HStack(spacing: 6) {
                        if let date = item.releaseDate {
                            Text(date.formatted(.dateTime.year()))
                                .font(BrandFont.mono(10, weight: .medium))
                                .foregroundStyle(BrandTheme.textDim)
                        }
                        if let rating = item.voteAverage, rating > 0 {
                            Text(String(format: "★ %.1f", rating))
                                .font(BrandFont.mono(10, weight: .medium))
                                .foregroundStyle(BrandTheme.primaryText)
                        }
                    }
                }
            }
            .buttonStyle(.plain)
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    // MARK: - Stats

    private func statsCard(stats: CollectionStats) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle("Franchise", accent: "stats")

            statRow(label: "Average rating", value: format(stats.avgRating))
            statRow(label: "Highest rating", value: format(stats.highestRating))
            statRow(label: "Total runtime", value: stats.totalRuntime.map { formatRuntime(minutes: $0) } ?? "—")
            statRow(label: "Total box office", value: format(money: stats.totalRevenue))
            statRow(label: "Total budget", value: format(money: stats.totalBudget))
            if let min = stats.minYear, let max = stats.maxYear {
                statRow(label: "Year range", value: min == max ? "\(min)" : "\(min)–\(max)")
            }
        }
        .padding(14)
        .background(BrandTheme.surface, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(BrandTheme.border, lineWidth: 1))
    }

    private func statRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(BrandFont.sans(13))
                .foregroundStyle(BrandTheme.textMuted)
            Spacer()
            Text(value)
                .font(BrandFont.mono(12, weight: .medium))
                .foregroundStyle(BrandTheme.text)
        }
    }

    private func format(_ value: Double?) -> String {
        guard let value, value > 0 else { return "—" }
        return String(format: "%.1f", value)
    }

    private func format(money value: Double?) -> String {
        guard let value, value > 0 else { return "—" }
        if value >= 1_000_000_000 { return String(format: "$%.1fB", value / 1_000_000_000) }
        if value >= 1_000_000 { return String(format: "$%.1fM", value / 1_000_000) }
        if value >= 1_000 { return String(format: "$%.1fK", value / 1_000) }
        return "$\(Int(value))"
    }

    private func formatRuntime(minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }

    // MARK: - Loading + actions

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        // Collection detail is the only required call — if it fails the page
        // can't render. Status / stats / favorite state are best-effort
        // (status 404s for collections that aren't in the local DB yet).
        do {
            collection = try await env.apiClient.collectionDecoded(id: collectionID)
        } catch {
            errorMessage = error.localizedDescription
            return
        }
        status = try? await env.apiClient.collectionsStatus(id: collectionID)
        stats = try? await env.apiClient.collectionsStats(id: collectionID)
        let favResponse = try? await env.apiClient.favoriteStatusCollection(id: collectionID)
        isFavorite = favResponse?.favorited ?? false
    }

    private func toggleFavorite() async {
        // Optimistic flip — roll back on failure.
        let newValue = !isFavorite
        isFavorite = newValue
        do {
            if newValue {
                _ = try await env.apiClient.favoriteAddCollection(id: collectionID)
            } else {
                _ = try await env.apiClient.favoriteRemoveCollection(id: collectionID)
            }
        } catch {
            isFavorite = !newValue
        }
    }
}
