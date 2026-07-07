import XCTest
@testable import YouTubeLikedExtractor

@MainActor
class LikedVideosViewModelTests: XCTestCase {

    var mockAPI: MockYouTubeAPIService!
    var authService: GoogleAuthService!
    var sut: LikedVideosViewModel!

    override func setUp() async throws {
        try await super.setUp()
        mockAPI = MockYouTubeAPIService()
        // Preload a non-expired access token so fetch() skips the network.
        UserDefaults.standard.set("test_token", forKey: "yt_access_token")
        UserDefaults.standard.set(Date.distantFuture, forKey: "yt_token_expiry")
        authService = GoogleAuthService()
        sut = LikedVideosViewModel(apiService: mockAPI, authService: authService)
    }

    override func tearDown() async throws {
        UserDefaults.standard.removeObject(forKey: "yt_access_token")
        UserDefaults.standard.removeObject(forKey: "yt_token_expiry")
        sut = nil
        mockAPI = nil
        authService = nil
        try await super.tearDown()
    }

    private func makeVideo(id: String, tags: [String]) -> LikedVideo {
        LikedVideo(id: id, title: "Title \(id)", description: "desc", url: "https://youtube.com/watch?v=\(id)",
                   thumbnailURL: nil, likedAt: Date(), categoryId: nil, categoryName: nil, tags: tags)
    }

    // MARK: - Default range

    func test_init_defaultsToTrailing30Days() {
        let days = Calendar.current.dateComponents([.day], from: sut.startDate, to: sut.endDate).day ?? 0
        XCTAssertEqual(days, 30)
    }

    // MARK: - fetch

    func test_fetch_populatesVideosAndSuccessMessage() async {
        mockAPI.stubbedVideos = [makeVideo(id: "1", tags: ["Music"])]

        await sut.fetch()

        XCTAssertEqual(mockAPI.fetchLikedVideosCallCount, 1)
        XCTAssertEqual(sut.videos.count, 1)
        XCTAssertEqual(mockAPI.lastAccessToken, "test_token")
        XCTAssertNotNil(sut.successMessage)
        XCTAssertNil(sut.errorMessage)
        XCTAssertFalse(sut.isLoading)
    }

    func test_fetch_setsWholeDayRange() async {
        mockAPI.stubbedVideos = []
        await sut.fetch()

        let calendar = Calendar.current
        XCTAssertEqual(calendar.component(.hour, from: mockAPI.lastFrom!), 0)
        XCTAssertEqual(calendar.component(.hour, from: mockAPI.lastTo!), 23)
    }

    func test_fetch_apiError_setsErrorMessage() async {
        mockAPI.shouldFail = true

        await sut.fetch()

        XCTAssertNotNil(sut.errorMessage)
        XCTAssertTrue(sut.videos.isEmpty)
    }

    // MARK: - Tag filtering

    func test_allTags_areDistinctAndSorted() {
        sut.videos = [
            makeVideo(id: "1", tags: ["Music", "Pop"]),
            makeVideo(id: "2", tags: ["Gaming", "Music"])
        ]
        XCTAssertEqual(sut.allTags, ["Gaming", "Music", "Pop"])
    }

    func test_filteredVideos_appliesSelectedTag() {
        sut.videos = [
            makeVideo(id: "1", tags: ["Music"]),
            makeVideo(id: "2", tags: ["Gaming"])
        ]
        sut.selectedTag = "Gaming"
        XCTAssertEqual(sut.filteredVideos.map(\.id), ["2"])
    }

    func test_filteredVideos_nilTagReturnsAll() {
        sut.videos = [makeVideo(id: "1", tags: ["Music"]), makeVideo(id: "2", tags: ["Gaming"])]
        sut.selectedTag = nil
        XCTAssertEqual(sut.filteredVideos.count, 2)
    }
}
