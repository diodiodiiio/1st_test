import XCTest
@testable import YouTubeLikedExtractor

class YouTubeAPIServiceTests: XCTestCase {

    var sut: YouTubeAPIService!

    override func setUp() {
        super.setUp()
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [RoutingMockURLProtocol.self]
        sut = YouTubeAPIService(session: URLSession(configuration: config))
        RoutingMockURLProtocol.reset()
    }

    override func tearDown() {
        sut = nil
        RoutingMockURLProtocol.reset()
        super.tearDown()
    }

    // MARK: - Decoding

    func test_fetchLikedVideoItems_decodesSnippetAndContentDetails() async throws {
        RoutingMockURLProtocol.route("/playlistItems", json: """
        {
          "items": [
            {
              "snippet": {
                "publishedAt": "2024-02-15T10:00:00Z",
                "title": "Liked Video",
                "description": "A description",
                "thumbnails": { "high": { "url": "https://img/high.jpg" } }
              },
              "contentDetails": { "videoId": "abc123" }
            }
          ],
          "nextPageToken": "TOKEN2"
        }
        """)

        let page = try await sut.fetchLikedVideoItems(pageToken: nil, accessToken: "tok")

        XCTAssertEqual(page.items.count, 1)
        XCTAssertEqual(page.items[0].contentDetails.videoId, "abc123")
        XCTAssertEqual(page.items[0].snippet.thumbnails?.bestURL, "https://img/high.jpg")
        XCTAssertEqual(page.nextPageToken, "TOKEN2")
    }

    func test_fetchVideoDetails_decodesCategoryAndTopics() async throws {
        RoutingMockURLProtocol.route("/videos", json: """
        {
          "items": [
            {
              "id": "abc123",
              "snippet": { "title": "T", "description": "D", "categoryId": "10" },
              "topicDetails": { "topicCategories": ["https://en.wikipedia.org/wiki/Rock_music"] }
            }
          ]
        }
        """)

        let items = try await sut.fetchVideoDetails(ids: ["abc123"], accessToken: "tok")

        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].snippet.categoryId, "10")
        XCTAssertEqual(items[0].topicDetails?.topicCategories?.first, "https://en.wikipedia.org/wiki/Rock_music")
    }

    func test_fetchVideoDetails_emptyIds_shortCircuits() async throws {
        let items = try await sut.fetchVideoDetails(ids: [], accessToken: "tok")
        XCTAssertTrue(items.isEmpty)
    }

    func test_fetchCategoryMap_buildsIdToName() async throws {
        RoutingMockURLProtocol.route("/videoCategories", json: """
        {
          "items": [
            { "id": "10", "snippet": { "title": "Music" } },
            { "id": "20", "snippet": { "title": "Gaming" } }
          ]
        }
        """)

        let map = try await sut.fetchCategoryMap(regionCode: "JP", accessToken: "tok")

        XCTAssertEqual(map["10"], "Music")
        XCTAssertEqual(map["20"], "Gaming")
    }

    func test_apiError_isThrownFromErrorEnvelope() async throws {
        RoutingMockURLProtocol.route("/playlistItems", json: """
        { "error": { "code": 403, "message": "quotaExceeded" } }
        """, status: 403)

        do {
            _ = try await sut.fetchLikedVideoItems(pageToken: nil, accessToken: "tok")
            XCTFail("Expected APIError")
        } catch APIError.apiError(let message, let code) {
            XCTAssertEqual(message, "quotaExceeded")
            XCTAssertEqual(code, 403)
        }
    }

    // MARK: - Orchestration (date filtering + tag assembly)

    func test_fetchLikedVideos_filtersByDateRange_andAssemblesTags() async throws {
        // Playlist is newest-first: too-new, in-range, too-old (triggers stop).
        RoutingMockURLProtocol.route("/playlistItems", json: """
        {
          "items": [
            { "snippet": { "publishedAt": "2024-03-05T00:00:00Z", "title": "New", "description": "" },
              "contentDetails": { "videoId": "vidNew" } },
            { "snippet": { "publishedAt": "2024-02-15T00:00:00Z", "title": "In", "description": "" },
              "contentDetails": { "videoId": "vidIn" } },
            { "snippet": { "publishedAt": "2024-01-01T00:00:00Z", "title": "Old", "description": "" },
              "contentDetails": { "videoId": "vidOld" } }
          ]
        }
        """)
        RoutingMockURLProtocol.route("/videoCategories", json: """
        { "items": [ { "id": "10", "snippet": { "title": "Music" } } ] }
        """)
        RoutingMockURLProtocol.route("/videos", json: """
        {
          "items": [
            {
              "id": "vidIn",
              "snippet": { "title": "In Range", "description": "desc", "categoryId": "10" },
              "topicDetails": { "topicCategories": ["https://en.wikipedia.org/wiki/Pop_music"] }
            }
          ]
        }
        """)

        let from = Self.date("2024-02-01")
        let to = Self.date("2024-02-28")
        let videos = try await sut.fetchLikedVideos(from: from, to: to, regionCode: "JP",
                                                    accessToken: "tok", progressHandler: nil)

        XCTAssertEqual(videos.count, 1, "Only the in-range video should survive filtering")
        let video = try XCTUnwrap(videos.first)
        XCTAssertEqual(video.id, "vidIn")
        XCTAssertEqual(video.title, "In Range")
        XCTAssertEqual(video.url, "https://www.youtube.com/watch?v=vidIn")
        XCTAssertEqual(video.categoryName, "Music")
        XCTAssertEqual(video.tags, ["Music", "Pop music"])
    }

    // MARK: - deriveTags

    func test_deriveTags_dedupesCategoryAndTopicLabels() {
        let tags = YouTubeAPIService.deriveTags(
            categoryName: "Music",
            topicCategories: [
                "https://en.wikipedia.org/wiki/Music",       // dupes category
                "https://en.wikipedia.org/wiki/Pop_music"    // underscores -> space
            ]
        )
        XCTAssertEqual(tags, ["Music", "Pop music"])
    }

    func test_deriveTags_handlesNilCategoryAndTopics() {
        XCTAssertEqual(YouTubeAPIService.deriveTags(categoryName: nil, topicCategories: nil), [])
    }

    // MARK: - Helpers

    static func date(_ yyyyMMdd: String) -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.date(from: yyyyMMdd)!
    }
}

// MARK: - Routing mock URL protocol

/// A URLProtocol stub that returns different bodies depending on the request
/// path, so multi-endpoint orchestration can be exercised end-to-end.
class RoutingMockURLProtocol: URLProtocol {
    private struct Stub { let data: Data; let status: Int }
    private static var routes: [String: Stub] = [:]

    static func route(_ pathFragment: String, json: String, status: Int = 200) {
        routes[pathFragment] = Stub(data: Data(json.utf8), status: status)
    }

    static func reset() { routes.removeAll() }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let path = request.url?.path ?? ""
        let stub = RoutingMockURLProtocol.routes.first { path.contains($0.key) }?.value
            ?? Stub(data: Data("{}".utf8), status: 404)

        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: stub.status,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: stub.data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
