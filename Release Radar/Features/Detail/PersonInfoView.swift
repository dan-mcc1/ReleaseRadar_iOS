import SwiftUI
import NukeUI

struct PersonInfoView: View {
    let personID: Int
    let initialName: String?

    @Environment(AppEnvironment.self) private var env
    @State private var person: PersonDetails?
    @State private var isLoading = true
    @State private var errorMessage: String?

    init(personID: Int, initialName: String? = nil) {
        self.personID = personID
        self.initialName = initialName
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if isLoading && person == nil {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, 64)
                } else if let errorMessage, person == nil {
                    InlineErrorBanner(message: errorMessage) { Task { await load() } }
                        .padding(.horizontal, 16)
                } else if let person {
                    hero(person: person)
                    if let bio = person.biography, !bio.isEmpty {
                        Text(bio)
                            .font(BrandFont.sans(14))
                            .foregroundStyle(BrandTheme.text)
                            .padding(.horizontal, 16)
                    }
                    keyFacts(person: person)
                    if let credits = topMovieCredits(person), !credits.isEmpty {
                        creditsSection(title: "Known for", accent: "movies", items: credits)
                    }
                    if let credits = topTVCredits(person), !credits.isEmpty {
                        creditsSection(title: "Known for", accent: "TV", items: credits)
                    }
                }
            }
            .padding(.bottom, 32)
        }
        .pageBackground()
        .navigationTitle(person?.name ?? initialName ?? "Person")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func hero(person: PersonDetails) -> some View {
        ZStack(alignment: .bottomLeading) {
            GeometryReader { geo in
                LazyImage(url: TMDBImage.providerLogo(person.profilePath)) { state in
                    if let image = state.image {
                        image.resizable().scaledToFill()
                    } else {
                        Color.brandSurfaceElevated
                    }
                }
                .frame(width: geo.size.width, height: 280)
                .clipped()
            }
            .frame(height: 280)

            LinearGradient(
                colors: [.black.opacity(0.0), .black.opacity(0.7)],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 6) {
                if let known = person.knownForDepartment, !known.isEmpty {
                    Text(known.uppercased())
                        .font(BrandFont.mono(10, weight: .semibold))
                        .tracking(1.6)
                        .foregroundStyle(.white.opacity(0.85))
                }
                Text(person.name ?? "—")
                    .font(BrandFont.serif(32))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .shadow(color: .black.opacity(0.5), radius: 12, x: 0, y: 1)
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 280)
        .clipped()
    }

    private func keyFacts(person: PersonDetails) -> some View {
        var facts: [KeyFactsCard.Fact] = []
        if let birthday = person.birthday, !birthday.isEmpty {
            facts.append(.init(label: "Born", value: birthday))
        }
        if let place = person.placeOfBirth, !place.isEmpty {
            facts.append(.init(label: "Place", value: place))
        }
        return Group {
            if !facts.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    DetailSectionHeader(title: "Key facts")
                    KeyFactsCard(facts: facts)
                }
            }
        }
    }

    private func creditsSection(title: String, accent: String?, items: [MediaItem]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            DetailSectionHeader(title: title, accent: accent)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(items) { item in
                        NavigationLink {
                            MediaDetailView(item: item)
                        } label: {
                            SharedPosterCard(
                                posterPath: item.posterPath,
                                title: item.title,
                                subtitle: item.releaseDate.flatMap { $0.formatted(.dateTime.year()) },
                                width: 110
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    private func topMovieCredits(_ person: PersonDetails) -> [MediaItem]? {
        guard let cast = person.movieCredits?.cast else { return nil }
        return cast
            .map { $0.withType(.movie) }
            .sorted { ($0.voteAverage ?? 0) > ($1.voteAverage ?? 0) }
            .prefix(20)
            .map { $0 }
    }

    private func topTVCredits(_ person: PersonDetails) -> [MediaItem]? {
        guard let cast = person.tvCredits?.cast else { return nil }
        return cast
            .map { $0.withType(.tv) }
            .sorted { ($0.voteAverage ?? 0) > ($1.voteAverage ?? 0) }
            .prefix(20)
            .map { $0 }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            person = try await env.apiClient.personInfoDecoded(id: personID)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
