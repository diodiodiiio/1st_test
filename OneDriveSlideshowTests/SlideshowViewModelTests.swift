import XCTest
@testable import OneDriveSlideshow

final class SlideshowViewModelTests: XCTestCase {

    func testSlideshowSettingsDefaultValues() {
        let settings = SlideshowSettings()
        XCTAssertEqual(settings.intervalSeconds, 5.0)
        XCTAssertEqual(settings.transitionStyle, .crossfade)
        XCTAssertFalse(settings.shuffle)
        XCTAssertFalse(settings.showCaptions)
        XCTAssertTrue(settings.keepScreenOn)
        XCTAssertNil(settings.selectedFolderID)
    }

    func testSlideshowSettingsRoundTrip() throws {
        var settings = SlideshowSettings()
        settings.intervalSeconds = 10.0
        settings.transitionStyle = .slide
        settings.shuffle = true
        settings.selectedFolderID = "folder123"
        settings.selectedFolderName = "My Photos"

        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(SlideshowSettings.self, from: data)

        XCTAssertEqual(decoded.intervalSeconds, 10.0)
        XCTAssertEqual(decoded.transitionStyle, .slide)
        XCTAssertTrue(decoded.shuffle)
        XCTAssertEqual(decoded.selectedFolderID, "folder123")
        XCTAssertEqual(decoded.selectedFolderName, "My Photos")
    }

    func testTransitionStyleAllCases() {
        XCTAssertEqual(SlideshowSettings.TransitionStyle.allCases.count, 3)
        XCTAssertTrue(SlideshowSettings.TransitionStyle.allCases.contains(.none))
        XCTAssertTrue(SlideshowSettings.TransitionStyle.allCases.contains(.crossfade))
        XCTAssertTrue(SlideshowSettings.TransitionStyle.allCases.contains(.slide))
    }

    func testIntervalOptions() {
        let options = SlideshowSettings.intervalOptions
        XCTAssertFalse(options.isEmpty)
        XCTAssertTrue(options.allSatisfy { $0.value > 0 })
    }

    func testArraySafeSubscript() {
        let arr = [1, 2, 3]
        XCTAssertEqual(arr[safe: 0], 1)
        XCTAssertEqual(arr[safe: 2], 3)
        XCTAssertNil(arr[safe: 3])
        XCTAssertNil(arr[safe: -1])
    }
}
