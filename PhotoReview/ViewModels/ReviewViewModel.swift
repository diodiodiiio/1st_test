import SwiftUI
import SwiftData
import Photos

@MainActor
class ReviewViewModel: ObservableObject {
    // Review session state
    @Published var items: [MediaItem] = []
    @Published var currentIndex: Int = 0
    @Published var dragOffset: CGSize = .zero
    @Published var isDragging: Bool = false

    // Flow control
    @Published var showGenrePicker: Bool = false
    @Published var isComplete: Bool = false

    // Session results
    @Published var pendingDeleteIDs: [String] = []
    @Published var keptCount: Int = 0
    @Published var genreCountMap: [String: Int] = [:]

    // Undo support
    private var history: [HistoryEntry] = []
    var canUndo: Bool { !history.isEmpty }

    let weekID: String
    private let photoService: PhotoLibraryService
    private var modelContext: ModelContext?

    private struct HistoryEntry {
        let item: MediaItem
        let decision: ReviewRecord.Decision
        let genreIDs: [String]
    }

    var currentItem: MediaItem? {
        guard currentIndex < items.count else { return nil }
        return items[currentIndex]
    }

    var progress: Double {
        guard !items.isEmpty else { return 1.0 }
        return Double(currentIndex) / Double(items.count)
    }

    var totalCount: Int { items.count }
    var remainingCount: Int { max(0, items.count - currentIndex) }

    init(weekID: String, photoService: PhotoLibraryService) {
        self.weekID = weekID
        self.photoService = photoService
    }

    func load(reviewedIDs: Set<String>, context: ModelContext) {
        modelContext = context
        items = photoService.fetchAssets(for: weekID, excluding: reviewedIDs)
        currentIndex = 0
        history.removeAll()
        pendingDeleteIDs.removeAll()
        keptCount = 0
        genreCountMap = [:]
        isComplete = false
    }

    // MARK: - Swipe Actions

    func swipeRight() {
        guard currentItem != nil else { return }
        showGenrePicker = true
    }

    func swipeLeft() {
        guard let item = currentItem else { return }
        commit(item: item, decision: .delete, genreIDs: [])
    }

    func confirmKeep(genreIDs: [String]) {
        guard let item = currentItem else { return }
        showGenrePicker = false
        commit(item: item, decision: .keep, genreIDs: genreIDs)
    }

    func skip() {
        guard let item = currentItem else { return }
        commit(item: item, decision: .pending, genreIDs: [])
    }

    func undo() {
        guard let last = history.popLast() else { return }
        // Remove the saved record
        removeRecord(assetID: last.item.id)
        // Reverse side effects
        switch last.decision {
        case .delete:
            pendingDeleteIDs.removeAll { $0 == last.item.id }
        case .keep:
            keptCount -= 1
            last.genreIDs.forEach { genreCountMap[$0, default: 0] -= 1 }
        case .pending:
            break
        }
        currentIndex -= 1
        dragOffset = .zero
    }

    // MARK: - Deletion

    func deleteMarkedAssets() async throws {
        try await photoService.deleteAssets(pendingDeleteIDs)
        pendingDeleteIDs.removeAll()
    }

    // MARK: - Private

    private func commit(item: MediaItem, decision: ReviewRecord.Decision, genreIDs: [String]) {
        history.append(HistoryEntry(item: item, decision: decision, genreIDs: genreIDs))

        switch decision {
        case .delete:
            pendingDeleteIDs.append(item.id)
        case .keep:
            keptCount += 1
            genreIDs.forEach { genreCountMap[$0, default: 0] += 1 }
        case .pending:
            break
        }

        saveRecord(assetID: item.id, decision: decision, genreIDs: genreIDs)
        currentIndex += 1
        dragOffset = .zero

        if currentIndex >= items.count {
            isComplete = true
        }
    }

    private func saveRecord(assetID: String, decision: ReviewRecord.Decision, genreIDs: [String]) {
        guard let ctx = modelContext else { return }
        let record = ReviewRecord(assetLocalIdentifier: assetID, weekID: weekID, decision: decision, genreIDs: genreIDs)
        ctx.insert(record)
        try? ctx.save()
    }

    private func removeRecord(assetID: String) {
        guard let ctx = modelContext else { return }
        let descriptor = FetchDescriptor<ReviewRecord>(predicate: #Predicate { $0.assetLocalIdentifier == assetID })
        (try? ctx.fetch(descriptor))?.forEach { ctx.delete($0) }
        try? ctx.save()
    }
}
