import Foundation

struct AppUser: Codable, Identifiable, Sendable {
    let id: String
    let username: String?
    let displayName: String?
    let email: String?
    let avatarURL: URL?
    let bio: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case uid
        case username
        case displayName = "display_name"
        case email
        case avatarURL = "avatar_url"
        case bio
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? container.decode(String.self, forKey: .id))
            ?? (try? container.decode(String.self, forKey: .userId))
            ?? (try? container.decode(String.self, forKey: .uid))
            ?? ""
        username = try container.decodeIfPresent(String.self, forKey: .username)
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName)
        email = try container.decodeIfPresent(String.self, forKey: .email)
        bio = try container.decodeIfPresent(String.self, forKey: .bio)
        if let urlString = try container.decodeIfPresent(String.self, forKey: .avatarURL) {
            avatarURL = URL(string: urlString)
        } else {
            avatarURL = nil
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(username, forKey: .username)
        try container.encodeIfPresent(displayName, forKey: .displayName)
        try container.encodeIfPresent(email, forKey: .email)
        try container.encodeIfPresent(bio, forKey: .bio)
        try container.encodeIfPresent(avatarURL?.absoluteString, forKey: .avatarURL)
    }
}
