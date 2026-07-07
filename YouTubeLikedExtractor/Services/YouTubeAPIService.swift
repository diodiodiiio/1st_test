import Foundation

enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse(statusCode: Int)
    case apiError(message: String, code: Int)
    case decodingError(Error)
    case noData

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "URLが無効です"
        case .invalidResponse(let code):
            return "サーバーエラー (HTTP \(code))"
        case .apiError(let message, _):
            return message
        case .decodingError(let error):
            return "データの解析に失敗しました: \(error.localizedDescription)"
        case .noData:
            return "データがありません"
        }
    }
}

protocol YouTubeAPIServiceProtocol {
    /// One page of the "LL" liked-videos playlist (newest first).
    func fetchLikedVideoItems(pageToken: String?, accessToken: String) async throws -> PlaylistItemsResponse
    /// Video details (title/description/category/topics) for up to 50 ids.
    func fetchVideoDetails(ids: [String], accessToken: String) async throws -> [VideosResponse.VideoItem]
    /// Map of categoryId -> localized category name for a region.
    func fetchCategoryMap(regionCode: String, accessToken: String) async throws -> [String: String]
    /// High-level: liked videos within `[from, to]`, enriched with tags.
    func fetchLikedVideos(from: Date, to: Date, regionCode: String, accessToken: String,
                          progressHandler: ((Int) -> Void)?) async throws -> [LikedVideo]
}

extension YouTubeAPIServiceProtocol {
    func fetchLikedVideos(from: Date, to: Date, regionCode: String = "JP", accessToken: String,
                          progressHandler: ((Int) -> Void)? = nil) async throws -> [LikedVideo] {
        try await fetchLikedVideos(from: from, to: to, regionCode: regionCode,
                                   accessToken: accessToken, progressHandler: progressHandler)
    }
}

class YouTubeAPIService: YouTubeAPIServiceProtocol {
    static let shared = YouTubeAPIService()

    private let baseURL = "https://www.googleapis.com/youtube/v3"
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    private lazy var decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    // MARK: - Endpoints

    func fetchLikedVideoItems(pageToken: String?, accessToken: String) async throws -> PlaylistItemsResponse {
        var components = URLComponents(string: "\(baseURL)/playlistItems")!
        var queryItems = [
            URLQueryItem(name: "part", value: "snippet,contentDetails"),
            URLQueryItem(name: "playlistId", value: "LL"),
            URLQueryItem(name: "maxResults", value: "50")
        ]
        if let pageToken = pageToken {
            queryItems.append(URLQueryItem(name: "pageToken", value: pageToken))
        }
        components.queryItems = queryItems
        return try await get(components: components, accessToken: accessToken)
    }

    func fetchVideoDetails(ids: [String], accessToken: String) async throws -> [VideosResponse.VideoItem] {
        guard !ids.isEmpty else { return [] }
        var components = URLComponents(string: "\(baseURL)/videos")!
        components.queryItems = [
            URLQueryItem(name: "part", value: "snippet,topicDetails"),
            URLQueryItem(name: "id", value: ids.joined(separator: ",")),
            URLQueryItem(name: "maxResults", value: "50")
        ]
        let response: VideosResponse = try await get(components: components, accessToken: accessToken)
        return response.items
    }

    func fetchCategoryMap(regionCode: String, accessToken: String) async throws -> [String: String] {
        var components = URLComponents(string: "\(baseURL)/videoCategories")!
        components.queryItems = [
            URLQueryItem(name: "part", value: "snippet"),
            URLQueryItem(name: "regionCode", value: regionCode)
        ]
        let response: VideoCategoriesResponse = try await get(components: components, accessToken: accessToken)
        return Dictionary(response.items.map { ($0.id, $0.snippet.title) }) { first, _ in first }
    }

    // MARK: - Orchestration

    func fetchLikedVideos(from: Date, to: Date, regionCode: String, accessToken: String,
                          progressHandler: ((Int) -> Void)?) async throws -> [LikedVideo] {
        // 1. Page through the "LL" playlist (newest first), collecting items
        //    whose like-date falls inside [from, to]. Stop once we pass below
        //    the range since the playlist is ordered newest-first.
        var inRange: [(videoId: String, likedAt: Date, thumbnail: String?)] = []
        var pageToken: String? = nil
        pageLoop: repeat {
            let page = try await fetchLikedVideoItems(pageToken: pageToken, accessToken: accessToken)
            for item in page.items {
                let likedAt = item.snippet.publishedAt
                if likedAt > to { continue }        // too new — keep scanning
                if likedAt < from { break pageLoop } // older than range — done
                inRange.append((item.contentDetails.videoId, likedAt, item.snippet.thumbnails?.bestURL))
            }
            progressHandler?(inRange.count)
            pageToken = page.nextPageToken
        } while pageToken != nil

        guard !inRange.isEmpty else { return [] }

        // 2. Resolve category id -> name once.
        let categoryMap = (try? await fetchCategoryMap(regionCode: regionCode, accessToken: accessToken)) ?? [:]

        // 3. Fetch video details in batches of 50 and index by id.
        var detailsById: [String: VideosResponse.VideoItem] = [:]
        for batch in inRange.map(\.videoId).chunked(into: 50) {
            let items = try await fetchVideoDetails(ids: batch, accessToken: accessToken)
            for item in items { detailsById[item.id] = item }
        }

        // 4. Assemble, preserving the newest-first order of the playlist.
        return inRange.compactMap { entry in
            guard let detail = detailsById[entry.videoId] else { return nil }
            let categoryName = detail.snippet.categoryId.flatMap { categoryMap[$0] }
            let tags = Self.deriveTags(categoryName: categoryName,
                                       topicCategories: detail.topicDetails?.topicCategories)
            return LikedVideo(
                id: entry.videoId,
                title: detail.snippet.title,
                description: detail.snippet.description,
                url: "https://www.youtube.com/watch?v=\(entry.videoId)",
                thumbnailURL: detail.snippet.thumbnails?.bestURL ?? entry.thumbnail,
                likedAt: entry.likedAt,
                categoryId: detail.snippet.categoryId,
                categoryName: categoryName,
                tags: tags
            )
        }
    }

    /// Build the tag list from the resolved category plus the trailing labels
    /// of any `topicDetails.topicCategories` Wikipedia URLs, de-duplicated.
    static func deriveTags(categoryName: String?, topicCategories: [String]?) -> [String] {
        var tags: [String] = []
        if let categoryName = categoryName { tags.append(categoryName) }
        for urlString in topicCategories ?? [] {
            let label = urlString
                .split(separator: "/").last
                .map { $0.replacingOccurrences(of: "_", with: " ") } ?? ""
            if !label.isEmpty { tags.append(label) }
        }
        // De-duplicate while preserving order.
        var seen = Set<String>()
        return tags.filter { seen.insert($0).inserted }
    }

    // MARK: - Networking

    private func get<T: Decodable>(components: URLComponents, accessToken: String) async throws -> T {
        guard let url = components.url else { throw APIError.invalidURL }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data)
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }

    private func validateResponse(_ response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse(statusCode: -1)
        }
        guard httpResponse.statusCode == 200 else {
            if let apiError = try? JSONDecoder().decode(GoogleAPIErrorResponse.self, from: data) {
                throw APIError.apiError(message: apiError.error.message, code: apiError.error.code)
            }
            throw APIError.invalidResponse(statusCode: httpResponse.statusCode)
        }
    }
}

extension Array {
    /// Split into consecutive sub-arrays of at most `size` elements.
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
