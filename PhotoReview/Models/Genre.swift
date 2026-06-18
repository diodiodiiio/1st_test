import SwiftData
import Foundation

@Model
final class Genre {
    var id: String
    var name: String
    var colorHex: String
    var icon: String
    var sortOrder: Int

    init(id: String = UUID().uuidString, name: String, colorHex: String, icon: String, sortOrder: Int) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.icon = icon
        self.sortOrder = sortOrder
    }

    static let defaults: [Genre] = [
        Genre(name: "人物",           colorHex: "#FF6B6B", icon: "person.fill",          sortOrder: 0),
        Genre(name: "風景",           colorHex: "#4ECDC4", icon: "mountain.2.fill",       sortOrder: 1),
        Genre(name: "食事",           colorHex: "#FFE66D", icon: "fork.knife",            sortOrder: 2),
        Genre(name: "ペット",         colorHex: "#A8E6CF", icon: "pawprint.fill",         sortOrder: 3),
        Genre(name: "書類・メモ",     colorHex: "#88D8B0", icon: "doc.fill",              sortOrder: 4),
        Genre(name: "スクリーンショット", colorHex: "#B0BEC5", icon: "iphone",            sortOrder: 5),
        Genre(name: "その他",         colorHex: "#CE93D8", icon: "tag.fill",              sortOrder: 6),
    ]
}
