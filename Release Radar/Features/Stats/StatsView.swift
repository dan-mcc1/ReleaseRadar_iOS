import SwiftUI

struct StatsView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var viewModel = StatsViewModel()

    /// Palette used to colour the top-genre bars. Cycled by index so a
    /// freshly-loaded list doesn't render five identical emerald bars.
    private static let genreBarColors: [Color] = [
        Color(hex: 0x10B981), // emerald
        Color(hex: 0x34D399), // light emerald
        Color(hex: 0x3B82F6), // blue
        Color(hex: 0xA78BFA), // violet
        Color(hex: 0xF59E0B)  // amber
    ]

    var body: some View {
        @Bindable var vm = viewModel
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                LargeTitleHeader(
                    eyebrow: eyebrowText,
                    title: "Stats",
                    accent: nil
                ) {
                    shareButton
                }

                yearChips
                    .padding(.horizontal, 20)
                    .padding(.bottom, 18)

                content
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
            }
        }
        .pageBackground()
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load(client: env.apiClient) }
        .refreshable { await viewModel.load(client: env.apiClient) }
    }

    // MARK: - State branches

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.top, 32)
        } else if let error = viewModel.errorMessage {
            InlineErrorBanner(message: error) {
                Task { await viewModel.load(client: env.apiClient) }
            }
        } else if let stats = viewModel.watchTimeStats {
            if (stats.totalMinutes ?? 0) == 0 {
                ContentUnavailableView(
                    "No watch time yet",
                    systemImage: "clock",
                    description: Text("Mark titles as watched to see your stats.")
                )
                .padding(.top, 32)
            } else {
                VStack(alignment: .leading, spacing: 28) {
                    heroHours(stats: stats)
                    kpiStrip(stats: stats)
                    if let genres = stats.topGenres, !genres.isEmpty {
                        topGenresSection(genres)
                    }
                    if let platforms = stats.topPlatforms, !platforms.isEmpty {
                        topPlatformsSection(platforms)
                    }
                    streaksRow
                }
            }
        }
    }

    // MARK: - Header

    private var eyebrowText: String {
        guard let year = viewModel.selectedYear else { return "All time" }
        let currentYear = Calendar.current.component(.year, from: Date())
        return year == currentYear ? "\(year) · so far" : "\(year)"
    }

    /// Share button trailing the editorial header. Hands a small text
    /// summary to the system share sheet — the user gets to pick the
    /// channel (Messages / Twitter / etc.).
    private var shareButton: some View {
        ShareLink(item: shareSummary) {
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(BrandTheme.text)
                .frame(width: 38, height: 38)
                .background(BrandTheme.surface, in: RoundedRectangle(cornerRadius: 13))
                .overlay(
                    RoundedRectangle(cornerRadius: 13)
                        .stroke(BrandTheme.border, lineWidth: 1)
                )
        }
    }

    private var shareSummary: String {
        guard let stats = viewModel.watchTimeStats else { return "Release Radar" }
        let total = stats.totalMinutes ?? 0
        let hours = total / 60
        let mins = total % 60
        let period = viewModel.selectedYear.map { "\($0)" } ?? "all time"
        return "I've watched \(hours)h \(mins)m on Release Radar (\(period))."
    }

    // MARK: - Year chips

    private var yearChips: some View {
        @Bindable var vm = viewModel
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(
                    label: "All-time",
                    count: nil,
                    isActive: vm.selectedYear == nil,
                    action: { selectYear(nil) }
                )
                ForEach(viewModel.availableYears, id: \.self) { year in
                    FilterChip(
                        label: String(year),
                        count: nil,
                        isActive: vm.selectedYear == year,
                        action: { selectYear(year) }
                    )
                }
            }
        }
    }

    private func selectYear(_ year: Int?) {
        @Bindable var vm = viewModel
        vm.selectedYear = year
        Task { await viewModel.load(client: env.apiClient) }
    }

    // MARK: - Hero hours

    /// Editorial total watch-time number: serif `218`, dimmed `h`, italic
    /// `12m`. The humor fact (when present) reads as a small italic serif
    /// line below — same voice the calendar uses for its sub-titles.
    private func heroHours(stats: WatchTimeStats) -> some View {
        let total = stats.totalMinutes ?? 0
        let hours = total / 60
        let mins = total % 60

        return VStack(alignment: .leading, spacing: 8) {
            Text("YOU'VE WATCHED")
                .font(BrandFont.mono(10.5, weight: .medium))
                .tracking(1.6)
                .foregroundStyle(BrandTheme.textDim)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(hours)")
                    .font(.system(size: 76, weight: .regular, design: .serif))
                    .foregroundStyle(BrandTheme.text)
                Text("h")
                    .font(.system(size: 56, weight: .regular, design: .serif))
                    .foregroundStyle(BrandTheme.textDim)
                Text("\(mins)m")
                    .font(BrandFont.serif(48, italic: true))
                    .foregroundStyle(BrandTheme.text)
                    .padding(.leading, 8)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.65)

            if let fact = stats.humorFact, !fact.isEmpty {
                Text(fact)
                    .font(BrandFont.serif(15, italic: true))
                    .foregroundStyle(BrandTheme.textMuted)
                    .frame(maxWidth: 290, alignment: .leading)
            }
        }
    }

    // MARK: - KPI strip

    private func kpiStrip(stats: WatchTimeStats) -> some View {
        HStack(spacing: 8) {
            kpiCard(label: "Movies", value: "\(stats.moviesCount ?? 0)")
            kpiCard(label: "Episodes", value: "\(stats.episodesCount ?? 0)")
            kpiCard(label: "Longest binge", value: bingeLabel(stats.longestBinge))
        }
    }

    private func kpiCard(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(BrandFont.mono(9, weight: .medium))
                .tracking(1.2)
                .foregroundStyle(BrandTheme.textDim)
            Text(value)
                .font(BrandFont.serif(24))
                .foregroundStyle(BrandTheme.text)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(BrandTheme.surface, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(BrandTheme.border, lineWidth: 1))
    }

    private func bingeLabel(_ binge: LongestBinge?) -> String {
        guard let minutes = binge?.minutes, minutes > 0 else { return "—" }
        let h = minutes / 60
        let m = minutes % 60
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }

    // MARK: - Top genres / platforms

    private func topGenresSection(_ genres: [StatsBucket]) -> some View {
        sectionHeader(title: "Top ", accent: "genres", caption: "BY MINUTES") {
            bars(items: genres.map { ($0.name, $0.minutes ?? $0.count ?? 0) }, unit: "m")
        }
    }

    private func topPlatformsSection(_ platforms: [PlatformBucket]) -> some View {
        sectionHeader(title: "Top ", accent: "platforms", caption: "BY MINUTES") {
            bars(items: platforms.map { ($0.name, $0.minutes ?? $0.count ?? 0) }, unit: "m")
        }
    }

    /// Serif title with italic emerald accent + small mono caption on the
    /// right. The bar content is supplied as a trailing closure so we can
    /// reuse the header layout for genres + platforms.
    private func sectionHeader<Content: View>(
        title: String,
        accent: String,
        caption: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .lastTextBaseline) {
                (
                    Text(title).font(BrandFont.serif(22)).foregroundColor(BrandTheme.text)
                    + Text(accent).font(BrandFont.serif(22, italic: true)).foregroundColor(BrandTheme.primaryText)
                )
                Spacer()
                Text(caption)
                    .font(BrandFont.mono(10, weight: .medium))
                    .tracking(1.2)
                    .foregroundStyle(BrandTheme.textDim)
            }
            content()
        }
    }

    /// Horizontal bar list: name on the left, mono `Nm` on the right, thin
    /// 4pt track underneath. Each bar's fill cycles through `genreBarColors`
    /// so the list reads as a small chart rather than a row of identical
    /// pills.
    private func bars(items: [(String, Int)], unit: String) -> some View {
        let maxValue = max(items.map(\.1).max() ?? 1, 1)
        return VStack(spacing: 12) {
            ForEach(items.indices, id: \.self) { i in
                let (name, value) = items[i]
                let fraction = Double(value) / Double(maxValue)
                let color = Self.genreBarColors[i % Self.genreBarColors.count]

                VStack(spacing: 4) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(name)
                            .font(BrandFont.sans(13, weight: .medium))
                            .foregroundStyle(BrandTheme.text)
                            .lineLimit(1)
                        Spacer()
                        Text("\(value)\(unit)")
                            .font(BrandFont.mono(11))
                            .foregroundStyle(BrandTheme.textMuted)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(BrandTheme.surface)
                            Capsule()
                                .fill(color)
                                .frame(width: geo.size.width * fraction)
                        }
                    }
                    .frame(height: 4)
                }
            }
        }
    }

    // MARK: - Streaks

    @ViewBuilder
    private var streaksRow: some View {
        if let userStats = viewModel.userStats {
            HStack(spacing: 10) {
                streakCard(
                    label: "Current streak",
                    value: userStats.streak.current,
                    color: Color(hex: 0xF43F5E)
                )
                streakCard(
                    label: "Longest streak",
                    value: userStats.streak.longest,
                    color: BrandTheme.primary
                )
            }
        }
    }

    private func streakCard(label: String, value: Int, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(BrandFont.mono(9, weight: .medium))
                .tracking(1.2)
                .foregroundStyle(BrandTheme.textDim)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(color)
                Text("\(value)")
                    .font(BrandFont.serif(32))
                    .foregroundStyle(BrandTheme.text)
                Text(value == 1 ? "day" : "days")
                    .font(BrandFont.sans(12))
                    .foregroundStyle(BrandTheme.textMuted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(BrandTheme.surface, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(BrandTheme.border, lineWidth: 1))
    }
}

@Observable @MainActor
final class StatsViewModel {
    var selectedYear: Int?
    var watchTimeStats: WatchTimeStats?
    var userStats: UserStats?
    var availableYears: [Int] = []
    var isLoading = false
    var errorMessage: String?

    func load(client: APIClient) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let stats = try await client.userWatchTimeStatsDecoded(year: selectedYear)
            watchTimeStats = stats
            availableYears = stats.availableYears ?? []
            userStats = try? await client.userStatsDecoded()
        } catch is CancellationError {
            // ignore
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
