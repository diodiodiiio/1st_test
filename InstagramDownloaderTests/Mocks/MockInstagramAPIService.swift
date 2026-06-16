import Foundation
@testable import InstagramDownloader

class MockInstagramAPIService: InstagramAPIServiceProtocol {
    var stubbedUser: InstagramUser?
    var stubbedMedia: [InstagramMedia] = []
    var stubbedMediaPages: [[InstagramMedia]] = []
    var shouldFail = false
    var error: Error = APIError.invalidResponse(statusCode: 500)

    var fetchUserProfileCallCount = 0
    var fetchUserMediaCallCount = 0
    var fetchAllMediaCallCount = 0
    var lastFetchedUserId: String?
    var lastAccessToken: String?

    func fetchUserProfile(userId: String, accessToken: String) async throws -> InstagramUser {
        fetchUserProfileCallCount += 1
        lastFetchedUserId = userId
        lastAccessToken = accessToken
        if shouldFail { throw error }
        guard let user = stubbedUser else { throw APIError.noData }
        return user
    }

    func fetchUserMedia(userId: String, accessToken: String, after: String?) async throws -> MediaListResponse {
        fetchUserMediaCallCount += 1
        if shouldFail { throw error }
        return MediaListResponse(data: stubbedMedia, paging: nil)
    }

    func fetchAllMedia(userId: String, accessToken: String, progressHandler: ((Int) -> Void)?) async throws -> [InstagramMedia] {
        fetchAllMediaCallCount += 1
        lastFetchedUserId = userId
        if shouldFail { throw error }
        progressHandler?(stubbedMedia.count)
        return stubbedMedia
    }
}
