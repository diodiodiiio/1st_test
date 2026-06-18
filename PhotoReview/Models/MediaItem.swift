import Photos
import Foundation

struct MediaItem: Identifiable, Equatable {
    let id: String
    let asset: PHAsset

    var creationDate: Date? { asset.creationDate }
    var mediaType: PHAssetMediaType { asset.mediaType }
    var isLivePhoto: Bool { asset.mediaSubtypes.contains(.photoLive) }
    var isVideo: Bool { asset.mediaType == .video }
    var duration: TimeInterval { asset.duration }

    static func == (lhs: MediaItem, rhs: MediaItem) -> Bool { lhs.id == rhs.id }
}
