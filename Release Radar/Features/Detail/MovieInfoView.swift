import SwiftUI
import NukeUI

/// Detail page for a movie. Loads `/movies/{id}/info` and renders hero + tabbed
/// sections mirroring the web app's Overview / Cast / Related layout.
struct MovieInfoView: View {
    let item: MediaItem

    enum Tab: String, CaseIterable, Identifiable {
        case overview, cast, related
        var id: String { rawValue }
        var title: String {
            switch self {
            case .overview: "Overview"
            case .cast: "Cast"
            case .related: "Related"
            }
        }
    }

    @Environment(AppEnvironment.self) private var env
    @Environment(\.openURL) private var openURL
    @State private var details: MovieDetails?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedTab: Tab = .overview

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                hero
                if details != nil {
                    WatchStatusButton(item: item)

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
        .navigationTitle(details?.title ?? item.title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .overlay(loadingOverlay)
        .task { await load() }
    }

    @ViewBuilder
    private func tabContent(details: MovieDetails) -> some View {
        switch selectedTab {
        case .overview: overviewTab(details: details)
        case .cast: castTab(details: details)
        case .related: relatedTab(details: details)
        }
    }

    @ViewBuilder
    private func overviewTab(details: MovieDetails) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            if let overview = details.overview, !overview.isEmpty {
                Text(overview)
                    .font(.body)
                    .padding(.horizontal, 16)
            }
            RatingsRow(
                tmdbAverage: details.voteAverage ?? item.voteAverage,
                imdbID: details.externalIDs?.imdbID,
                type: .movie,
                contentID: details.id
            )
            keyFacts(for: details)
            if let providers = details.watchProviders, !providers.isEmpty {
                whereToWatch(providers: providers)
            }
            VideoGallery(videos: details.videos)
            ReviewsSection(type: .movie, contentID: details.id)
        }
    }

    @ViewBuilder
    private func castTab(details: MovieDetails) -> some View {
        if details.cast.isEmpty {
            ContentUnavailableView("No cast info", systemImage: "person.2.slash")
                .padding(.top, 24)
        } else {
            CastStrip(cast: details.cast)
        }
    }

    @ViewBuilder
    private func relatedTab(details: MovieDetails) -> some View {
        if details.recommendations.isEmpty {
            ContentUnavailableView("No related movies", systemImage: "film.stack")
                .padding(.top, 24)
        } else {
            RecommendationsStrip(items: details.recommendations)
        }
    }

    @ViewBuilder
    private var hero: some View {
        DetailHero(
            backdropURL: details?.backdropURL ?? item.backdropURL,
            posterURL: details?.posterURL ?? item.posterURL,
            title: details?.title ?? item.title,
            subtitle: subtitleLine,
            metaLine: metaLine
        )
    }

    private var subtitleLine: String {
        if let runtime = details?.runtime, runtime > 0 {
            "Film · \(formatRuntime(runtime))"
        } else {
            "Film"
        }
    }

    private var metaLine: String {
        var parts: [String] = []
        if let rating = details?.voteAverage ?? item.voteAverage, rating > 0 {
            parts.append(String(format: "★ %.1f", rating))
        }
        if let date = details?.releaseDate ?? item.releaseDate {
            parts.append(String(Calendar.current.component(.year, from: date)))
        }
        let genres = (details?.genres ?? []).prefix(3).map(\.name)
        if !genres.isEmpty { parts.append(genres.joined(separator: " · ")) }
        if let cert = details?.certification, !cert.isEmpty { parts.append(cert) }
        return parts.joined(separator: "  ·  ")
    }

    @ViewBuilder
    private func keyFacts(for details: MovieDetails) -> some View {
        let facts = buildFacts(for: details)
        if !facts.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                DetailSectionHeader(title: "Key facts")
                KeyFactsCard(facts: facts)
            }
        }
    }

    private func buildFacts(for details: MovieDetails) -> [KeyFactsCard.Fact] {
        var facts: [KeyFactsCard.Fact] = []
        if let status = details.status, !status.isEmpty {
            facts.append(.init(label: "Status", value: status))
        }
        if let date = details.releaseDate {
            facts.append(.init(label: "Released", value: Self.fullDateFormatter.string(from: date)))
        }
        if let runtime = details.runtime, runtime > 0 {
            facts.append(.init(label: "Runtime", value: formatRuntime(runtime)))
        }
        if let budget = details.budget, budget > 0 {
            facts.append(.init(label: "Budget", value: formatLargeAmount(budget)))
        }
        if let revenue = details.revenue, revenue > 0 {
            facts.append(.init(label: "Revenue", value: formatLargeAmount(revenue)))
        }
        return facts
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
                "Couldn't load movie",
                systemImage: "exclamationmark.triangle",
                description: Text(errorMessage)
            )
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            details = try await env.apiClient.movieInfo(id: item.id)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func formatRuntime(_ minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        var parts: [String] = []
        if h > 0 { parts.append("\(h)h") }
        if m > 0 { parts.append("\(m)m") }
        return parts.joined(separator: " ")
    }

    private func formatLargeAmount(_ amount: Int64) -> String {
        let billion: Int64 = 1_000_000_000
        let million: Int64 = 1_000_000
        if amount >= billion {
            return String(format: "$%.2fB", Double(amount) / Double(billion))
        }
        return "$\(amount / million)M"
    }

    private static let fullDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()
}
