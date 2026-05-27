import SwiftUI
import NukeUI

struct CalendarView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var viewModel = CalendarViewModel()
    @State private var didScrollToToday = false
    @State private var jumpToTodayToggle = false

    /// Toggle between the existing scrollable-timeline view and the new
    /// experimental web-style month grid. Kept as transient view state
    /// (not persisted) since the grid is still being trialed.
    enum DisplayMode: String, CaseIterable, Identifiable {
        case timeline, grid
        var id: String { rawValue }
        var label: String {
            switch self {
            case .timeline: "Timeline"
            case .grid: "Grid"
            }
        }
        var icon: String {
            switch self {
            case .timeline: "list.bullet"
            case .grid: "square.grid.2x2"
            }
        }
    }
    @State private var displayMode: DisplayMode = .timeline
    /// The date the user just tapped in the week strip. Bumped via `scrollNonce`
    /// so tapping the same date twice re-fires the scroll.
    @State private var pendingScrollDate: Date?
    @State private var scrollNonce: Int = 0
    /// Currently highlighted day in the week strip. Defaults to today.
    @State private var selectedDate: Date = Calendar.current.startOfDay(for: Date())
    /// Which week is currently snapped in the strip pager. Lifted up so the
    /// "today" button can snap the pager back to the current week.
    @State private var visibleWeek: Date?

    /// How many weeks of past / future are pre-rendered in the week strip.
    private static let weeksBack = 12
    private static let weeksForward = 12

    var body: some View {
        @Bindable var viewModel = viewModel
        NavigationStack {
            content
                .background(BrandTheme.bg.ignoresSafeArea())
                .toolbar(.hidden, for: .navigationBar)
                .task {
                    await viewModel.loadIfNeeded(client: env.apiClient)
                    await viewModel.enrichEpisodeData(client: env.apiClient)
                }
                .onAppear {
                    Task { await viewModel.refreshCurrentlyWatching(client: env.apiClient) }
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.days.isEmpty {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = viewModel.errorMessage, viewModel.days.isEmpty {
            ContentUnavailableView("Couldn't load calendar", systemImage: "exclamationmark.triangle", description: Text(error))
        } else if viewModel.days.isEmpty {
            ContentUnavailableView("Nothing scheduled", systemImage: "calendar", description: Text("Add movies and TV shows to your library to see them here."))
        } else {
            switch displayMode {
            case .timeline:
                VStack(spacing: 0) {
                    CalendarHeader(
                        displayDate: selectedDate,
                        monthCount: viewModel.releaseCount(inMonthOf: selectedDate),
                        onJumpToToday: { jumpToToday() },
                        viewModel: viewModel
                    )
                    .overlay(alignment: .topTrailing) {
                        displayModeToggle
                            .padding(.top, 18)
                            .padding(.trailing, 12)
                    }
                    WeekStripPager(
                        weeks: weeks,
                        initialWeekId: currentWeekStart,
                        selectedDate: selectedDate,
                        visibleWeek: $visibleWeek,
                        countProvider: { date in
                            let cal = Calendar.current
                            return viewModel.filteredDays
                                .first { cal.isDate($0.date, inSameDayAs: date) }?.entries.count ?? 0
                        },
                        onSelectDate: { date in
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedDate = Calendar.current.startOfDay(for: date)
                            }
                            pendingScrollDate = date
                            scrollNonce &+= 1
                        }
                    )
                    .frame(height: 60)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 14)
                    if !viewModel.currentlyWatchingItems.isEmpty {
                        ContinueWatchingRail(viewModel: viewModel)
                            .padding(.bottom, 14)
                    }
                    timeline
                }
            case .grid:
                VStack(spacing: 0) {
                    HStack {
                        Spacer()
                        displayModeToggle
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)

                    CalendarMonthGridView(viewModel: viewModel)
                }
            }
        }
    }

    /// Small segmented toggle that swaps between the original timeline
    /// and the new web-style month grid. Lives in both modes' headers so
    /// users can flip back and forth easily.
    private var displayModeToggle: some View {
        HStack(spacing: 0) {
            ForEach(DisplayMode.allCases) { mode in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        displayMode = mode
                    }
                } label: {
                    Image(systemName: mode.icon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(displayMode == mode ? BrandTheme.bg : BrandTheme.textMuted)
                        .frame(width: 34, height: 28)
                        .background(
                            displayMode == mode ? BrandTheme.text : Color.clear,
                            in: RoundedRectangle(cornerRadius: 7)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(mode.label) view")
            }
        }
        .padding(2)
        .background(BrandTheme.surface, in: RoundedRectangle(cornerRadius: 9))
        .overlay(RoundedRectangle(cornerRadius: 9).stroke(BrandTheme.border, lineWidth: 1))
    }

    /// Start of the calendar week (Sunday in the user's locale) for today.
    private var currentWeekStart: Date {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return cal.dateInterval(of: .weekOfYear, for: today)?.start ?? today
    }

    /// Pre-rendered weeks centered on the current week.
    private var weeks: [WeekData] {
        let cal = Calendar.current
        let start = currentWeekStart
        return (-Self.weeksBack...Self.weeksForward).compactMap { offset -> WeekData? in
            guard let weekStart = cal.date(byAdding: .weekOfYear, value: offset, to: start) else { return nil }
            let days: [Date] = (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: weekStart) }
            return WeekData(startDate: weekStart, days: days)
        }
    }

    private var timeline: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 24) {
                    ForEach(viewModel.filteredDays) { day in
                        DaySectionView(day: day, viewModel: viewModel)
                            .id(day.date)
                            .onAppear { handleAppear(of: day, proxy: proxy) }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 24)
            }
            .refreshable { await viewModel.load(client: env.apiClient) }
            .task {
                guard !didScrollToToday, let anchor = viewModel.todayAnchorID else { return }
                // Retry until LazyVStack has materialised the today
                // item, then drop it at the top of the viewport.
                for delay in [50, 150, 300] {
                    try? await Task.sleep(for: .milliseconds(delay))
                    proxy.scrollTo(anchor, anchor: .top)
                }
                didScrollToToday = true
            }
            .onChange(of: jumpToTodayToggle) { _, _ in
                if let anchor = viewModel.todayAnchorID {
                    withAnimation { proxy.scrollTo(anchor, anchor: .top) }
                }
            }
            .onChange(of: scrollNonce) { _, _ in
                guard let target = pendingScrollDate else { return }
                let cal = Calendar.current
                let dayStart = cal.startOfDay(for: target)
                if let anchor = viewModel.days.first(where: { $0.date >= dayStart })?.date {
                    withAnimation { proxy.scrollTo(anchor, anchor: .top) }
                }
            }
        }
    }

    /// On-scroll chunk triggers. With `.defaultScrollAnchor(.center)`
    /// in place, the ScrollView keeps the visible content stable when
    /// `days` changes size — no manual scroll restoration needed in
    /// either direction.
    private func handleAppear(of day: CalendarViewModel.DaySection, proxy: ScrollViewProxy) {
        guard didScrollToToday else { return }
        if day.date == viewModel.days.first?.date {
            Task {
                guard let chunk = await viewModel.fetchBackwardChunk(client: env.apiClient) else { return }
                viewModel.applyBackwardChunk(chunk)
                await viewModel.enrichEpisodeData(client: env.apiClient)
            }
        } else if day.date == viewModel.days.last?.date {
            Task {
                guard let chunk = await viewModel.fetchForwardChunk(client: env.apiClient) else { return }
                viewModel.applyForwardChunk(chunk)
                await viewModel.enrichEpisodeData(client: env.apiClient)
            }
        }
    }

    /// Reset everything to "today": highlighted day, week strip page, header
    /// month, and agenda scroll position.
    private func jumpToToday() {
        let today = Calendar.current.startOfDay(for: Date())
        withAnimation(.easeInOut(duration: 0.25)) {
            selectedDate = today
            visibleWeek = currentWeekStart
        }
        jumpToTodayToggle.toggle()
    }
}

