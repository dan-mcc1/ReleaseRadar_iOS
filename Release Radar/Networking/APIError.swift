import Foundation

enum APIError: LocalizedError {
    case invalidURL
    case unauthorized
    case http(status: Int, body: String?)
    case decoding(Error)
    case transport(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The request URL was invalid."
        case .unauthorized:
            return "You need to sign in to continue."
        case .http(let status, let body):
            if let body, !body.isEmpty {
                return "Server error (\(status)): \(body)"
            }
            return "Server error (\(status))."
        case .decoding(let error):
            return "Could not read the server's response: \(error.localizedDescription)"
        case .transport(let error):
            return error.localizedDescription
        }
    }
}
