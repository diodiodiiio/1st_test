import Foundation

struct InstagramUser: Identifiable, Codable {
    let id: String
    let username: String
    let name: String?
    let biography: String?
    let followersCount: Int?
    let followsCount: Int?
    let mediaCount: Int?
    let profilePictureUrl: String?
    let website: String?

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case name
        case biography
        case followersCount = "followers_count"
        case followsCount = "follows_count"
        case mediaCount = "media_count"
        case profilePictureUrl = "profile_picture_url"
        case website
    }
}
