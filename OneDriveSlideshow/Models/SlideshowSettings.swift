import Foundation

struct SlideshowSettings: Codable {
    var intervalSeconds: Double = 5.0
    var transitionStyle: TransitionStyle = .crossfade
    var shuffle: Bool = false
    var showCaptions: Bool = false
    var keepScreenOn: Bool = true
    var selectedFolderID: String? = nil
    var selectedFolderName: String? = nil

    enum TransitionStyle: String, CaseIterable, Codable, Identifiable {
        case none, crossfade, slide
        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .none: return "なし"
            case .crossfade: return "クロスフェード"
            case .slide: return "スライド"
            }
        }
    }

    static let intervalOptions: [(label: String, value: Double)] = [
        ("3秒", 3), ("5秒", 5), ("10秒", 10), ("15秒", 15), ("30秒", 30)
    ]
}
