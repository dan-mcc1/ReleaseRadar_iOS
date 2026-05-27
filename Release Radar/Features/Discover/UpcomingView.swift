import SwiftUI
import NukeUI

struct UpcomingView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var viewModel = UpcomingViewModel()

    var body: some View {
        @Bindable var vm = viewModel
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                LargeTitleHeader(
                    eyebrow: "On the horizon · \(viewModel.dateRangeLabel)",
                    title: "Upcoming",
                    accent: nil
                ) { EmptyView() }

                HStack(spacing: 8) {
                    FilterChip(
                        label: "Movies",
                        count: nil,
                        isActive: vm.type == .movie,
                        action: { vm.type = .movie }
                    )
                    FilterChip(
                        label: "TV",
                        count: nil,
                        isActive: vm.type == .tv,
                        action: { vm.type = .tv }
                    )
                    Spacer()
                }
                .padding(.horizontal, 16)
                .onChange(of: vm.type) { _, _ in Task { await viewModel.load(client: env.apiClient) } }

                if viewModel.isLoading {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, 32)
                } else if let error = viewModel.errorMessage {
                    InlineErrorBanner(message: error) { Task { await viewModel.load(client: env.apiClient) } }
                        .padding(.horizontal, 16)
                } else if viewModel.items.isEmpty {
                    ContentUnavailableView("Nothing yet", systemImage: "calendar", description: Text("Check back soon."))
                } else {
                    LazyVStack(spacing: 18) {
                        ForEach(viewModel.items) { item in
                            NavigationLink {
                                MediaDetailView(item: item)
                            } label: {
                                upcomingCard(for: item)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                }

                if viewModel.totalPages > 1 {
                    paginationBar
                        .padding(.horizontal, 16)
                }
            }
            .padding(.bottom, 16)
        }
        .pageBackground()
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load(client: env.apiClient) }
    }

    @ViewBuilder
    private func upcomingCard(for item: MediaItem) -> some View {
        ZStack(alignment: .bottomLeading) {
            Color.brandSurfaceElevated
                .aspectRatio(16.0 / 10.0, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .overlay {
                    LazyImage(url: item.backdropURL ?? item.posterURL) { state in
                        if let image = state.image {
                            image.resizable().scaledToFill()
                        }
                    }
                }
                .clipped()

            LinearGradient(
                colors: [
                    Color.black.opacity(0.88),
                    Color.black.opacity(0.45),
                    Color.black.opacity(0.0),
                    Color.black.opacity(0.35)
                ],
                startPoint: .bottom,
                endPoint: .top
            )

            VStack {
                HStack(alignment: .top) {
                    dateStamp(for: item.releaseDate)
                    Spacer()
                    countdownChip(for: item.releaseDate)
                }
                Spacer()
            }
            .padding(14)

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(item.contentType == .tv ? "SERIES" : "FILM")
                        .font(BrandFont.mono(10, weight: .semibold))
                        .tracking(2)
                        .foregroundStyle(BrandTheme.primaryText)
                    if let year = item.releaseDate?.formatted(.dateTime.year()) {
                        Text("·")
                            .font(BrandFont.mono(10, weight: .semibold))
                            .foregroundStyle(BrandTheme.textMuted)
                        Text(year)
                            .font(BrandFont.mono(10, weight: .semibold))
                            .tracking(1.5)
                            .foregroundStyle(BrandTheme.textMuted)
                    }
                }

                Text(item.title)
                    .font(BrandFont.serif(24))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                HStack(alignment: .bottom, spacing: 12) {
                    if let overview = item.overview, !overview.isEmpty {
                        Text(overview)
                            .font(BrandFont.sans(12))
                            .foregroundStyle(Color.white.opacity(0.78))
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        Spacer()
                    }
                    MiniWatchButtons(type: item.contentType, id: item.id)
                }
                .padding(.top, 2)
            }
            .padding(14)
        }
        .frame(maxWidth: .infinity)
        .background(Color.brandSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(BrandTheme.border, lineWidth: 1)
        )
    }

    @ViewBuilder
    private func dateStamp(for date: Date?) -> some View {
        if let date {
            VStack(alignment: .leading, spacing: -2) {
                Text(date.formatted(.dateTime.month(.abbreviated)).uppercased())
                    .font(BrandFont.mono(11, weight: .semibold))
                    .tracking(2)
                    .foregroundStyle(BrandTheme.primaryText)
                Text(date.formatted(.dateTime.day()))
                    .font(BrandFont.serif(40, italic: true))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
            )
        }
    }

    @ViewBuilder
    private func countdownChip(for date: Date?) -> some View {
        if let date, let label = countdownLabel(for: date) {
            Text(label)
                .font(BrandFont.mono(10, weight: .semibold))
                .tracking(1.5)
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(BrandTheme.primary, in: Capsule())
        }
    }

    private func countdownLabel(for date: Date) -> String? {
        let cal = Calendar.current
        let startOfToday = cal.startOfDay(for: Date())
        let startOfTarget = cal.startOfDay(for: date)
        guard let days = cal.dateComponents([.day], from: startOfToday, to: startOfTarget).day else {
            return nil
        }
        if days < 0 { return "OUT NOW" }
        if days == 0 { return "TODAY" }
        if days == 1 { return "TOMORROW" }
        if days < 7 { return "IN \(days) DAYS" }
        let weeks = Int((Double(days) / 7.0).rounded())
        if weeks == 1 { return "IN 1 WEEK" }
        return "IN \(weeks) WEEKS"
    }

    private var paginationBar: some View {
        @Bindable var vm = viewModel
        return HStack {
            Button("Previous") {
                Task { await viewModel.previousPage(client: env.apiClient) }
            }
            .disabled(vm.page <= 1)
            Spacer()
            Text("Page \(vm.page) of \(vm.totalPages)")
                .font(.caption)
                .foregroundStyle(Color.brandTextSecondary)
            Spacer()
            Button("Next") {
                Task { await viewModel.nextPage(client: env.apiClient) }
            }
            .disabled(vm.page >= vm.totalPages)
        }
        .buttonStyle(.bordered)
    }
}

@Observable @MainActor
final class UpcomingViewModel {
    var type: ContentType = .movie
    var items: [MediaItem] = []
    var isLoading = false
    var errorMessage: String?
    var page = 1
    var totalPages = 1

    var dateRangeLabel: String {
        let today = Date()
        let cal = Calendar.current
        let end = cal.date(byAdding: .day, value: 30, to: today) ?? today
        let fmt = Date.FormatStyle().month(.abbreviated).day()
        return "\(today.formatted(fmt)) – \(end.formatted(fmt))"
    }

    func load(client: APIClient) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        let from = Date()
        let to = Calendar.current.date(byAdding: .day, value: 30, to: from) ?? from
        do {
            // Try paginated upcoming first — the source of truth when there
            // are date-range results. Falls back to trending only when the
            // upcoming window is empty for this content type.
            let upcoming = try await client.upcomingPaged(
                type: type,
                from: from,
                to: to,
                page: page
            )
            if !upcoming.results.isEmpty {
                items = upcoming.results
                totalPages = upcoming.totalPages
            } else {
                let response = try await client.trending(type: type, page: page)
                items = response.results.map { $0.withType(type) }
                totalPages = max(response.totalPages, 1)
            }
        } catch is CancellationError {
            // ignore
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func nextPage(client: APIClient) async {
        guard page < totalPages else { return }
        page += 1
        await load(client: client)
    }

    func previousPage(client: APIClient) async {
        guard page > 1 else { return }
        page -= 1
        await load(client: client)
    }
}
