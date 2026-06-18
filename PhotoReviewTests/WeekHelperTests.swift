import XCTest
@testable import PhotoReview

final class WeekHelperTests: XCTestCase {

    func testWeekIDFormat() {
        let id = WeekHelper.weekID(for: Date())
        XCTAssertTrue(id.contains("-W"), "weekID should contain '-W': \(id)")
        let parts = id.split(separator: "-W")
        XCTAssertEqual(parts.count, 2)
        XCTAssertNotNil(Int(parts[0]))
        XCTAssertNotNil(Int(parts[1]))
    }

    func testDateRoundTrip() throws {
        // A specific Monday
        var c = DateComponents()
        c.year = 2024; c.month = 10; c.day = 14
        let monday = Calendar.current.date(from: c)!
        let wid = WeekHelper.weekID(for: monday)
        let range = try XCTUnwrap(WeekHelper.dateRange(for: wid))
        XCTAssertLessThanOrEqual(range.start, monday)
        XCTAssertGreaterThan(range.end, monday)
    }

    func testRecentWeekIDsCount() {
        let ids = WeekHelper.recentWeekIDs(count: 8)
        XCTAssertEqual(ids.count, 8)
    }

    func testRecentWeekIDsAreDescending() {
        let ids = WeekHelper.recentWeekIDs(count: 3)
        guard ids.count == 3 else { return }
        // Current week is ids[0], last week is ids[1]
        XCTAssertEqual(ids[0], WeekHelper.currentWeekID())
    }

    func testWeekLabelNotEmpty() {
        let wid = WeekHelper.currentWeekID()
        let label = WeekHelper.weekLabel(for: wid)
        XCTAssertFalse(label.isEmpty)
        XCTAssertTrue(label.contains("〜"))
    }

    func testInvalidWeekIDReturnsNil() {
        XCTAssertNil(WeekHelper.dateRange(for: "invalid"))
        XCTAssertNil(WeekHelper.dateRange(for: "2024-W"))
        XCTAssertNil(WeekHelper.dateRange(for: ""))
    }
}
