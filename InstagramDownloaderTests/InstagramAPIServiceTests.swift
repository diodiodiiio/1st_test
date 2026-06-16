import XCTest
@testable import InstagramDownloader

class InstagramAPIServiceTests: XCTestCase {

    var sut: InstagramAPIService!
    var mockSession: MockURLSession!

    override func setUp() {
        super.setUp()
        mockSession = MockURLSession()
        sut = InstagramAPIService(session: mockSession.session)
    }

    override func tearDown() {
        sut = nil
        mockSession = nil
        super.tearDown()
    }

    // MARK: - fetchUserProfile

    func test_fetchUserProfile_success_decodesUser() async throws {
        let json = """
        {
            "id": "12345",
            "username": "testuser",
            "name": "Test User",
            "biography": "Test bio",
            "followers_count": 1000,
            "follows_count": 500,
            "media_count": 42,
            "profile_picture_url": null,
            "website": null
        }
        """
        mockSession.stub(data: json.data(using: .utf8)!, statusCode: 200)

        let user = try await sut.fetchUserProfile(userId: "me", accessToken: "token")

        XCTAssertEqual(user.id, "12345")
        XCTAssertEqual(user.username, "testuser")
        XCTAssertEqual(user.name, "Test User")
        XCTAssertEqual(user.followersCount, 1000)
        XCTAssertEqual(user.mediaCount, 42)
    }

    func test_fetchUserProfile_apiError_throwsAPIError() async throws {
        let json = """
        {
            "error": {
                "message": "Invalid access token",
                "type": "OAuthException",
                "code": 190
            }
        }
        """
        mockSession.stub(data: json.data(using: .utf8)!, statusCode: 400)

        do {
            _ = try await sut.fetchUserProfile(userId: "me", accessToken: "bad_token")
            XCTFail("Expected APIError to be thrown")
        } catch APIError.apiError(let message, let code) {
            XCTAssertEqual(message, "Invalid access token")
            XCTAssertEqual(code, 190)
        }
    }

    func test_fetchUserProfile_httpError_withoutBody_throwsInvalidResponse() async throws {
        mockSession.stub(data: Data(), statusCode: 500)

        do {
            _ = try await sut.fetchUserProfile(userId: "me", accessToken: "token")
            XCTFail("Expected error")
        } catch APIError.invalidResponse(let code) {
            XCTAssertEqual(code, 500)
        }
    }

    // MARK: - fetchUserMedia

    func test_fetchUserMedia_success_returnsDecodedMedia() async throws {
        let json = """
        {
            "data": [
                {
                    "id": "media1",
                    "media_type": "IMAGE",
                    "media_url": "https://example.com/photo.jpg",
                    "thumbnail_url": null,
                    "timestamp": "2024-01-01T12:00:00+0000",
                    "caption": "Hello world",
                    "permalink": "https://www.instagram.com/p/abc/"
                },
                {
                    "id": "media2",
                    "media_type": "VIDEO",
                    "media_url": "https://example.com/video.mp4",
                    "thumbnail_url": "https://example.com/thumb.jpg",
                    "timestamp": "2024-01-02T12:00:00+0000",
                    "caption": null,
                    "permalink": null
                },
                {
                    "id": "media3",
                    "media_type": "CAROUSEL_ALBUM",
                    "media_url": "https://example.com/carousel.jpg",
                    "thumbnail_url": null,
                    "timestamp": "2024-01-03T12:00:00+0000",
                    "caption": "Multiple photos",
                    "permalink": null
                }
            ],
            "paging": {
                "cursors": {
                    "after": "cursor_after_123",
                    "before": "cursor_before_456"
                },
                "next": "https://graph.instagram.com/next"
            }
        }
        """
        mockSession.stub(data: json.data(using: .utf8)!, statusCode: 200)

        let response = try await sut.fetchUserMedia(userId: "12345", accessToken: "token", after: nil)

        XCTAssertEqual(response.data.count, 3)
        XCTAssertEqual(response.data[0].id, "media1")
        XCTAssertEqual(response.data[0].mediaType, .image)
        XCTAssertEqual(response.data[0].caption, "Hello world")
        XCTAssertEqual(response.data[1].mediaType, .video)
        XCTAssertNotNil(response.data[1].thumbnailUrl)
        XCTAssertEqual(response.data[2].mediaType, .carouselAlbum)
        XCTAssertEqual(response.paging?.cursors?.after, "cursor_after_123")
        XCTAssertNotNil(response.paging?.next)
    }

    func test_fetchUserMedia_emptyResponse_returnsEmptyArray() async throws {
        let json = """
        {
            "data": []
        }
        """
        mockSession.stub(data: json.data(using: .utf8)!, statusCode: 200)

        let response = try await sut.fetchUserMedia(userId: "12345", accessToken: "token", after: nil)

        XCTAssertTrue(response.data.isEmpty)
        XCTAssertNil(response.paging?.next)
    }

    func test_fetchUserMedia_withCursor_appendsCursorParam() async throws {
        let json = """{"data": []}"""
        mockSession.stub(data: json.data(using: .utf8)!, statusCode: 200)

        _ = try await sut.fetchUserMedia(userId: "123", accessToken: "tok", after: "cursor_abc")

        // The request URL should contain 'after=cursor_abc'
        let requestURL = mockSession.lastRequestURL?.absoluteString ?? ""
        XCTAssertTrue(requestURL.contains("after=cursor_abc"), "URL should contain cursor parameter")
    }

    // MARK: - fetchAllMedia

    func test_fetchAllMedia_singlePage_returnsAllMedia() async throws {
        let json = """
        {
            "data": [
                {"id": "1", "media_type": "IMAGE", "media_url": "https://example.com/1.jpg", "thumbnail_url": null, "timestamp": "2024-01-01T00:00:00+0000", "caption": null, "permalink": null},
                {"id": "2", "media_type": "IMAGE", "media_url": "https://example.com/2.jpg", "thumbnail_url": null, "timestamp": "2024-01-02T00:00:00+0000", "caption": null, "permalink": null}
            ]
        }
        """
        mockSession.stub(data: json.data(using: .utf8)!, statusCode: 200)

        var progressValues: [Int] = []
        let allMedia = try await sut.fetchAllMedia(
            userId: "123",
            accessToken: "tok",
            progressHandler: { count in progressValues.append(count) }
        )

        XCTAssertEqual(allMedia.count, 2)
        XCTAssertFalse(progressValues.isEmpty)
        XCTAssertEqual(progressValues.last, 2)
    }
}

// MARK: - Mock URLSession helpers

class MockURLSession {
    private(set) var lastRequestURL: URL?

    var session: URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }

    func stub(data: Data, statusCode: Int) {
        MockURLProtocol.stubbedData = data
        MockURLProtocol.stubbedStatusCode = statusCode
        MockURLProtocol.stubbedError = nil
        MockURLProtocol.requestURLCapture = { [weak self] url in self?.lastRequestURL = url }
    }

    func stub(error: Error) {
        MockURLProtocol.stubbedError = error
    }
}

class MockURLProtocol: URLProtocol {
    static var stubbedData: Data = Data()
    static var stubbedStatusCode: Int = 200
    static var stubbedError: Error? = nil
    static var requestURLCapture: ((URL) -> Void)? = nil

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        if let url = request.url {
            MockURLProtocol.requestURLCapture?(url)
        }

        if let error = MockURLProtocol.stubbedError {
            client?.urlProtocol(self, didFailWithError: error)
            return
        }

        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: MockURLProtocol.stubbedStatusCode,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: MockURLProtocol.stubbedData)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
