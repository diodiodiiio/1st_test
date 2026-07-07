import Foundation

// MARK: - playlistItems.list (the "LL" liked-videos playlist)

/// Response for `playlistItems.list(playlistId="LL", part="snippet,contentDetails")`.
struct PlaylistItemsResponse: Codable {
    let items: [PlaylistItem]
    let nextPageToken: String?
    let pageInfo: PageInfo?

    struct PlaylistItem: Codable {
        let snippet: Snippet
        let contentDetails: ContentDetails

        struct Snippet: Codable {
            /// For the "LL" playlist this is when the video was liked / added.
            let publishedAt: Date
            let title: String
            let description: String
            let thumbnails: Thumbnails?
        }

        struct ContentDetails: Codable {
            let videoId: String
        }
    }
}

// MARK: - videos.list (per-video details + classification)

/// Response for `videos.list(part="snippet,topicDetails", id=...)`.
struct VideosResponse: Codable {
    let items: [VideoItem]

    struct VideoItem: Codable {
        let id: String
        let snippet: Snippet
        let topicDetails: TopicDetails?

        struct Snippet: Codable {
            let title: String
            let description: String
            let categoryId: String?
            let thumbnails: Thumbnails?
        }

        struct TopicDetails: Codable {
            /// Wikipedia URLs describing the video's topics, e.g.
            /// "https://en.wikipedia.org/wiki/Music".
            let topicCategories: [String]?
        }
    }
}

// MARK: - videoCategories.list (categoryId -> name)

/// Response for `videoCategories.list(part="snippet", regionCode=...)`.
struct VideoCategoriesResponse: Codable {
    let items: [CategoryItem]

    struct CategoryItem: Codable {
        let id: String
        let snippet: Snippet

        struct Snippet: Codable {
            let title: String
        }
    }
}

// MARK: - Shared

struct Thumbnails: Codable {
    let `default`: Thumbnail?
    let medium: Thumbnail?
    let high: Thumbnail?

    /// Best available thumbnail URL, preferring higher resolution.
    var bestURL: String? {
        high?.url ?? medium?.url ?? `default`?.url
    }

    struct Thumbnail: Codable {
        let url: String
    }
}

struct PageInfo: Codable {
    let totalResults: Int?
    let resultsPerPage: Int?
}

// MARK: - Error envelope

/// The standard Google API error body, e.g.
/// `{ "error": { "code": 403, "message": "...", "errors": [...] } }`.
struct GoogleAPIErrorResponse: Codable {
    let error: GoogleAPIError

    struct GoogleAPIError: Codable {
        let code: Int
        let message: String
    }
}
