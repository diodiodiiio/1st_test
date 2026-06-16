import Foundation

struct InstagramMedia: Identifiable, Codable, Equatable {
    let id: String
    let mediaType: MediaType
    let mediaUrl: String?
    let thumbnailUrl: String?
    let timestamp: String
    let caption: String?
    let permalink: String?

    enum MediaType: String, Codable {
        case image = "IMAGE"
        case video = "VIDEO"
        case carouselAlbum = "CAROUSEL_ALBUM"
    }

    enum CodingKeys: String, CodingKey {
        case id
        case mediaType = "media_type"
        case mediaUrl = "media_url"
        case thumbnailUrl = "thumbnail_url"
        case timestamp
        case caption
        case permalink
    }

    static func == (lhs: InstagramMedia, rhs: InstagramMedia) -> Bool {
        lhs.id == rhs.id
    }
}

struct MediaListResponse: Codable {
    let data: [InstagramMedia]
    let paging: Paging?

    struct Paging: Codable {
        let cursors: Cursors?
        let next: String?

        struct Cursors: Codable {
            let after: String?
            let before: String?
        }
    }
}
