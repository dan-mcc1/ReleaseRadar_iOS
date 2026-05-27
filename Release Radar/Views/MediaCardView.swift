import SwiftUI
import NukeUI

/// Compact row used in lists for a movie or TV show.
struct MediaCardView: View {
    let item: MediaItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            poster
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.headline)
                    .lineLimit(2)
                HStack(spacing: 8) {
                    Text(item.contentType.displayName)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.15), in: Capsule())
                    if let year = releaseYear {
                        Text(year)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let rating = item.voteAverage, rating > 0 {
                        Label(String(format: "%.1f", rating), systemImage: "star.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                if let overview = item.overview, !overview.isEmpty {
                    Text(overview)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var releaseYear: String? {
        guard let date = item.releaseDate else { return nil }
        return Calendar(identifier: .gregorian).component(.year, from: date).description
    }

    @ViewBuilder
    private var poster: some View {
        LazyImage(url: item.posterURL) { state in
            if let image = state.image {
                image.resizable().scaledToFill()
            } else if state.error != nil {
                placeholder(systemImage: "photo")
            } else {
                placeholder(systemImage: nil)
            }
        }
        .frame(width: 72, height: 108)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func placeholder(systemImage: String?) -> some View {
        ZStack {
            Color.secondary.opacity(0.15)
            if let systemImage {
                Image(systemName: systemImage)
                    .foregroundStyle(.secondary)
            } else {
                ProgressView()
            }
        }
    }
}