// MARK: - Editorial header (eyebrow + month + italic year accent + trailing actions)

private struct CalendarHeader: View {
    /// The month/year shown in the title is derived from this — tapping a
    /// day in the week strip on a different month updates `displayDate`
    /// and the header re-renders.
    let displayDate: Date
    /// Number of releases in `displayDate`'s month after filtering.
    let monthCount: Int
    let onJumpToToday: () -> Void
    @Bindable var viewModel: CalendarViewModel

    private static let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "LLLL"
        return f
    }()

    var body: some View {
        let monthName = Self.monthFormatter.string(from: displayDate)
        let year = Calendar.current.component(.year, from: displayDate)

        LargeTitleHeader(
            eyebrow: eyebrow,
            title: monthName,
            accent: String(year)
        ) {
            HStack(spacing: 8) {
                SoftIconButton(systemName: "calendar", action: onJumpToToday)
                filterMenu
            }
        }
    }

    private var filterMenu: some View {
        Menu {
            Picker("Type", selection: $viewModel.mediaTypeFilter) {
                ForEach(CalendarViewModel.MediaTypeFilter.allCases) { f in
                    Text(f.label).tag(f)
                }
            }
            Picker("Status", selection: $viewModel.watchedFilter) {
                ForEach(CalendarViewModel.WatchedFilter.allCases) { f in
                    Text(f.label).tag(f)
                }
            }
            Toggle("Currently watching only", isOn: $viewModel.currentlyWatchingOnly)
            if viewModel.anyFilterActive {
                Divider()
                Button("Clear filters", role: .destructive) {
                    viewModel.clearFilters()
                }
            }
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 38 / 2.8)
                    .fill(viewModel.anyFilterActive ? BrandTheme.primarySoft : BrandTheme.surface)
                RoundedRectangle(cornerRadius: 38 / 2.8)
                    .stroke(viewModel.anyFilterActive ? Color.clear : BrandTheme.border, lineWidth: 1)
                Image(systemName: "line.3.horizontal.decrease")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(viewModel.anyFilterActive ? BrandTheme.primaryText : BrandTheme.text)
            }
            .frame(width: 38, height: 38)
        }
    }

    private var eyebrow: String {
        let base = "On the radar"
        guard monthCount > 0 else { return base }
        return "\(base) · \(monthCount) this month"
    }
}

