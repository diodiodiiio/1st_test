import XCTest
import SwiftData
@testable import PhotoReview

final class ReviewViewModelTests: XCTestCase {

    var container: ModelContainer!

    override func setUp() async throws {
        container = try ModelContainer(
            for: ReviewRecord.self, Genre.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    override func tearDown() async throws {
        container = nil
    }

    @MainActor
    func testInitialState() {
        let vm = ReviewViewModel(weekID: "2024-W42", photoService: PhotoLibraryService())
        XCTAssertEqual(vm.currentIndex, 0)
        XCTAssertFalse(vm.isComplete)
        XCTAssertFalse(vm.canUndo)
        XCTAssertTrue(vm.pendingDeleteIDs.isEmpty)
        XCTAssertEqual(vm.keptCount, 0)
    }

    @MainActor
    func testProgressBeforeLoad() {
        let vm = ReviewViewModel(weekID: "2024-W42", photoService: PhotoLibraryService())
        XCTAssertEqual(vm.progress, 1.0)
        XCTAssertEqual(vm.totalCount, 0)
        XCTAssertEqual(vm.remainingCount, 0)
    }

    @MainActor
    func testUndoDisabledWhenHistoryEmpty() {
        let vm = ReviewViewModel(weekID: "2024-W42", photoService: PhotoLibraryService())
        XCTAssertFalse(vm.canUndo)
        vm.undo() // should not crash
    }
}
