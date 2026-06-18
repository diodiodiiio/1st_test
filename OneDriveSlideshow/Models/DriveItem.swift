import Foundation

struct DriveItem: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let size: Int64?
    let mimeType: String?
    let downloadURL: String?
    let lastModified: Date?
    let isFolder: Bool

    enum CodingKeys: String, CodingKey {
        case id, name, size
        case mimeType = "file"
        case downloadURL = "@microsoft.graph.downloadUrl"
        case lastModified = "lastModifiedDateTime"
        case folder
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        size = try c.decodeIfPresent(Int64.self, forKey: .size)
        downloadURL = try c.decodeIfPresent(String.self, forKey: .downloadURL)

        if let fileInfo = try? c.decode(FileInfo.self, forKey: .mimeType) {
            mimeType = fileInfo.mimeType
        } else {
            mimeType = nil
        }

        if let _ = try? c.decode(FolderInfo.self, forKey: .folder) {
            isFolder = true
        } else {
            isFolder = false
        }

        if let raw = try c.decodeIfPresent(String.self, forKey: .lastModified) {
            let fmt = ISO8601DateFormatter()
            fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            lastModified = fmt.date(from: raw) ?? ISO8601DateFormatter().date(from: raw)
        } else {
            lastModified = nil
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encodeIfPresent(size, forKey: .size)
        try c.encodeIfPresent(downloadURL, forKey: .downloadURL)
    }

    var isImage: Bool {
        guard let mime = mimeType else { return false }
        return mime.hasPrefix("image/")
    }

    private struct FileInfo: Codable {
        let mimeType: String
    }

    private struct FolderInfo: Codable {
        let childCount: Int?
    }
}

struct DriveItemList: Codable {
    let value: [DriveItem]
    let nextLink: String?

    enum CodingKeys: String, CodingKey {
        case value
        case nextLink = "@odata.nextLink"
    }
}
