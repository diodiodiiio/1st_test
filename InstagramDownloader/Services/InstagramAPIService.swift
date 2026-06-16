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

protocol InstagramAPIServiceProtocol {
    func fetchUserProfile(userId: String, accessToken: String) async throws -> InstagramUser
    func fetchUserMedia(userId: String, accessToken: String, after: String?) async throws -> MediaListResponse
    func fetchAllMedia(userId: String, accessToken: String, progressHandler: ((Int) -> Void)?) async throws -> [InstagramMedia]
}

extension InstagramAPIServiceProtocol {
    func fetchAllMedia(userId: String, accessToken: String, progressHandler: ((Int) -> Void)? = nil) async throws -> [InstagramMedia] {
        try await fetchAllMedia(userId: userId, accessToken: accessToken, progressHandler: progressHandler)
    }
}

class InstagramAPIService: InstagramAPIServiceProtocol {
    static let shared = InstagramAPIService()

    private let baseURL = "https://graph.instagram.com"
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchUserProfile(userId: String, accessToken: String) async throws -> InstagramUser {
        let fields = "id,username,name,biography,followers_count,follows_count,media_count,profile_picture_url,website"
        var components = URLComponents(string: "\(baseURL)/\(userId)")!
        components.queryItems = [
            URLQueryItem(name: "fields", value: fields),
            URLQueryItem(name: "access_token", value: accessToken)
        ]

        guard let url = components.url else { throw APIError.invalidURL }

        let (data, response) = try await session.data(from: url)
        try validateResponse(response, data: data)

        do {
            return try JSONDecoder().decode(InstagramUser.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }

    func fetchUserMedia(userId: String, accessToken: String, after: String? = nil) async throws -> MediaListResponse {
        let fields = "id,media_type,media_url,thumbnail_url,timestamp,caption,permalink"
        var components = URLComponents(string: "\(baseURL)/\(userId)/media")!
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "fields", value: fields),
            URLQueryItem(name: "access_token", value: accessToken),
            URLQueryItem(name: "limit", value: "50")
        ]
        if let after = after {
            queryItems.append(URLQueryItem(name: "after", value: after))
        }
        components.queryItems = queryItems

        guard let url = components.url else { throw APIError.invalidURL }

        let (data, response) = try await session.data(from: url)
        try validateResponse(response, data: data)

        do {
            return try JSONDecoder().decode(MediaListResponse.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }

    func fetchAllMedia(userId: String, accessToken: String, progressHandler: ((Int) -> Void)? = nil) async throws -> [InstagramMedia] {
        var allMedia: [InstagramMedia] = []
        var cursor: String? = nil

        repeat {
            let response = try await fetchUserMedia(userId: userId, accessToken: accessToken, after: cursor)
            allMedia.append(contentsOf: response.data)
            progressHandler?(allMedia.count)

            guard let next = response.paging?.next else { break }
            _ = next
            cursor = response.paging?.cursors?.after
        } while cursor != nil

        return allMedia
    }

    private func validateResponse(_ response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse(statusCode: -1)
        }

        guard httpResponse.statusCode == 200 else {
            if let apiError = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                throw APIError.apiError(message: apiError.error.message, code: apiError.error.code)
            }
            throw APIError.invalidResponse(statusCode: httpResponse.statusCode)
        }
    }

    private struct APIErrorResponse: Codable {
        let error: APIErrorDetail

        struct APIErrorDetail: Codable {
            let message: String
            let type: String
            let code: Int
        }
    }
}
