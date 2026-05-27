import Foundation

/// Thin URLSession-based client for the Release Radar backend.
/// All endpoints are documented at https://api.releaseradar.co/openapi.json
actor APIClient {
    static let defaultBaseURL = URL(string: "https://api.releaseradar.co")!

    private let baseURL: URL
    private let session: URLSession
    private let auth: AuthProvider
    let decoder: JSONDecoder
    let encoder: JSONEncoder

    init(
        baseURL: URL = APIClient.defaultBaseURL,
        auth: AuthProvider,
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.session = session
        self.auth = auth
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder
    }

    // MARK: - Search

    /// Convenience for the simple "all results interleaved" view. Most callers
    /// should prefer `searchAll(query:)` so they can show each category.
    func search(query: String) async throws -> [MediaItem] {
        let response = try await searchAll(query: query)
        return response.movies + response.shows
    }

    /// Full multi-category search — movies, shows, people, collections.
    func searchAll(query: String) async throws -> SearchAllResults {
        try await get("/search", query: [.init(name: "query", value: query)])
    }

    func trending() async throws -> [MediaItem] {
        let response: SearchResponse = try await get("/search/multi/trending")
        return response.results
    }

    func trending(type: ContentType, page: Int) async throws -> TrendingResponse {
        try await get(
            "/search/\(type.rawValue)/trending",
            query: [.init(name: "page", value: "\(page)")]
        )
    }

    func multiTrending() async throws -> MultiResponse {
        try await get("/search/multi/trending")
    }

    func multiPopular() async throws -> MultiResponse {
        try await get("/search/multi/popular")
    }

    func multiTopRated() async throws -> MultiResponse {
        try await get("/search/multi/top-rated")
    }

    func airingToday() async throws -> [MediaItem] {
        let r: TrendingResponse = try await get("/search/tv/airing-today")
        return r.results.map { $0.withType(.tv) }
    }

    func nowPlaying() async throws -> [MediaItem] {
        let r: TrendingResponse = try await get("/search/movie/now-playing")
        return r.results.map { $0.withType(.movie) }
    }

    func upcoming(type: ContentType, from: Date, to: Date) async throws -> [MediaItem] {
        try await upcomingPaged(type: type, from: from, to: to, page: 1).results
    }

    /// Page-aware upcoming fetch. Returns items + totalPages so the caller
    /// can drive a Previous/Next pager. Items already have `contentType`
    /// forced to the requested type.
    func upcomingPaged(
        type: ContentType,
        from: Date,
        to: Date,
        page: Int = 1
    ) async throws -> (results: [MediaItem], totalPages: Int) {
        let f = MediaItem.tmdbDateFormatter
        let r: TrendingResponse = try await get(
            "/search/\(type.rawValue)/upcoming",
            query: [
                .init(name: "min_date", value: f.string(from: from)),
                .init(name: "max_date", value: f.string(from: to)),
                .init(name: "page", value: "\(page)")
            ]
        )
        return (r.results.map { $0.withType(type) }, max(r.totalPages, 1))
    }

    // MARK: - Watchlist

    /// Backend returns `{ movies, shows }`. Combines both into a single list and
    /// forces `contentType` per array so downstream filtering is reliable.
    func watchlist() async throws -> [MediaItem] {
        let response: MultiResponse = try await get("/watchlist")
        return response.movies + response.shows
    }

    @discardableResult
    func addToWatchlist(_ item: MediaItem) async throws -> Data {
        try await send(
            "/watchlist/add",
            method: "POST",
            body: ContentRef(content_type: item.contentType.rawValue, content_id: item.id)
        )
    }

    @discardableResult
    func removeFromWatchlist(_ item: MediaItem) async throws -> Data {
        try await send(
            "/watchlist/remove",
            method: "DELETE",
            body: ContentRef(content_type: item.contentType.rawValue, content_id: item.id)
        )
    }

    // MARK: - Watched

    func watched() async throws -> [MediaItem] {
        let response: MultiResponse = try await get("/watched")
        return response.movies + response.shows
    }

    @discardableResult
    func removeFromWatched(_ item: MediaItem) async throws -> Data {
        try await send(
            "/watched/remove",
            method: "DELETE",
            body: ContentRef(content_type: item.contentType.rawValue, content_id: item.id)
        )
    }

    // MARK: - Detail pages

    func movieInfo(id: Int) async throws -> MovieDetails {
        try await get("/movies/\(id)/info")
    }

    func showInfo(id: Int) async throws -> ShowDetails {
        try await get("/tv/\(id)/full")
    }

    // MARK: - Calendar

    func calendar(from: Date, to: Date) async throws -> CalendarResponse {
        let formatter = MediaItem.tmdbDateFormatter
        return try await get(
            "/calendar",
            query: [
                .init(name: "from_date", value: formatter.string(from: from)),
                .init(name: "to_date", value: formatter.string(from: to))
            ]
        )
    }

    // MARK: - Currently watching

    func currentlyWatching() async throws -> (showIDs: Set<Int>, movieIDs: Set<Int>) {
        let response: CurrentlyWatchingResponse = try await get("/currently-watching")
        return (Set(response.shows.map(\.id)), Set(response.movies.map(\.id)))
    }

    // MARK: - User

    func currentUser() async throws -> AppUser {
        try await get("/user/me")
    }

    // MARK: - Core request

    /// GET a path, decoding into `T`.
    func get<T: Decodable>(
        _ path: String,
        query: [URLQueryItem] = []
    ) async throws -> T {
        let request = try await makeRequest(path: path, method: "GET", query: query, body: nil as EmptyBody?)
        let data = try await perform(request)
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decoding(error)
        }
    }

    /// GET a path and return the raw response body. Use this when the response is
    /// a TMDB-style passthrough that we don't yet have a typed model for.
    func getData(
        _ path: String,
        query: [URLQueryItem] = []
    ) async throws -> Data {
        let request = try await makeRequest(path: path, method: "GET", query: query, body: nil as EmptyBody?)
        return try await perform(request)
    }

    /// Send a request with a JSON body, returning the raw response body.
    @discardableResult
    func send<Body: Encodable>(
        _ path: String,
        method: String,
        query: [URLQueryItem] = [],
        body: Body
    ) async throws -> Data {
        let request = try await makeRequest(path: path, method: method, query: query, body: body)
        return try await perform(request)
    }

    /// Send a request without a body.
    @discardableResult
    func send(
        _ path: String,
        method: String,
        query: [URLQueryItem] = []
    ) async throws -> Data {
        let request = try await makeRequest(path: path, method: method, query: query, body: nil as EmptyBody?)
        return try await perform(request)
    }

    /// Send a request with a JSON body and decode the response into `T`.
    func sendDecoded<Body: Encodable, T: Decodable>(
        _ path: String,
        method: String,
        query: [URLQueryItem] = [],
        body: Body
    ) async throws -> T {
        let data = try await send(path, method: method, query: query, body: body)
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decoding(error)
        }
    }

    /// Send a request without a body and decode the response into `T`.
    func sendDecoded<T: Decodable>(
        _ path: String,
        method: String,
        query: [URLQueryItem] = []
    ) async throws -> T {
        let data = try await send(path, method: method, query: query)
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decoding(error)
        }
    }

    /// Upload a file via multipart/form-data and return the raw response body.
    /// Convenience wrappers exist for the common case of reading from disk.
    func uploadMultipart(
        path: String,
        method: String,
        fileURL: URL,
        fieldName: String = "file"
    ) async throws -> Data {
        let data = try Data(contentsOf: fileURL)
        let mime = Self.mimeType(for: fileURL.pathExtension)
        return try await uploadMultipart(
            path: path,
            method: method,
            fileData: data,
            filename: fileURL.lastPathComponent,
            mimeType: mime,
            fieldName: fieldName
        )
    }

    func uploadMultipart(
        path: String,
        method: String,
        fileData: Data,
        filename: String,
        mimeType: String,
        fieldName: String = "file"
    ) async throws -> Data {
        let boundary = "Boundary-\(UUID().uuidString)"
        guard let url = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)?.url else {
            throw APIError.invalidURL
        }

        var body = Data()
        body.appendString("--\(boundary)\r\n")
        body.appendString("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(filename)\"\r\n")
        body.appendString("Content-Type: \(mimeType)\r\n\r\n")
        body.append(fileData)
        body.appendString("\r\n--\(boundary)--\r\n")

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        if let token = try await auth.currentIDToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return try await perform(request)
    }

    private static func mimeType(for pathExtension: String) -> String {
        switch pathExtension.lowercased() {
        case "csv": "text/csv"
        case "zip": "application/zip"
        case "json": "application/json"
        case "txt": "text/plain"
        default: "application/octet-stream"
        }
    }

    private func makeRequest<Body: Encodable>(
        path: String,
        method: String,
        query: [URLQueryItem],
        body: Body?
    ) async throws -> URLRequest {
        guard var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false) else {
            throw APIError.invalidURL
        }
        if !query.isEmpty {
            components.queryItems = query
        }
        guard let url = components.url else { throw APIError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = method
        // The backend doesn't send cache-control headers, so URLSession's
        // default policy was returning stale data for write-then-read flows
        // (e.g. mark watched → open detail → status query reads stale value).
        // Force every request to hit the network.
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try encoder.encode(body)
        }

        if let token = try await auth.currentIDToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    private func perform(_ request: URLRequest) async throws -> Data {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.transport(error)
        }
        guard let http = response as? HTTPURLResponse else {
            throw APIError.http(status: -1, body: nil)
        }
        switch http.statusCode {
        case 200..<300:
            return data
        case 401, 403:
            throw APIError.unauthorized
        default:
            let body = String(data: data, encoding: .utf8)
            throw APIError.http(status: http.statusCode, body: body)
        }
    }
}

struct EmptyBody: Encodable {}

private extension Data {
    mutating func appendString(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}

/// Standard `{ content_type, content_id }` body used by most tracking endpoints.
struct ContentRef: Encodable {
    let content_type: String
    let content_id: Int

    init(_ item: MediaItem) {
        self.content_type = item.contentType.rawValue
        self.content_id = item.id
    }

    init(content_type: String, content_id: Int) {
        self.content_type = content_type
        self.content_id = content_id
    }

    init(type: ContentType, id: Int) {
        self.content_type = type.rawValue
        self.content_id = id
    }
}

private struct CurrentlyWatchingResponse: Decodable {
    let shows: [IDOnly]
    let movies: [IDOnly]
    struct IDOnly: Decodable { let id: Int }
}