// MARK: - Week strip
//
// A horizontally paging scroll view of weeks (one week per page, ±12 weeks
// from today). Each day cell is tappable — taps bubble up via `onSelectDate`
// so the parent can jump the agenda to that date. The current week is the
// initial page; users swipe to navigate to past or future weeks.

struct WeekData: Identifiable, Hashable {
    let startDate: Date
    let days: [Date]
    var id: Date { startDate }
}

private struct WeekStripPager: View {
    let weeks: [WeekData]
    let initialWeekId: Date
    let selectedDate: Date
    /// Bound to the parent so external actions ("today" button) can snap
    /// the pager back to a specific week.
    @Binding var visibleWeek: Date?
    let countProvider: (Date) -> Int
    let onSelectDate: (Date) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 0) {
                ForEach(weeks) { week in
                    HStack(spacing: 6) {
                        ForEach(week.days, id: \.self) { date in
                            WeekStripDay(
                                date: date,
                                isToday: Calendar.current.isDateInToday(date),
                                isSelected: Calendar.current.isDate(date, inSameDayAs: selectedDate),
                                releaseCount: countProvider(date),
                                onTap: { onSelectDate(date) }
                            )
                        }
                    }
                    .containerRelativeFrame(.horizontal)
                    .id(week.startDate)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $visibleWeek, anchor: .leading)
        .task {
            if visibleWeek == nil { visibleWeek = initialWeekId }
        }
    }
}

// MARK: - One day in the agenda — header + hero card per entry
//
// When a single show drops more than `Self.collapseLimit` episodes on the
// same day (typical of batch releases on Netflix / Apple TV+), only the
// first three are shown by default and an "X more" affordance reveals the
// rest. Movies and one-off episodes are unaffected.

private struct DaySectionView: View {
    let day: CalendarViewModel.DaySection
    @Bindable var viewModel: CalendarViewModel
    @Environment(AppEnvironment.self) private var env

    /// Show IDs whose grouped episodes are currently expanded for this day.
    @State private var expandedShows: Set<Int> = []

    private static let collapseLimit = 3

    private static let monthDayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()

    /// Used in the day-header breadcrumb when the day falls outside the
    /// current calendar year — so the user knows at a glance that a
    /// historical episode (or a far-future release) isn't from "this
    /// year" without having to mentally compare with today's date.
    private static let monthDayYearFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            dayHeader

