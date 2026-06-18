import UIKit

final class ImageCacheService {
    static let shared = ImageCacheService()

    private let memoryCache = NSCache<NSString, UIImage>()
    private let cacheDir: URL
    private let fileManager = FileManager.default

    private init() {
        let docs = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        cacheDir = docs.appendingPathComponent("OneDriveImageCache", isDirectory: true)
        try? fileManager.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        memoryCache.countLimit = 50
        memoryCache.totalCostLimit = 100 * 1024 * 1024 // 100 MB
    }

    func image(for itemID: String) -> UIImage? {
        if let cached = memoryCache.object(forKey: itemID as NSString) {
            return cached
        }
        let diskURL = cacheDir.appendingPathComponent(itemID)
        if let data = try? Data(contentsOf: diskURL), let img = UIImage(data: data) {
            memoryCache.setObject(img, forKey: itemID as NSString, cost: data.count)
            return img
        }
        return nil
    }

    func store(data: Data, for itemID: String) {
        let diskURL = cacheDir.appendingPathComponent(itemID)
        try? data.write(to: diskURL, options: .atomic)
        if let img = UIImage(data: data) {
            memoryCache.setObject(img, forKey: itemID as NSString, cost: data.count)
        }
    }

    func clearAll() {
        memoryCache.removeAllObjects()
        try? fileManager.removeItem(at: cacheDir)
        try? fileManager.createDirectory(at: cacheDir, withIntermediateDirectories: true)
    }

    func isCached(itemID: String) -> Bool {
        let diskURL = cacheDir.appendingPathComponent(itemID)
        return fileManager.fileExists(atPath: diskURL.path)
    }
}
