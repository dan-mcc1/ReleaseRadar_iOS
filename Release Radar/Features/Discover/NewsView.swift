import SwiftUI
import NukeUI
import SafariServices

struct NewsView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var viewModel = NewsViewModel()
    @State private var presentedArticle: PresentedArticle?

    /// Identifiable wrapper around an article URL so we can drive a `.sheet`
    /// presentation directly from a tap on the card.
    struct PresentedArticle: Identifiable {
        let id = UUID()
        let url: URL
    }

    var body: some View {
        @Bindable var vm = viewModel
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                LargeTitleHeader(
                    eyebrow: "Hand-picked · updates 3× daily",
                    title: "News",
                    accent: nil
                ) {
                    Button {
                        Task { await viewModel.load(client: env.apiClient) }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(BrandTheme.text)
                            .frame(width: 38, height: 38)
                            .background(BrandTheme.surface, in: RoundedRectangle(cornerRadius: 13))
                            .overlay(RoundedRectangle(cornerRadius: 13).stroke(BrandTheme.border, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }

                HStack(spacing: 8) {
                    FilterChip(label: "All", count: nil, isActive: vm.category == .entertainment) {
                        selectCategory(.entertainment)
                    }
                    FilterChip(label: "Films", count: nil, isActive: vm.category == .movies) {
                        selectCategory(.movies)
                    }
                    FilterChip(label: "TV", count: nil, isActive: vm.category == .tv) {
                        selectCategory(.tv)
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)

                searchField
                    .padding(.horizontal, 16)

                if viewModel.isLoading && viewModel.articles.isEmpty {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, 32)
                } else if let error = viewModel.errorMessage {
                    InlineErrorBanner(message: error) { Task { await viewModel.load(client: env.apiClient) } }
                        .padding(.horizontal, 16)
                } else if viewModel.articles.isEmpty {
                    ContentUnavailableView("No headlines", systemImage: "newspaper", description: Text("Check back soon."))
                } else {
                    if let hero = viewModel.articles.first {
                        VStack(alignment: .leading, spacing: 10) {
                            EyebrowLabel(text: "Top story\(TimeAgo.format(hero.publishedAt).map { " · \($0)" } ?? "")")
                                .foregroundStyle(BrandTheme.primaryText)
                            Button {
                                if let url = URL(string: hero.url) {
                                    presentedArticle = PresentedArticle(url: url)
                                }
                            } label: {
                                heroCard(hero)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 16)
                    }

                    LazyVStack(alignment: .leading, spacing: 18) {
                        ForEach(Array(viewModel.articles.dropFirst()), id: \.id) { article in
                            Button {
                                if let url = URL(string: article.url) {
                                    presentedArticle = PresentedArticle(url: url)
                                }
                            } label: {
                                storyRow(article)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)

                    if let totalPages = viewModel.totalPages, totalPages > 1 {
                        HStack {
                            Button("Previous") { Task { await viewModel.previousPage(client: env.apiClient) } }
                                .disabled(vm.page <= 1)
                            Spacer()
                            Text("Page \(vm.page) of \(totalPages)")
                                .font(.caption)
                                .foregroundStyle(Color.brandTextSecondary)
                            Spacer()
                            Button("Next") { Task { await viewModel.nextPage(client: env.apiClient) } }
                                .disabled(vm.page >= totalPages)
                        }
                        .buttonStyle(.bordered)
                        .padding(.horizontal, 16)
                    }
                }
            }
            .padding(.bottom, 24)
        }
        .pageBackground()
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load(client: env.apiClient) }
        .sheet(item: $presentedArticle) { item in
            SafariView(url: item.url)
                .ignoresSafeArea()
        }
    }

    private func selectCategory(_ category: NewsCategory) {
        @Bindable var vm = viewModel
        vm.category = category
        vm.page = 1
        Task { await viewModel.load(client: env.apiClient) }
    }

    private var categoryLabel: String {
        switch viewModel.category {
        case .entertainment: return "Entertainment"
        case .movies: return "Film"
        case .tv: return "TV"
        }
    }

    private var searchField: some View {
        @Bindable var vm = viewModel
        return HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(BrandTheme.textMuted)
            TextField("Search headlines", text: $vm.searchText)
                .font(BrandFont.sans(14))
                .foregroundStyle(BrandTheme.text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .onSubmit {
                    vm.activeQuery = vm.searchText.isEmpty ? nil : vm.searchText
                    vm.page = 1
                    Task { await viewModel.load(client: env.apiClient) }
                }
            if !vm.searchText.isEmpty {
                Button {
                    vm.searchText = ""
                    vm.activeQuery = nil
                    vm.page = 1
                    Task { await viewModel.load(client: env.apiClient) }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(BrandTheme.textMuted)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(BrandTheme.surface, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(BrandTheme.border, lineWidth: 1))
    }

    /// Full-bleed hero card for the lead story: 16:10 backdrop, dark gradient
    /// across the bottom, source · category eyebrow, serif headline.
    private func heroCard(_ article: NewsArticle) -> some View {
        ZStack(alignment: .bottomLeading) {
            Color.brandSurfaceElevated
                .aspectRatio(16.0 / 10.0, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .overlay {
                    if let urlString = article.imageUrl, let url = URL(string: urlString) {
                        LazyImage(url: url) { state in
                            if let image = state.image {
                                image.resizable().scaledToFill()
                            }
                        }
                    } else {
                        Image(systemName: "newspaper")
                            .font(.system(size: 44, weight: .light))
                            .foregroundStyle(BrandTheme.textDim)
                    }
                }
                .clipped()

            LinearGradient(
                colors: [Color.black.opacity(0.05), Color.black.opacity(0.9)],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 6) {
                Text(heroEyebrow(for: article))
                    .font(BrandFont.mono(10, weight: .semibold))
                    .tracking(1.4)
                    .foregroundStyle(BrandTheme.primaryText)
                Text(article.title ?? "")
                    .font(BrandFont.serif(22))
                    .foregroundStyle(.white)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
            }
            .padding(16)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(BrandTheme.border, lineWidth: 1)
        )
    }

    private func heroEyebrow(for article: NewsArticle) -> String {
        var parts: [String] = []
        if let source = article.source?.name, !source.isEmpty {
            parts.append(source.uppercased())
        }
        parts.append(categoryLabel.uppercased())
        return parts.joined(separator: " · ")
    }

    /// Compact horizontal row: square thumbnail on the left, mono metadata
    /// (source · tag · time) over a serif headline on the right.
    private func storyRow(_ article: NewsArticle) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Group {
                if let urlString = article.imageUrl, let url = URL(string: urlString) {
                    LazyImage(url: url) { state in
                        if let image = state.image { image.resizable().scaledToFill() }
                        else { BrandTheme.surface2 }
                    }
                } else {
                    BrandTheme.surface2.overlay(
                        Image(systemName: "newspaper")
                            .foregroundStyle(BrandTheme.textDim)
                    )
                }
            }
            .frame(width: 84, height: 84)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 4) {
                Text(rowEyebrow(for: article))
                    .font(BrandFont.mono(9.5, weight: .medium))
                    .tracking(1.2)
                    .foregroundStyle(BrandTheme.textDim)
                Text(article.title ?? "")
                    .font(BrandFont.serif(16.5))
                    .foregroundStyle(BrandTheme.text)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func rowEyebrow(for article: NewsArticle) -> String {
        var parts: [String] = []
        if let source = article.source?.name, !source.isEmpty {
            parts.append(source.uppercased())
        }
        parts.append(categoryLabel.uppercased())
        if let ago = TimeAgo.format(article.publishedAt) {
            parts.append(ago)
        }
        return parts.joined(separator: " · ")
    }
}

@Observable @MainActor
final class NewsViewModel {
    var category: NewsCategory = .entertainment
    var searchText: String = ""
    var activeQuery: String?
    var articles: [NewsArticle] = []
    var page = 1
    var totalPages: Int?
    var isLoading = false
    var errorMessage: String?

    func load(client: APIClient) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let response = try await client.newsDecoded(category: category, page: page, pageSize: 20, q: activeQuery)
            articles = response.articles
            totalPages = response.totalPages
        } catch is CancellationError {
            // ignore
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func nextPage(client: APIClient) async {
        page += 1
        await load(client: client)
    }

    func previousPage(client: APIClient) async {
        guard page > 1 else { return }
        page -= 1
        await load(client: client)
    }
}

// MARK: - In-app Safari sheet
//
// Wraps `SFSafariViewController` so taps on a news card open the article
// inside a sheet rather than launching the system browser and yanking the
// user out of the app. Safari's built-in toolbar still lets users tap the
// Safari icon to escape to the system browser whenever they want.

private struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = false
        config.barCollapsingEnabled = true
        let vc = SFSafariViewController(url: url, configuration: config)
        vc.dismissButtonStyle = .done
        vc.preferredBarTintColor = UIColor(BrandTheme.bg)
        vc.preferredControlTintColor = UIColor(BrandTheme.primary)
        return vc
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
