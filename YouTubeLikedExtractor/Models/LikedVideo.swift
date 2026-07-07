import Foundation

/// A single "liked" YouTube video enriched with classification tags.
///
/// Assembled from three API calls: the "LL" liked-videos playlist
/// (`playlistItems.list`) provides `likedAt`, `videos.list` provides the
/// title / description / `categoryId` / topic details, and
/// `videoCategories.list` resolves the numeric category into a human name.
struct LikedVideo: Identifiable, Codable, Equatable {
    /// The YouTube video ID (also used as the stable identity).
    let id: String
    let title: String
    /// The video description — the "内容" the user wants captured.
    let description: String
    /// Canonical watch URL, e.g. https://www.youtube.com/watch?v=<id>
    let url: String
    let thumbnailURL: String?
    /// When the video was liked (added to the "LL" playlist).
    let likedAt: Date
    /// Raw YouTube category id (e.g. "10" for Music). Optional — not every
    /// video reports one.
    let categoryId: String?
    /// Resolved human-readable category name (e.g. "Music").
    let categoryName: String?
    /// Auto-derived topic tags: the category name plus any labels parsed
    /// from `topicDetails.topicCategories`, de-duplicated.
    let tags: [String]

    static func == (lhs: LikedVideo, rhs: LikedVideo) -> Bool {
        lhs.id == rhs.id
    }
}
