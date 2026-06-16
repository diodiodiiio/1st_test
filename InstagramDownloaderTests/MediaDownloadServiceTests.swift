import XCTest
@testable import InstagramDownloader

class MediaDownloadServiceTests: XCTestCase {

    var sut: MediaDownloadService!

    override func setUp() {
        super.setUp()
        sut = MediaDownloadService()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - Initial state

    func test_initialState_noCompletedIds() {
        XCTAssertTrue(sut.completedIds.isEmpty)
    }

    func test_initialState_noDownloadingIds() {
        XCTAssertTrue(sut.downloadingIds.isEmpty)
    }

    func test_initialState_noFailedIds() {
        XCTAssertTrue(sut.failedIds.isEmpty)
    }

    // MARK: - Status queries

    func test_isCompleted_returnsFalseForUnknownId() {
        XCTAssertFalse(sut.isCompleted("unknown"))
    }

    func test_isDownloading_returnsFalseForUnknownId() {
        XCTAssertFalse(sut.isDownloading("unknown"))
    }

    func test_hasFailed_returnsFalseForUnknownId() {
        XCTAssertFalse(sut.hasFailed("unknown"))
    }

    func test_getLocalURL_returnsNilWhenNotDownloaded() {
        XCTAssertNil(sut.getLocalURL(for: "nonexistent_media_id_xyz"))
    }

    // MARK: - downloadMedia with no URL

    func test_downloadMedia_withNilURL_marksAsFailed() async {
        let media = InstagramMedia(
            id: "no_url_media",
            mediaType: .image,
            mediaUrl: nil,
            thumbnailUrl: nil,
            timestamp: "2024-01-01T00:00:00+0000",
            caption: nil,
            permalink: nil
        )

        await sut.downloadMedia(media)

        await MainActor.run {
            XCTAssertTrue(sut.hasFailed("no_url_media"))
            XCTAssertFalse(sut.isCompleted("no_url_media"))
            XCTAssertFalse(sut.isDownloading("no_url_media"))
        }
    }

    func test_downloadMedia_withInvalidURLString_marksAsFailed() async {
        let media = InstagramMedia(
            id: "bad_url_media",
            mediaType: .image,
            mediaUrl: "not a valid url !!!",
            thumbnailUrl: nil,
            timestamp: "2024-01-01T00:00:00+0000",
            caption: nil,
            permalink: nil
        )

        await sut.downloadMedia(media)

        await MainActor.run {
            XCTAssertTrue(sut.hasFailed("bad_url_media"))
        }
    }

    // MARK: - clearAll

    func test_clearAll_removesCompletedAndFailedState() throws {
        Task { @MainActor in
            sut.completedIds = ["a", "b"]
            sut.failedIds = ["c"]
        }

        try sut.clearAll()

        XCTAssertTrue(sut.completedIds.isEmpty)
        XCTAssertTrue(sut.failedIds.isEmpty)
    }

    // MARK: - Deduplication

    func test_downloadMedia_alreadyDownloading_doesNotStartAgain() async {
        let media = InstagramMedia(
            id: "dup_media",
            mediaType: .image,
            mediaUrl: nil,
            thumbnailUrl: nil,
            timestamp: "2024-01-01T00:00:00+0000",
            caption: nil,
            permalink: nil
        )

        // Manually mark as downloading
        await MainActor.run {
            sut.downloadingIds.insert("dup_media")
        }

        // Calling downloadMedia should return early without changing state further
        await sut.downloadMedia(media)

        await MainActor.run {
            // Should still be in downloading state (not failed or completed)
            XCTAssertTrue(sut.isDownloading("dup_media"))
            XCTAssertFalse(sut.isCompleted("dup_media"))
            XCTAssertFalse(sut.hasFailed("dup_media"))
        }
    }
}
