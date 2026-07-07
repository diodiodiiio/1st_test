import XCTest
@testable import YouTubeLikedExtractor

class ExportServiceTests: XCTestCase {

    var sut: ExportService!

    override func setUp() {
        super.setUp()
        sut = ExportService()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    private func makeVideo(
        id: String = "abc",
        title: String = "Title",
        description: String = "Description",
        tags: [String] = ["Music"]
    ) -> LikedVideo {
        LikedVideo(id: id, title: title, description: description,
                   url: "https://www.youtube.com/watch?v=\(id)", thumbnailURL: nil,
                   likedAt: Date(timeIntervalSince1970: 1_700_000_000),
                   categoryId: "10", categoryName: "Music", tags: tags)
    }

    // MARK: - CSV

    func test_makeCSV_includesHeaderRow() {
        let csv = sut.makeCSV(from: [])
        let firstLine = csv.components(separatedBy: "\r\n").first
        XCTAssertEqual(firstLine, "\"title\",\"url\",\"likedAt\",\"categoryName\",\"tags\",\"description\"")
    }

    func test_makeCSV_escapesQuotesAndPreservesCommasAndNewlines() {
        let video = makeVideo(title: "Say \"Hello\"",
                              description: "Line1, still line1\nLine2")
        let csv = sut.makeCSV(from: [video])

        // Embedded quotes are doubled.
        XCTAssertTrue(csv.contains("\"Say \"\"Hello\"\"\""))
        // Comma and newline live inside a quoted field, so there are exactly
        // two logical rows separated by CRLF (header + one record).
        let rows = csv.components(separatedBy: "\r\n")
        XCTAssertEqual(rows.count, 2)
        XCTAssertTrue(csv.contains("Line1, still line1\nLine2"))
    }

    func test_makeCSV_joinsTagsWithSemicolon() {
        let csv = sut.makeCSV(from: [makeVideo(tags: ["Music", "Pop"])])
        XCTAssertTrue(csv.contains("\"Music; Pop\""))
    }

    // MARK: - JSON

    func test_makeJSON_roundTripsToLikedVideos() throws {
        let videos = [makeVideo(id: "1"), makeVideo(id: "2")]
        let json = try sut.makeJSON(from: videos)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode([LikedVideo].self, from: Data(json.utf8))

        XCTAssertEqual(decoded.count, 2)
        XCTAssertEqual(decoded.map(\.id), ["1", "2"])
        XCTAssertEqual(decoded[0].categoryName, "Music")
    }

    // MARK: - File output

    func test_export_writesFileWithCorrectExtension() throws {
        let url = try sut.export([makeVideo()], format: .csv)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }

        XCTAssertEqual(url.pathExtension, "csv")
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        let contents = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(contents.contains("Title"))
    }
}
