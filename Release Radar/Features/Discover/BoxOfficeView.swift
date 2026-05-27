import SwiftUI
import NukeUI

struct BoxOfficeView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var viewModel = BoxOfficeViewModel()

    var body: some View {
        @Bindable var vm = viewModel
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                LargeTitleHeader(
                    eyebrow: "Receipts",
                    title: "Box",
                    accent: "office"
                ) { EmptyView() }

                HStack(spacing: 8) {
                    FilterChip(
                        label: "Yearly",
                        count: nil,
                        isActive: vm.mode == .yearly,
                        action: { selectMode(.yearly) }
                    )
                    FilterChip(
                        label: "Monthly",
                        count: nil,
                        isActive: vm.mode == .monthly,
                        action: { selectMode(.monthly) }
                    )
                    FilterChip(
                        label: "All-time",
                        count: nil,
                        isActive: vm.mode == .allTime,
                        action: { selectMode(.allTime) }
                    )
                    Spacer()
                }
                .padding(.horizontal, 16)

                if vm.mode != .allTime {
                    yearPicker
                }
                if vm.mode == .monthly {
                    monthPicker
                }

                if viewModel.isLoading {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, 32)
                } else if let error = viewModel.errorMessage {
                    InlineErrorBanner(message: error) { Task { await viewModel.load(client: env.apiClient) } }
                        .padding(.horizontal, 16)
                } else if viewModel.entries.isEmpty {
                    ContentUnavailableView("No data", systemImage: "chart.bar", description: Text("Try a different period."))
                } else {
                    if let hero = viewModel.entries.first {
                        NavigationLink {
                            MediaDetailView(item: mediaItem(for: hero))
                        } label: {
                            heroCard(entry: hero)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 16)
                    }
                    LazyVStack(spacing: 0) {
                        ForEach(Array(viewModel.entries.enumerated()), id: \.element.id) { _, entry in
                            NavigationLink {
                                MediaDetailView(item: mediaItem(for: entry))
                            } label: {
                                entryRow(entry)
                            }
                            .buttonStyle(.plain)
                            Divider().background(Color.brandBorder)
                        }
                    }
                    .padding(.horizontal, 16)

                    if vm.mode == .allTime {
                        HStack {
                            Button("Previous") { Task { await viewModel.previousPage(client: env.apiClient) } }
                                .disabled(vm.page <= 1)
                            Spacer()
                            Text("Page \(vm.page)")
                                .font(.caption)
                                .foregroundStyle(Color.brandTextSecondary)
                            Spacer()
                            Button("Next") { Task { await viewModel.nextPage(client: env.apiClient) } }
                                .disabled(vm.page >= 20)
                        }
                        .buttonStyle(.bordered)
                        .padding(.horizontal, 16)
                    }
                }
            }
            .padding(.bottom, 16)
        }
        .pageBackground()
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load(client: env.apiClient) }
    }

    private func selectMode(_ mode: BoxOfficeViewModel.Mode) {
        @Bindable var vm = viewModel
        vm.mode = mode
        vm.page = 1
        Task { await viewModel.load(client: env.apiClient) }
    }

    @ViewBuilder
    private var yearPicker: some View {
        @Bindable var vm = viewModel
        let chipYears = viewModel.recentYearOptions
        let menuYears = viewModel.earlierYearOptions
        let selectedIsInChips = chipYears.contains(vm.year)
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(chipYears, id: \.self) { y in
                    FilterChip(
                        label: String(y),
                        count: nil,
                        isActive: vm.year == y,
                        action: {
                            vm.year = y
                            Task { await viewModel.load(client: env.apiClient) }
                        }
                    )
                }

                if !menuYears.isEmpty {
                    Menu {
                        ForEach(menuYears, id: \.self) { y in
                            Button(String(y)) {
                                vm.year = y
                                Task { await viewModel.load(client: env.apiClient) }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(selectedIsInChips ? "Earlier" : String(vm.year))
                                .font(BrandFont.sans(12.5, weight: .medium))
                            Image(systemName: "chevron.down")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .padding(.horizontal, 13)
                        .padding(.vertical, 7)
                        .foregroundStyle(selectedIsInChips ? BrandTheme.text : BrandTheme.bg)
                        .background(
                            Capsule().fill(selectedIsInChips ? BrandTheme.surface : BrandTheme.text)
                        )
                        .overlay(
                            Capsule().stroke(selectedIsInChips ? BrandTheme.border : .clear, lineWidth: 1)
                        )
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    @ViewBuilder
    private var monthPicker: some View {
        @Bindable var vm = viewModel
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(1...12, id: \.self) { m in
                    FilterChip(
                        label: DateFormatter().shortMonthSymbols[m - 1],
                        count: nil,
                        isActive: vm.month == m,
                        action: {
                            vm.month = m
                            Task { await viewModel.load(client: env.apiClient) }
                        }
                    )
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func heroCard(entry: BoxOfficeEntry) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            LazyImage(url: TMDBImage.backdrop(entry.backdropPath)) { state in
                if let image = state.image { image.resizable().scaledToFill() }
                else { Color.brandSurfaceElevated }
            }
            .aspectRatio(16.0 / 9.0, contentMode: .fill)
            .frame(maxWidth: .infinity)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(alignment: .topLeading) {
                Text("#\(entry.rank)")
                    .font(.system(.title3, design: .serif).weight(.bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.brandPrimary, in: Capsule())
                    .padding(10)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(entry.title).font(.title3.weight(.semibold)).foregroundStyle(.white)
                HStack(spacing: 12) {
                    if let revenue = entry.revenue {
                        kpi("Revenue", value: formatMoney(revenue))
                    }
                    if let budget = entry.budget {
                        kpi("Budget", value: formatMoney(budget))
                    }
                    if let rating = entry.voteAverage {
                        kpi("Rating", value: String(format: "★ %.1f", rating))
                    }
                }
            }
        }
    }

    private func kpi(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(Color.brandTextSecondary)
            Text(value).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
        }
    }

    private func entryRow(_ entry: BoxOfficeEntry) -> some View {
        HStack(spacing: 10) {
            Text("\(entry.rank)")
                .font(.system(.title3, design: .monospaced))
                .foregroundStyle(Color.brandTextSecondary)
                .frame(width: 28)

            LazyImage(url: TMDBImage.poster(entry.posterPath)) { state in
                if let image = state.image { image.resizable().scaledToFill() }
                else { Color.brandSurfaceElevated }
            }
            .frame(width: 44, height: 66)
            .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                if let formatted = formatReleaseDate(entry.releaseDate) {
                    Text(formatted).font(.caption2).foregroundStyle(Color.brandTextSecondary)
                }
            }
            Spacer()
            if let revenue = entry.revenue {
                Text(formatMoney(revenue))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.white)
            }
        }
        .padding(.vertical, 8)
    }

    /// Bridge a `BoxOfficeEntry` (movie-only) into the shared `MediaItem`
    /// shape so the row/hero can push a `MediaDetailView`.
    private func mediaItem(for entry: BoxOfficeEntry) -> MediaItem {
        MediaItem(
            id: entry.id,
            contentType: .movie,
            title: entry.title,
            posterPath: entry.posterPath,
            backdropPath: entry.backdropPath
        )
    }

    private func formatMoney(_ value: Int) -> String {
        let v = Double(value)
        if v >= 1_000_000_000 { return String(format: "$%.1fB", v / 1_000_000_000) }
        if v >= 1_000_000 { return String(format: "$%.1fM", v / 1_000_000) }
        return "$\(value)"
    }

    /// Backend returns release dates as ISO `YYYY-MM-DD` strings — reformat
    /// to the site-wide "May 23, 2026" style.
    private func formatReleaseDate(_ raw: String?) -> String? {
        guard let raw, !raw.isEmpty,
              let date = MediaItem.tmdbDateFormatter.date(from: raw) else { return nil }
        return date.formatted(.dateTime.month(.wide).day().year())
    }
}

@Observable @MainActor
final class BoxOfficeViewModel {
    enum Mode { case yearly, monthly, allTime }

    var mode: Mode = .yearly
    var year: Int = Calendar.current.component(.year, from: Date())
    var month: Int = Calendar.current.component(.month, from: Date())
    var page: Int = 1
    var entries: [BoxOfficeEntry] = []
    var isLoading = false
    var errorMessage: String?

    /// How many of the most recent years to show as inline chips. Anything
    /// earlier than this falls into the "Earlier" menu picker.
    private static let chipYearCount = 5
    /// Earliest year offered in the menu picker.
    private static let earliestYear = 1980

    var yearOptions: [Int] {
        let current = Calendar.current.component(.year, from: Date())
        return Array(Self.earliestYear...current).reversed()
    }

    /// Recent years rendered as horizontal chips alongside the menu.
    var recentYearOptions: [Int] {
        let current = Calendar.current.component(.year, from: Date())
        return Array((current - Self.chipYearCount + 1)...current).reversed()
    }

    /// Older years rendered inside the "Earlier" menu picker.
    var earlierYearOptions: [Int] {
        let current = Calendar.current.component(.year, from: Date())
        let cutoff = current - Self.chipYearCount
        guard cutoff >= Self.earliestYear else { return [] }
        return Array(Self.earliestYear...cutoff).reversed()
    }

    func load(client: APIClient) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            switch mode {
            case .yearly:
                entries = try await client.boxOfficeYearly(year: year, limit: 20)
            case .monthly:
                entries = try await client.boxOfficeMonthly(year: year, month: month, limit: 20)
            case .allTime:
                entries = try await client.boxOfficeAllTime(page: page, limit: 20)
            }
        } catch is CancellationError {
            // ignore
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func nextPage(client: APIClient) async {
        guard mode == .allTime else { return }
        page += 1
        await load(client: client)
    }

    func previousPage(client: APIClient) async {
        guard mode == .allTime, page > 1 else { return }
        page -= 1
        await load(client: client)
    }
}
