import Foundation
@testable import OneDriveSlideshow

final class MockOneDriveAPIService {
    var stubbedItems: [DriveItem] = []
    var stubbedError: Error?
    var downloadedData: Data = Data()

    static func makeDriveItem(
        id: String = UUID().uuidString,
        name: String = "test.jpg",
        isFolder: Bool = false,
        mimeType: String? = "image/jpeg"
    ) -> DriveItem {
        let json: [String: Any] = [
            "id": id,
            "name": name,
            "file": isFolder ? NSNull() : ["mimeType": mimeType as Any],
            "folder": isFolder ? ["childCount": 0] : NSNull()
        ]
        let data = try! JSONSerialization.data(withJSONObject: json)
        return try! JSONDecoder().decode(DriveItem.self, from: data)
    }
}
