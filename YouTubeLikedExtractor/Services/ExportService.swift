import Foundation

/// Serializes `[LikedVideo]` to CSV or JSON and writes it into the app's
/// Documents directory for sharing.
struct ExportService {
    enum Format {
        case csv
        case json

        var fileExtension: String { self == .csv ? "csv" : "json" }
    }

    private let fileManager: FileManager
    private let dateFormatter: ISO8601DateFormatter

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.dateFormatter = ISO8601DateFormatter()
    }

    // MARK: - String generation

    /// CSV with a header row. All fields are quoted and embedded quotes are
    /// doubled, so commas / newlines inside descriptions stay safe.
    func makeCSV(from videos: [LikedVideo]) -> String {
        let header = ["title", "url", "likedAt", "categoryName", "tags", "description"]
        var rows = [header.map(csvField).joined(separator: ",")]
        for video in videos {
            let fields = [
                video.title,
                video.url,
                dateFormatter.string(from: video.likedAt),
                video.categoryName ?? "",
                video.tags.joined(separator: "; "),
                video.description
            ]
            rows.append(fields.map(csvField).joined(separator: ","))
        }
        return rows.joined(separator: "\r\n")
    }

    func makeJSON(from videos: [LikedVideo]) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(videos)
        return String(data: data, encoding: .utf8) ?? ""
    }

    private func csvField(_ value: String) -> String {
        "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }

    // MARK: - File output

    /// Writes an export file into Documents and returns its URL (for a share
    /// sheet). Filenames are timestamped so repeated exports don't collide.
    func export(_ videos: [LikedVideo], format: Format) throws -> URL {
        let contents: String
        switch format {
        case .csv: contents = makeCSV(from: videos)
        case .json: contents = try makeJSON(from: videos)
        }

        let stamp = fileStampFormatter.string(from: Date())
        let filename = "liked_videos_\(stamp).\(format.fileExtension)"
        let directory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = directory.appendingPathComponent(filename)
        try contents.data(using: .utf8)?.write(to: url)
        return url
    }

    private var fileStampFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }
}