            if day.entries.isEmpty {
                emptyState
            } else {
                VStack(spacing: 12) {
                    ForEach(Array(groupedEntries.enumerated()), id: \.offset) { _, group in
                        showGroup(group)
                    }
                }
            }
        }
    }

    /// Groups consecutive episodes of the same show into one bucket while
    /// keeping movies as singletons. Episodes within a group are sorted by
    /// season then episode number so the expanded list reads in order.
    private var groupedEntries: [[CalendarEntry]] {
        var result: [[CalendarEntry]] = []
        var current: [CalendarEntry] = []
        var currentShowId: Int? = nil

        func flush() {
            guard !current.isEmpty else { return }
            if currentShowId != nil {
                current.sort { a, b in
                    guard case .episode(_, _, let sa, let na) = a.kind,
                          case .episode(_, _, let sb, let nb) = b.kind else { return false }
                    if sa != sb { return sa < sb }
                    return na < nb
                }
            }
            result.append(current)
            current = []
            currentShowId = nil
        }

        for entry in day.entries {
            switch entry.kind {
            case .episode(let showId, _, _, _):
                if currentShowId == showId {
                    current.append(entry)
                } else {
                    flush()
                    current = [entry]
                    currentShowId = showId
                }
            case .movie:
                flush()
                result.append([entry])
            }
        }
        flush()
        return result
    }

    @ViewBuilder
    private func showGroup(_ entries: [CalendarEntry]) -> some View {
        let showId = entries.compactMap { entry -> Int? in
            if case .episode(let id, _, _, _) = entry.kind { return id }
            return nil
        }.first
        let isExpanded = showId.map { expandedShows.contains($0) } ?? false
        let needsCollapse = entries.count > Self.collapseLimit
        let visible = (needsCollapse && !isExpanded)
            ? Array(entries.prefix(Self.collapseLimit))
            : entries

        VStack(spacing: 12) {
            ForEach(visible) { entry in
                heroCard(for: entry)
            }
            if needsCollapse {
                expandButton(
                    hiddenCount: entries.count - Self.collapseLimit,
                    isExpanded: isExpanded,
                    showId: showId
                )
            }
        }
    }

    private func expandButton(hiddenCount: Int, isExpanded: Bool, showId: Int?) -> some View {
        Button {
            guard let showId else { return }
            withAnimation(.spring(duration: 0.3)) {
                if isExpanded {
                    expandedShows.remove(showId)
                } else {
                    expandedShows.insert(showId)
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                Text(isExpanded
                     ? "Show less"
                     : "\(hiddenCount) more episode\(hiddenCount == 1 ? "" : "s")")
                    .font(BrandFont.sans(13, weight: .semibold))
                Spacer(minLength: 0)
            }
            .foregroundStyle(BrandTheme.primaryText)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(BrandTheme.primarySoft, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private var dayHeader: some View {
        let cal = Calendar.current
        let isToday = cal.isDateInToday(day.date)
        let isTomorrow = cal.isDateInTomorrow(day.date)
        let label: String = {
            if isToday { return "Today" }
            if isTomorrow { return "Tomorrow" }
            return day.date.formatted(.dateTime.weekday(.wide))
        }()
        let count = day.entries.count
        // Surface the year in the breadcrumb whenever the day isn't in
        // the current calendar year — e.g. catching up on a 2024
        // episode in 2026 reads as "DEC 3, 2024 · 1 RELEASE" instead
        // of an ambiguous "DEC 3".
        let dayYear = cal.component(.year, from: day.date)
        let currentYear = cal.component(.year, from: Date())
        let dayString = dayYear == currentYear
            ? Self.monthDayFormatter.string(from: day.date)
            : Self.monthDayYearFormatter.string(from: day.date)
        let breadcrumb = "\(dayString) · \(count) release\(count == 1 ? "" : "s")"

        return HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(label)
                .font(BrandFont.serif(26, italic: isToday))
                .foregroundStyle(isToday ? BrandTheme.primaryText : BrandTheme.text)
            Text(breadcrumb.uppercased())
                .font(BrandFont.mono(10, weight: .medium))
                .tracking(1.4)
                .foregroundStyle(BrandTheme.textDim)
            Spacer(minLength: 0)
        }
    }

    private var emptyState: some View {
        Text("Nothing scheduled.")
            .font(BrandFont.sans(13).italic())
            .foregroundStyle(BrandTheme.textDim)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(BrandTheme.border, style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .background(BrandTheme.surface.clipShape(RoundedRectangle(cornerRadius: 12)))
            )
    }

    private func heroCard(for entry: CalendarEntry) -> some View {
        let chip = chipInfo(for: entry)
        let tag = tagInfo(for: entry)
        return HeroReleaseCard(
            backdropURL: backdropURL(for: entry),
            chipText: chip.text,
            chipColor: chip.color,
            tagText: tag?.text,
            tagColor: tag?.color,
            title: entry.title,
            metadata: heroMetadata(for: entry),
            isWatched: viewModel.isWatched(entry),
            onWatchedToggle: {
                Task { await viewModel.toggleWatched(entry, client: env.apiClient) }
            }
        ) {
            // TV episodes route to the dedicated EpisodeInfoView so the
            // user lands on the exact episode they tapped instead of the
            // show's overview page.
            if case .episode(let showId, _, let season, let number) = entry.kind {
                EpisodeInfoView(
                    showID: showId,
                    season: season,
                    episode: number,
                    initialShowName: entry.title
                )
            } else {
                MediaDetailView(item: entry.asMediaItem)
            }
        }
    }

    private func backdropURL(for entry: CalendarEntry) -> URL? {
        TMDBImage.backdrop(entry.backdropPath, size: "w780")
            ?? TMDBImage.poster(entry.posterPath, size: "w780")
    }

    /// Primary chip at the top-left of the hero — time-relative for upcoming
    /// items, content-type as a fallback.
    private func chipInfo(for entry: CalendarEntry) -> (text: String, color: Color) {
        let cal = Calendar.current
        if cal.isDateInToday(entry.date) { return ("Tonight", BrandTheme.primaryText) }
        if cal.isDateInTomorrow(entry.date) { return ("Tomorrow", BrandTheme.primaryText) }
        return (entry.contentType.displayName, BrandTheme.primaryText)
    }

    /// Optional secondary tag (rendered below the primary chip on the
    /// backdrop) calling out notable TV milestones — premieres in blue,
    /// finales in amber. Returns `nil` for movies and standard episodes.
    ///
    /// The bulk calendar payload often has `episode_type == nil` (the
    /// backend DB column lags TMDb), so we fall back to the per-episode
    /// `episode_type` cached by `enrichEpisodeData` (covers Mid-Season
    /// Finale and Series Finale) and finally to an episode-count check
    /// for plain Season Finales.
    private func tagInfo(for entry: CalendarEntry) -> (text: String, color: Color)? {
        let blue = Color(hex: 0x3B82F6)   // blue-500
        let amber = Color(hex: 0xF59E0B)  // amber-500
        guard case .episode(let showId, _, let season, let number) = entry.kind else { return nil }

        if number == 1 && season == 1 { return ("Series Premiere", blue) }
        if number == 1 { return ("Season Premiere", blue) }

        // Prefer the calendar payload's episode_type, then the enriched
        // per-episode cache (fresh from TMDb season info).
        let type = entry.episodeType
            ?? viewModel.episodeType(showID: showId, season: season, episode: number)
        switch type {
        case "finale": return ("Season Finale", amber)
        case "mid_season": return ("Mid-Season Finale", amber)
        default: break
        }
        // Last resort: infer Season Finale from the total episode count.
        if let total = viewModel.episodeCount(showID: showId, season: season),
           total > 1, number == total {
            return ("Season Finale", amber)
        }
        return nil
    }

    private func heroMetadata(for entry: CalendarEntry) -> [String] {
        var bits: [String] = []
        if let airTime = entry.airTime {
            bits.append(airTime)
        }
        if let subtitle = entry.subtitle, !subtitle.isEmpty {
            bits.append(contentsOf: subtitle.components(separatedBy: " · "))
        } else {
            bits.append(entry.contentType.displayName)
        }
        return bits
    }
}

// MARK: - Continue watching rail
//
// Horizontal scroll of cards for items the user is actively in the middle
// of — episode stills + SxxExx + show name + an inline mark-watched button
// that advances the next-episode pointer. Movies show their backdrop and
// flip the watch-status to "watched" when checked.

private struct ContinueWatchingRail: View {
    @Bindable var viewModel: CalendarViewModel
    @Environment(AppEnvironment.self) private var env

    /// Persisted across launches — the user's choice to hide the rail
    /// sticks until they explicitly re-open it.
    @AppStorage("calendar.continueWatchingExpanded") private var isExpanded: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
                .padding(.horizontal, 20)
            if isExpanded {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 10) {
                        ForEach(viewModel.currentlyWatchingItems) { item in
                            ContinueWatchingCard(
                                item: item,
                                next: item.contentType == .tv ? viewModel.nextEpisodesByShow[item.id] : nil,
                                onMarkWatched: {
                                    Task {
                                        switch item.contentType {
                                        case .tv:
                                            await viewModel.markNextEpisodeWatched(
                                                showID: item.id,
                                                client: env.apiClient
                                            )
                                        case .movie:
                                            await viewModel.markCurrentlyWatchingMovieWatched(
                                                movieID: item.id,
                                                client: env.apiClient
                                            )
                                        }
                                    }
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    /// Header row with the eyebrow label and an expand/collapse chevron.
    private var header: some View {
        HStack {
            EyebrowLabel(text: "Continue watching")
            Spacer()
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(BrandTheme.textMuted)
                    .rotationEffect(.degrees(isExpanded ? 0 : -90))
                    .frame(width: 22, height: 22)
                    .background(BrandTheme.surface, in: Circle())
                    .overlay(Circle().stroke(BrandTheme.border, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isExpanded ? "Hide continue watching" : "Show continue watching")
        }
    }
}

/// Compact discrete card — fixed-size artwork plus a short meta block,
/// wrapped in a surface background so each entry reads as its own pill.
private struct ContinueWatchingCard: View {
    let item: MediaItem
    let next: NextEpisode?
    let onMarkWatched: () -> Void

    private static let cardWidth: CGFloat = 130
    private static let artworkHeight: CGFloat = 73 // 130 * 9/16, rounded

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            NavigationLink {
                destination
            } label: {
                artwork
            }
            .buttonStyle(.plain)

            NavigationLink {
                destination
            } label: {
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.title)
                        .font(BrandFont.sans(11.5, weight: .semibold))
                        .foregroundStyle(BrandTheme.text)
                        .lineLimit(1)
                    if let line = subtitle {
                        Text(line)
                            .font(BrandFont.mono(9, weight: .medium))
                            .tracking(0.3)
                            .foregroundStyle(BrandTheme.textMuted)
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 7)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
        }
        .frame(width: Self.cardWidth, alignment: .leading)
        .background(BrandTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10).stroke(BrandTheme.border, lineWidth: 1)
        )
    }

    /// Tapping a TV card jumps straight to the specific next episode;
    /// tapping a movie card opens the standard movie detail page.
    /// Falls back to the generic detail view when there's no next episode
    /// (e.g. caught-up shows).
    @ViewBuilder
    private var destination: some View {
        if item.contentType == .tv,
           let season = next?.seasonNumber,
           let number = next?.episodeNumber,
           next?.finished != true {
            EpisodeInfoView(
                showID: item.id,
                season: season,
                episode: number,
                initialShowName: item.title
            )
        } else {
            MediaDetailView(item: item)
        }
    }

    @ViewBuilder
    private var artwork: some View {
        LazyImage(url: artworkURL) { state in
            if let image = state.image {
                image.resizable().scaledToFill()
            } else {
                BrandTheme.surface2
            }
        }
        .frame(width: Self.cardWidth, height: Self.artworkHeight)
        .clipped()
        .overlay(alignment: .topLeading) {
            if let codeText {
                Text(codeText)
                    .font(BrandFont.mono(8.5, weight: .semibold))
                    .tracking(0.8)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.black.opacity(0.65), in: RoundedRectangle(cornerRadius: 4))
                    .padding(4)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            Button(action: onMarkWatched) {
                Image(systemName: isCaughtUp ? "checkmark" : "checkmark.circle.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(isCaughtUp ? BrandTheme.bg : .white)
                    .frame(width: 22, height: 22)
                    .background(
                        Circle().fill(isCaughtUp ? BrandTheme.primary : Color.black.opacity(0.6))
                    )
            }
            .buttonStyle(.plain)
            .padding(4)
        }
    }

    // MARK: - Helpers

    private var artworkURL: URL? {
        if let still = next?.stillPath, let url = TMDBImage.still(still, size: "w300") {
            return url
        }
        return TMDBImage.backdrop(item.backdropPath, size: "w780") ?? item.posterURL
    }

    private var isCaughtUp: Bool { next?.finished == true }

    /// Top-left chip: SxxExx for shows with progress, "CAUGHT UP" when the
    /// user has burned through every available episode, `nil` for movies
    /// (the artwork already conveys the title).
    private var codeText: String? {
        if isCaughtUp { return "Caught up" }
        if let season = next?.seasonNumber, let ep = next?.episodeNumber {
            return String(format: "S%02d E%02d", season, ep)
        }
        return nil
    }

    private var subtitle: String? {
        if item.contentType == .movie { return "Movie" }
        if isCaughtUp { return "All caught up" }
        if let name = next?.name, !name.isEmpty { return name }
        return nil
    }
}

#Preview {
    CalendarView()
        .environment(AppEnvironment())
        .tint(.brandPrimary)
        .preferredColorScheme(.dark)
}
