import Foundation

enum ContentType: String, Codable, CaseIterable, Identifiable, Sendable {
    case movie
    case tv

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .movie: "Movie"
        case .tv: "TV"
        }
    }
}
