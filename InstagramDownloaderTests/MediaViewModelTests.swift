import XCTest
@testable import InstagramDownloader

@MainActor
class MediaViewModelTests: XCTestCase {

    var sut: MediaViewModel!
    var mockAPI: MockInstagramAPIService!
    var mockDownload: SpyMediaDownloadService!

    override func setUp() async throws {
        try await super.setUp()
        mockAPI = MockInstagramAPIService()
        mockDownload = SpyMediaDownloadService()
        sut = MediaViewModel(apiService: mockAPI, downloadService: mockDownload)
        sut.configure(userId: "user123", accessToken: "token_abc")
    }

    override func tearDown() async throws {
        sut = nil
        mockAPI = nil
        mockDownload = nil
        try await super.tearDown()
    }

    // MARK: - fetchAllPosts

    func test_fetchAllPosts_success_populatesMediaItems() async {
        mockAPI.stubbedMedia = makeMediaList(count: 5)

        await sut.fetchAllPosts()

        XCTAssertEqual(sut.mediaItems.count, 5)
        XCTAssertNil(sut.errorMessage)
        XCTAssertFalse(sut.isLoading)
    }

    func test_fetchAllPosts_failure_setsErrorMessage() async {
        mockAPI.shouldFail = true

        await sut.fetchAllPosts()

        XCTAssertTrue(sut.mediaItems.isEmpty)
        XCTAssertNotNil(sut.errorMessage)
        XCTAssertFalse(sut.isLoading)
    }

    func test_fetchAllPosts_passesCorrectCredentials() async {
        mockAPI.stubbedMedia = []

        await sut.fetchAllPosts()

        XCTAssertEqual(mockAPI.lastFetchedUserId, "user123")
    }

    func test_fetchAllPosts_updatesProgressCount() async {
        mockAPI.stubbedMedia = makeMediaList(count: 10)

        await sut.fetchAllPosts()

        XCTAssertEqual(sut.fetchedCount, 10)
    }

    func test_fetchAllPosts_isLoadingDuringFetch() async {
        mockAPI.stubbedMedia = makeMediaList(count: 3)

        // After completion, isLoading must be false
        await sut.fetchAllPosts()
        XCTAssertFalse(sut.isLoading)
    }

    func test_fetchAllPosts_clearsErrorOnRetry() async {
        mockAPI.shouldFail = true
        await sut.fetchAllPosts()
        XCTAssertNotNil(sut.errorMessage)

        mockAPI.shouldFail = false
        mockAPI.stubbedMedia = makeMediaList(count: 2)
        await sut.fetchAllPosts()

        XCTAssertNil(sut.errorMessage)
        XCTAssertEqual(sut.mediaItems.count, 2)
    }

    // MARK: - downloadSingle

    func test_downloadSingle_callsDownloadService() async {
        let media = makeMedia(id: "m1", type: .image)

        await sut.downloadSingle(media)

        XCTAssertEqual(mockDownload.downloadedIds, ["m1"])
    }

    func test_downloadSingle_videoMedia_isPassedCorrectly() async {
        let video = makeMedia(id: "v1", type: .video)

        await sut.downloadSingle(video)

        XCTAssertEqual(mockDownload.downloadedIds.first, "v1")
    }

    // MARK: - downloadAll

    func test_downloadAll_withNoMediaItems_doesNothing() async {
        await sut.downloadAll()

        XCTAssertNil(sut.successMessage)
        XCTAssertTrue(mockDownload.downloadedIds.isEmpty)
    }

    func test_downloadAll_downloadsAllUndownloadedItems() async {
        sut.mediaItems = makeMediaList(count: 3)

        await sut.downloadAll()

        XCTAssertEqual(mockDownload.downloadedIds.count, 3)
        XCTAssertNotNil(sut.successMessage)
    }

    func test_downloadAll_skipsAlreadyCompletedItems() async {
        sut.mediaItems = makeMediaList(count: 4)
        mockDownload._completedIds = ["0", "1"]

        await sut.downloadAll()

        // Only ids "2" and "3" should be downloaded
        XCTAssertEqual(mockDownload.downloadedIds.count, 2)
        XCTAssertFalse(mockDownload.downloadedIds.contains("0"))
        XCTAssertFalse(mockDownload.downloadedIds.contains("1"))
    }

    func test_downloadAll_whenAllAlreadyDownloaded_setsAlreadyDoneMessage() async {
        sut.mediaItems = [makeMedia(id: "x", type: .image)]
        mockDownload._completedIds = ["x"]

        await sut.downloadAll()

        XCTAssertEqual(sut.successMessage, "すべてダウンロード済みです")
        XCTAssertTrue(mockDownload.downloadedIds.isEmpty)
    }

    func test_downloadAll_progressResetAfterCompletion() async {
        sut.mediaItems = makeMediaList(count: 2)

        await sut.downloadAll()

        XCTAssertEqual(sut.downloadProgress.completed, 0)
        XCTAssertEqual(sut.downloadProgress.total, 0)
    }

    // MARK: - Helpers

    func makeMedia(id: String, type: InstagramMedia.MediaType) -> InstagramMedia {
        InstagramMedia(
            id: id,
            mediaType: type,
            mediaUrl: "https://example.com/\(id).jpg",
            thumbnailUrl: "https://example.com/thumb_\(id).jpg",
            timestamp: "2024-01-01T00:00:00+0000",
            caption: "Caption for \(id)",
            permalink: nil
        )
    }

    func makeMediaList(count: Int) -> [InstagramMedia] {
        (0..<count).map { makeMedia(id: "\($0)", type: .image) }
    }
}

// MARK: - Spy MediaDownloadService

class SpyMediaDownloadService: MediaDownloadService {
    var downloadedIds: [String] = []
    var _completedIds: Set<String> = []

    override var completedIds: Set<String> {
        get { _completedIds }
        set { _completedIds = newValue }
    }

    @MainActor
    override func downloadMedia(_ media: InstagramMedia) async {
        downloadedIds.append(media.id)
        _completedIds.insert(media.id)
    }

    @MainActor
    override func downloadAll(_ mediaItems: [InstagramMedia], progressHandler: ((Int, Int) -> Void)? = nil) async {
        let toDownload = mediaItems.filter { !_completedIds.contains($0.id) }
        for (i, media) in toDownload.enumerated() {
            await downloadMedia(media)
            progressHandler?(i + 1, toDownload.count)
        }
    }

    override func isCompleted(_ mediaId: String) -> Bool {
        _completedIds.contains(mediaId)
    }

    override func hasFailed(_ mediaId: String) -> Bool { false }
    override func isDownloading(_ mediaId: String) -> Bool { false }
}
