import Foundation

enum OneDriveAPIError: Error, LocalizedError {
    case invalidURL
    case httpError(Int)
    case decodingFailed(Error)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "URLが無効です"
        case .httpError(let code): return "HTTPエラー: \(code)"
        case .decodingFailed(let e): return "レスポンス解析失敗: \(e.localizedDescription)"
        case .networkError(let e): return "ネットワークエラー: \(e.localizedDescription)"
        }
    }
}

private let kGraphBase = "https://graph.microsoft.com/v1.0"

final class OneDriveAPIService {
    static let shared = OneDriveAPIService()
    private let session = URLSession.shared
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        return d
    }()

    private init() {}

    private func makeRequest(path: String, token: String) throws -> URLRequest {
        guard let url = URL(string: kGraphBase + path) else { throw OneDriveAPIError.invalidURL }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return req
    }

    func listChildren(itemID: String? = nil, token: String) async throws -> [DriveItem] {
        let path: String
        if let id = itemID {
            path = "/me/drive/items/\(id)/children?$select=id,name,size,file,folder,lastModifiedDateTime,@microsoft.graph.downloadUrl&$top=100"
        } else {
            path = "/me/drive/root/children?$select=id,name,size,file,folder,lastModifiedDateTime,@microsoft.graph.downloadUrl&$top=100"
        }
        return try await fetchAll(path: path, token: token)
    }

    private func fetchAll(path: String, token: String) async throws -> [DriveItem] {
        var results: [DriveItem] = []
        var nextPath: String? = path

        while let currentPath = nextPath {
            let req = try makeRequest(path: currentPath, token: token)
            let (data, response) = try await session.data(for: req)

            guard let http = response as? HTTPURLResponse else { break }
            guard http.statusCode == 200 else { throw OneDriveAPIError.httpError(http.statusCode) }

            let list: DriveItemList
            do {
                list = try decoder.decode(DriveItemList.self, from: data)
            } catch {
                throw OneDriveAPIError.decodingFailed(error)
            }
            results.append(contentsOf: list.value)

            if let link = list.nextLink, let url = URL(string: link) {
                nextPath = url.path + (url.query.map { "?\($0)" } ?? "")
            } else {
                nextPath = nil
            }
        }
        return results
    }

    func downloadImageData(item: DriveItem, token: String) async throws -> Data {
        let urlString: String
        if let dl = item.downloadURL {
            urlString = dl
        } else {
            urlString = "\(kGraphBase)/me/drive/items/\(item.id)/content"
        }
        guard let url = URL(string: urlString) else { throw OneDriveAPIError.invalidURL }

        var req = URLRequest(url: url)
        if item.downloadURL == nil {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        do {
            let (data, response) = try await session.data(for: req)
            if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                throw OneDriveAPIError.httpError(http.statusCode)
            }
            return data
        } catch let e as OneDriveAPIError {
            throw e
        } catch {
            throw OneDriveAPIError.networkError(error)
        }
    }

    func driveInfo(token: String) async throws -> String {
        let req = try makeRequest(path: "/me/drive", token: token)
        let (data, _) = try await session.data(for: req)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        return json?["id"] as? String ?? "unknown"
    }
}
