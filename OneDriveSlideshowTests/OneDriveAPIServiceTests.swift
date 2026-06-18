import XCTest
@testable import OneDriveSlideshow

final class OneDriveAPIServiceTests: XCTestCase {

    func testDriveItemDecodingFile() throws {
        let json = """
        {
            "id": "abc123",
            "name": "photo.jpg",
            "size": 102400,
            "@microsoft.graph.downloadUrl": "https://example.com/photo.jpg",
            "file": { "mimeType": "image/jpeg" },
            "lastModifiedDateTime": "2024-01-15T10:30:00Z"
        }
        """.data(using: .utf8)!

        let item = try JSONDecoder().decode(DriveItem.self, from: json)

        XCTAssertEqual(item.id, "abc123")
        XCTAssertEqual(item.name, "photo.jpg")
        XCTAssertEqual(item.size, 102400)
        XCTAssertEqual(item.mimeType, "image/jpeg")
        XCTAssertFalse(item.isFolder)
        XCTAssertTrue(item.isImage)
        XCTAssertNotNil(item.lastModified)
    }

    func testDriveItemDecodingFolder() throws {
        let json = """
        {
            "id": "folder1",
            "name": "Photos",
            "folder": { "childCount": 42 }
        }
        """.data(using: .utf8)!

        let item = try JSONDecoder().decode(DriveItem.self, from: json)

        XCTAssertEqual(item.id, "folder1")
        XCTAssertEqual(item.name, "Photos")
        XCTAssertTrue(item.isFolder)
        XCTAssertFalse(item.isImage)
    }

    func testDriveItemListDecoding() throws {
        let json = """
        {
            "value": [
                { "id": "1", "name": "a.jpg", "file": { "mimeType": "image/jpeg" } },
                { "id": "2", "name": "folder", "folder": { "childCount": 0 } }
            ]
        }
        """.data(using: .utf8)!

        let list = try JSONDecoder().decode(DriveItemList.self, from: json)

        XCTAssertEqual(list.value.count, 2)
        XCTAssertNil(list.nextLink)
    }

    func testImageMimeTypeDetection() throws {
        let mimeTypes = ["image/jpeg", "image/png", "image/heic", "image/gif", "image/webp"]
        for mime in mimeTypes {
            let json = """
            {"id":"x","name":"f","file":{"mimeType":"\(mime)"}}
            """.data(using: .utf8)!
            let item = try JSONDecoder().decode(DriveItem.self, from: json)
            XCTAssertTrue(item.isImage, "\(mime) should be recognized as image")
        }
    }

    func testNonImageMimeType() throws {
        let json = """
        {"id":"x","name":"doc.pdf","file":{"mimeType":"application/pdf"}}
        """.data(using: .utf8)!
        let item = try JSONDecoder().decode(DriveItem.self, from: json)
        XCTAssertFalse(item.isImage)
    }
}
