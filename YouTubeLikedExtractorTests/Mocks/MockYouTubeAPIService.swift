import Foundation
@testable import YouTubeLikedExtractor

class MockYouTubeAPIService: YouTubeAPIServiceProtocol {
    var stubbedVideos: [LikedVideo] = []
    var stubbedPlaylistResponse = PlaylistItemsResponse(items: [], nextPageToken: nil, pageInfo: nil)
    var stubbedVideoItems: [VideosResponse.VideoItem] = []
    var stubbedCategoryMap: [String: String] = [:]
    var shouldFail = false
    var error: Error = APIError.invalidResponse(statusCode: 500)

    var fetchLikedVideosCallCount = 0
    var lastFrom: Date?
    var lastTo: Date?
    var lastAccessToken: String?

    func fetchLikedVideoItems(pageToken: String?, accessToken: String) async throws -> PlaylistItemsResponse {
        if shouldFail { throw error }
        return stubbedPlaylistResponse
    }

    func fetchVideoDetails(ids: [String], accessToken: String) async throws -> [VideosResponse.VideoItem] {
        if shouldFail { throw error }
        return stubbedVideoItems
    }

    func fetchCategoryMap(regionCode: String, accessToken: String) async throws -> [String: String] {
        if shouldFail { throw error }
        return stubbedCategoryMap
    }

    func fetchLikedVideos(from: Date, to: Date, regionCode: String, accessToken: String,
                          progressHandler: ((Int) -> Void)?) async throws -> [LikedVideo] {
        fetchLikedVideosCallCount += 1
        lastFrom = from
        lastTo = to
        lastAccessToken = accessToken
        if shouldFail { throw error }
        progressHandler?(stubbedVideos.count)
        return stubbedVideos
    }
}
