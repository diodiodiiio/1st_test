import SwiftData
import Foundation

@Model
final class ReviewRecord {
    var assetLocalIdentifier: String
    var weekID: String
    var decision: String
    var genreIDs: [String]
    var reviewedAt: Date

    init(
        assetLocalIdentifier: String,
        weekID: String,
        decision: Decision = .pending,
        genreIDs: [String] = [],
        reviewedAt: Date = Date()
    ) {
        self.assetLocalIdentifier = assetLocalIdentifier
        self.weekID = weekID
        self.decision = decision.rawValue
        self.genreIDs = genreIDs
        self.reviewedAt = reviewedAt
    }

    enum Decision: String {
        case keep, delete, pending
    }

    var decisionEnum: Decision { Decision(rawValue: decision) ?? .pending }
}
