import Photos
import UIKit

@MainActor
class PhotoLibraryService: ObservableObject {
    @Published var authorizationStatus: PHAuthorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)

    func requestAuthorization() async -> PHAuthorizationStatus {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        authorizationStatus = status
        return status
    }

    func fetchAssets(for weekID: String, excluding reviewedIDs: Set<String>) -> [MediaItem] {
        guard let range = WeekHelper.dateRange(for: weekID) else { return [] }

        let options = PHFetchOptions()
        options.predicate = NSPredicate(
            format: "creationDate >= %@ AND creationDate < %@",
            range.start as CVarArg,
            range.end as CVarArg
        )
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]

        let result = PHAsset.fetchAssets(with: options)
        var items: [MediaItem] = []
        result.enumerateObjects { asset, _, _ in
            guard !reviewedIDs.contains(asset.localIdentifier) else { return }
            // Skip non-representative burst shots
            if asset.representsBurst && !asset.burstSelectionTypes.contains(.autoPick) { return }
            items.append(MediaItem(id: asset.localIdentifier, asset: asset))
        }
        return items
    }

    func totalCount(for weekID: String) -> Int {
        guard let range = WeekHelper.dateRange(for: weekID) else { return 0 }
        let options = PHFetchOptions()
        options.predicate = NSPredicate(
            format: "creationDate >= %@ AND creationDate < %@",
            range.start as CVarArg,
            range.end as CVarArg
        )
        return PHAsset.fetchAssets(with: options).count
    }

    func unreviewedCount(for weekID: String, reviewedIDs: Set<String>) -> Int {
        fetchAssets(for: weekID, excluding: reviewedIDs).count
    }

    func deleteAssets(_ identifiers: [String]) async throws {
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: nil)
        var list: [PHAsset] = []
        assets.enumerateObjects { asset, _, _ in list.append(asset) }
        guard !list.isEmpty else { return }

        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.deleteAssets(list as NSArray)
        }
    }

    func loadImage(for asset: PHAsset, targetSize: CGSize) async -> UIImage? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            options.isSynchronous = false
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFit,
                options: options
            ) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }

    func loadLivePhoto(for asset: PHAsset, targetSize: CGSize) async -> PHLivePhoto? {
        await withCheckedContinuation { continuation in
            let options = PHLivePhotoRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            PHImageManager.default().requestLivePhoto(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFit,
                options: options
            ) { livePhoto, _ in
                continuation.resume(returning: livePhoto)
            }
        }
    }
}
