import SwiftUI
import NukeUI

/// Experimental month-grid calendar that mirrors the web app's layout —
/// a 7-column grid of day cells where each cell shows the day number and
/// up to two poster thumbnails for that day's releases. Tapping a day
/// selects it and a list of that day's items renders below the grid.
///
/// Kept as a standalone component (driven by the parent's existing
/// `CalendarViewModel` so the two views share data) so the parent can
/// trivially toggle between this and the existing timeline.
struct CalendarMonthGridView: View {
    @Bindable var viewModel: CalendarViewModel
    @Environment(AppEnvironment.self) private var env

    /// First day of the month currently being displayed. Always the
    /// 1st-of-the-month, midnight, local time.
    @State private var monthAnchor: Date = Self.startOfMonth(Date())
    @State private var selectedDate: Date = Calendar.current.startOfDay(for: Date())

    private let cal = Calendar.current

    var body: some View {
        // Wrap the entire grid + selected-day list in one ScrollView so
        // the page scrolls as a single surface — the day list below the
        // grid now naturally comes into view as the user scrolls past
        // the month grid, instead of being trapped in its own scroller.
        ScrollView {
            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
                    .padding(.bottom, 12)

                weekdayHeader
                    .padding(.horizontal, 12)
                    .padding(.bottom, 6)

                grid
                    .padding(.horizontal, 12)
                    .padding(.bottom, 14)

                selectedDaySection
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
            }
        }
    }

    // MARK: - Header

    /// Big serif month/year title with prev / today / next nav and a
    /// `Today (N)` chip on the right (mirrors the web app eyebrow).
    private var header: some View {
        let monthCount = viewModel.releaseCount(inMonthOf: monthAnchor)
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("YOUR CALENDAR\(monthCount > 0 ? " · \(monthCount) THIS MONTH" : "")")
                    .font(BrandFont.mono(10, weight: .semibold))
                    .tracking(1.5)
                    .foregroundStyle(BrandTheme.textDim)
                Spacer()
            }

            HStack(alignment: .firstTextBaseline) {
                (
                    Text(monthName).font(BrandFont.serif(38)).foregroundColor(BrandTheme.text)
                    + Text(" \(yearString)").font(BrandFont.serif(38, italic: true)).foregroundColor(BrandTheme.primaryText)
                )
                Spacer()
                HStack(spacing: 6) {
                    navButton(icon: "chevron.left") { stepMonth(-1) }
                    navButton(label: "Today") { jumpToToday() }
                    navButton(icon: "chevron.right") { stepMonth(+1) }
                }
            }
        }
    }

    private func navButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(BrandTheme.text)
                .frame(width: 32, height: 32)
                .background(BrandTheme.surface, in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(BrandTheme.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func navButton(label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(BrandFont.sans(12, weight: .semibold))
                .foregroundStyle(BrandTheme.text)
                .padding(.horizontal, 10)
                .frame(height: 32)
                .background(BrandTheme.surface, in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(BrandTheme.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Grid

    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            ForEach(weekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(BrandFont.mono(10, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(BrandTheme.textDim)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var grid: some View {
        let cells = monthCells
        let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)
        return LazyVGrid(columns: columns, spacing: 6) {
            ForEach(cells.indices, id: \.self) { idx in
                if let date = cells[idx] {
                    dayCell(date: date)
                } else {
                    Color.clear.aspectRatio(0.78, contentMode: .fit)
                }
            }
        }
    }

    /// One cell in the month grid. Highlighted when it's the selected
    /// day; shows a small emerald dot when it's today. Up to two poster
    /// thumbnails appear stacked underneath the date number.
    private func dayCell(date: Date) -> some View {
        let entries = entries(for: date)
        let isSelected = cal.isDate(date, inSameDayAs: selectedDate)
        let isToday = cal.isDateInToday(date)
        let isCurrentMonth = cal.isDate(date, equalTo: monthAnchor, toGranularity: .month)
        let dayNum = cal.component(.day, from: date)

        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedDate = cal.startOfDay(for: date)
            }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text("\(dayNum)")
                        .font(BrandFont.mono(11, weight: isToday ? .bold : .medium))
                        .foregroundStyle(
                            isToday ? BrandTheme.primaryText
                            : (isCurrentMonth ? BrandTheme.text : BrandTheme.textDim)
                        )
                    Spacer(minLength: 0)
                    if entries.count > 2 {
                        Text("+\(entries.count - 2)")
                            .font(BrandFont.mono(8, weight: .semibold))
                            .foregroundStyle(BrandTheme.textDim)
                    }
                }

                // Up to two backdrop thumbnails stacked vertically — both
                // fully visible at once, full cell width, so every release
                // in a day is identifiable at a glance instead of being
                // hidden behind another poster.
                VStack(spacing: 3) {
                    ForEach(entries.prefix(2)) { entry in
                        miniBackdrop(entry: entry)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: 0)
            }
            .padding(5)
            .frame(maxWidth: .infinity)
            .aspectRatio(0.78, contentMode: .fit)
            .background(
                isSelected ? BrandTheme.primarySoft : BrandTheme.surface,
                in: RoundedRectangle(cornerRadius: 8)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        isSelected ? BrandTheme.primary :
                        (isToday ? BrandTheme.borderStrong : BrandTheme.border),
                        lineWidth: isSelected ? 1.5 : 1
                    )
            )
            .opacity(isCurrentMonth ? 1 : 0.55)
        }
        .buttonStyle(.plain)
    }

    private func miniPoster(entry: CalendarEntry) -> some View {
        LazyImage(url: entry.posterURL) { state in
            if let image = state.image {
                image.resizable().scaledToFill()
            } else {
                BrandTheme.surface2
            }
        }
        .aspectRatio(2.0 / 3.0, contentMode: .fit)
        .frame(maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 3))
    }

    /// 16:9 backdrop thumbnail used inside a day cell. Falls back to the
    /// poster (cropped) when no backdrop is available. Sized via a clear
    /// aspect-ratio anchor + LazyImage overlay so the height is always
    /// derived from the cell's actual width — without that pattern the
    /// LazyImage's intrinsic size confuses the VStack layout.
    private func miniBackdrop(entry: CalendarEntry) -> some View {
        Color.clear
            .aspectRatio(16.0 / 9.0, contentMode: .fit)
            .overlay {
                LazyImage(url: backdropURL(for: entry)) { state in
                    if let image = state.image {
                        image.resizable().scaledToFill()
                    } else {
                        BrandTheme.surface2
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 3))
    }

    private func backdropURL(for entry: CalendarEntry) -> URL? {
        TMDBImage.backdrop(entry.backdropPath, size: "w300")
            ?? TMDBImage.poster(entry.posterPath, size: "w185")
    }

    // MARK: - Selected day list

    @ViewBuilder
    private var selectedDaySection: some View {
        let entries = entries(for: selectedDate)
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                (
                    Text(selectedDateLabel + " ").font(BrandFont.serif(20)).foregroundColor(BrandTheme.text)
                    + Text(weekdayLabel).font(BrandFont.serif(20, italic: true)).foregroundColor(BrandTheme.primaryText)
                )
                Spacer()
                Text("\(entries.count) ITEM\(entries.count == 1 ? "" : "S")")
                    .font(BrandFont.mono(10, weight: .medium))
                    .tracking(1.2)
                    .foregroundStyle(BrandTheme.textDim)
            }

            if entries.isEmpty {
                Text("Nothing scheduled.")
                    .font(BrandFont.sans(13))
                    .foregroundStyle(BrandTheme.textMuted)
                    .padding(.vertical, 18)
            } else {
                VStack(spacing: 10) {
                    ForEach(entries) { entry in
                        entryRow(entry: entry)
                    }
                }
            }
        }
    }

    private func entryRow(entry: CalendarEntry) -> some View {
        NavigationLink {
            // Route episode entries to EpisodeInfoView, movies to
            // MediaDetailView — same dispatch the timeline uses.
            entryDestination(entry: entry)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                LazyImage(url: entry.posterURL) { state in
                    if let image = state.image { image.resizable().scaledToFill() }
                    else { BrandTheme.surface2 }
                }
                .frame(width: 50, height: 75)
                .clipShape(RoundedRectangle(cornerRadius: 6))

                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.contentType == .tv ? "TV · S\(seasonOrEpisodeLabel(entry))" : "FILM")
                        .font(BrandFont.mono(10, weight: .semibold))
                        .tracking(1.2)
                        .foregroundStyle(BrandTheme.primaryText)
                    Text(entry.title)
                        .font(BrandFont.serif(17))
                        .foregroundStyle(BrandTheme.text)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    if let subtitle = entry.subtitle {
                        Text(subtitle)
                            .font(BrandFont.sans(12))
                            .foregroundStyle(BrandTheme.textMuted)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if entry.isWatched {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(BrandTheme.primary)
                }
            }
            .padding(10)
            .background(BrandTheme.surface, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(BrandTheme.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func entryDestination(entry: CalendarEntry) -> some View {
        switch entry.kind {
        case let .episode(showId, _, season, number):
            EpisodeInfoView(
                showID: showId,
                season: season,
                episode: number,
                initialShowName: entry.title
            )
        case .movie:
            MediaDetailView(item: entry.asMediaItem)
        }
    }

    private func seasonOrEpisodeLabel(_ entry: CalendarEntry) -> String {
        if case let .episode(_, _, season, number) = entry.kind {
            return "\(String(format: "%02d", season)) · E\(String(format: "%02d", number))"
        }
        return ""
    }

    // MARK: - Data helpers

    /// Visible-month cells (with leading/trailing days from neighboring
    /// months padded in) so the grid always reads as a balanced 6-row
    /// block. Returns `nil` placeholders only when the month genuinely
    /// has empty rows at the bottom.
    private var monthCells: [Date?] {
        let firstWeekdayIndex = (cal.component(.weekday, from: monthAnchor) - cal.firstWeekday + 7) % 7
        guard let range = cal.range(of: .day, in: .month, for: monthAnchor) else { return [] }
        let totalDays = range.count

        var cells: [Date?] = []
        // Prepend trailing days of the previous month so the grid lines
        // up under the weekday headers.
        if firstWeekdayIndex > 0,
           let prevMonth = cal.date(byAdding: .month, value: -1, to: monthAnchor),
           let prevRange = cal.range(of: .day, in: .month, for: prevMonth) {
            let prevTotal = prevRange.count
            for i in (prevTotal - firstWeekdayIndex + 1)...prevTotal {
                if let d = cal.date(from: DateComponents(
                    year: cal.component(.year, from: prevMonth),
                    month: cal.component(.month, from: prevMonth),
                    day: i
                )) {
                    cells.append(d)
                }
            }
        }
        // Current month
        for day in 1...totalDays {
            if let d = cal.date(from: DateComponents(
                year: cal.component(.year, from: monthAnchor),
                month: cal.component(.month, from: monthAnchor),
                day: day
            )) {
                cells.append(d)
            }
        }
        // Trail with next-month days to fill a final row of 7
        let remainder = cells.count % 7
        if remainder > 0 {
            let needed = 7 - remainder
            if let nextMonth = cal.date(byAdding: .month, value: 1, to: monthAnchor) {
                for i in 1...needed {
                    if let d = cal.date(from: DateComponents(
                        year: cal.component(.year, from: nextMonth),
                        month: cal.component(.month, from: nextMonth),
                        day: i
                    )) {
                        cells.append(d)
                    }
                }
            }
        }
        return cells
    }

    private func entries(for date: Date) -> [CalendarEntry] {
        viewModel.filteredDays
            .first { cal.isDate($0.date, inSameDayAs: date) }?
            .entries ?? []
    }

    // MARK: - Navigation

    private func stepMonth(_ delta: Int) {
        if let next = cal.date(byAdding: .month, value: delta, to: monthAnchor) {
            withAnimation(.easeInOut(duration: 0.2)) {
                monthAnchor = Self.startOfMonth(next)
            }
        }
    }

    private func jumpToToday() {
        let today = Date()
        withAnimation(.easeInOut(duration: 0.2)) {
            monthAnchor = Self.startOfMonth(today)
            selectedDate = cal.startOfDay(for: today)
        }
    }

    // MARK: - Formatting

    private var weekdaySymbols: [String] {
        // Calendar.veryShortWeekdaySymbols starts at Sunday; reorder
        // based on the user's firstWeekday so the grid matches their
        // locale.
        let symbols = cal.veryShortWeekdaySymbols
        let start = cal.firstWeekday - 1
        return Array(symbols[start...] + symbols[..<start])
    }

    private var monthName: String {
        let f = DateFormatter()
        f.dateFormat = "LLLL"
        return f.string(from: monthAnchor)
    }

    private var yearString: String {
        "\(cal.component(.year, from: monthAnchor))"
    }

    private var selectedDateLabel: String {
        let f = DateFormatter()
        f.dateFormat = "LLLL d"
        return f.string(from: selectedDate)
    }

    private var weekdayLabel: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE"
        return f.string(from: selectedDate)
    }

    private static func startOfMonth(_ date: Date) -> Date {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: date)
        return cal.date(from: comps) ?? date
    }
}
