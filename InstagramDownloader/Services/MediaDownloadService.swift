import Foundation
import UIKit
import Photos

enum DownloadError: LocalizedError {
    case invalidURL
    case downloadFailed
    case saveFailed
    case permissionDenied

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "ダウンロードURLが無効です"
        case .downloadFailed: return "ダウンロードに失敗しました"
        case .saveFailed: return "カメラロールへの保存に失敗しました"
        case .permissionDenied: return "フォトライブラリへのアクセス許可が必要です"
        }
    }
}

struct DownloadResult {
    let mediaId: String
    let success: Bool
    let localURL: URL?
    let error: Error?
}

class MediaDownloadService: ObservableObject {
    static let shared = MediaDownloadService()

    @Published var downloadingIds: Set<String> = []
    @Published var completedIds: Set<String> = []
    @Published var failedIds: Set<String> = []

    private let fileManager = FileManager.default
    private let session: URLSession

    private lazy var downloadDirectory: URL = {
        let paths = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        let dir = paths[0].appendingPathComponent("InstagramDownloads", isDirectory: true)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    init(session: URLSession = .shared) {
        self.session = session
    }

    @MainActor
    func downloadMedia(_ media: InstagramMedia) async {
        guard !downloadingIds.contains(media.id) else { return }

        let urlString = media.mediaUrl ?? media.thumbnailUrl
        guard let urlString = urlString, let url = URL(string: urlString) else {
            failedIds.insert(media.id)
            return
        }

        downloadingIds.insert(media.id)

        do {
            let localURL = try await downloadToCache(from: url, mediaId: media.id, mediaType: media.mediaType)
            try await saveToPhotoLibrary(localURL: localURL, mediaType: media.mediaType)
            completedIds.insert(media.id)
        } catch {
            failedIds.insert(media.id)
        }

        downloadingIds.remove(media.id)
    }

    @MainActor
    func downloadAll(_ mediaItems: [InstagramMedia], progressHandler: ((Int, Int) -> Void)? = nil) async {
        let toDownload = mediaItems.filter { !completedIds.contains($0.id) }
        var completed = 0

        await withTaskGroup(of: Void.self) { group in
            for media in toDownload {
                group.addTask {
                    await self.downloadMedia(media)
                    completed += 1
                    progressHandler?(completed, toDownload.count)
                }
            }
        }
    }

    private func downloadToCache(from url: URL, mediaId: String, mediaType: InstagramMedia.MediaType) async throws -> URL {
        let ext = mediaType == .video ? "mp4" : "jpg"
        let destinationURL = downloadDirectory.appendingPathComponent("\(mediaId).\(ext)")

        if fileManager.fileExists(atPath: destinationURL.path) {
            return destinationURL
        }

        let (tempURL, response) = try await session.download(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw DownloadError.downloadFailed
        }

        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        try fileManager.moveItem(at: tempURL, to: destinationURL)
        return destinationURL
    }

    private func saveToPhotoLibrary(localURL: URL, mediaType: InstagramMedia.MediaType) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            throw DownloadError.permissionDenied
        }

        try await PHPhotoLibrary.shared().performChanges {
            if mediaType == .video {
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: localURL)
            } else {
                PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: localURL)
            }
        }
    }

    func isCompleted(_ mediaId: String) -> Bool {
        completedIds.contains(mediaId)
    }

    func isDownloading(_ mediaId: String) -> Bool {
        downloadingIds.contains(mediaId)
    }

    func hasFailed(_ mediaId: String) -> Bool {
        failedIds.contains(mediaId)
    }

    func getLocalURL(for mediaId: String) -> URL? {
        for ext in ["jpg", "mp4"] {
            let url = downloadDirectory.appendingPathComponent("\(mediaId).\(ext)")
            if fileManager.fileExists(atPath: url.path) { return url }
        }
        return nil
    }

    func clearAll() throws {
        let files = try fileManager.contentsOfDirectory(at: downloadDirectory, includingPropertiesForKeys: nil)
        for file in files {
            try fileManager.removeItem(at: file)
        }
        completedIds.removeAll()
        failedIds.removeAll()
    }
}
