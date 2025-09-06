import XCTest

@testable import CalSync1on1

final class DateHelperTests: XCTestCase {

    // MARK: - Basic Date Helper Tests

    func testCurrentWeekStart() {
        let dateHelper = DateHelper()
        let weekStart = dateHelper.getCurrentWeekStart()

        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: weekStart)

        // Monday should be weekday 2 (Sunday is 1)
        XCTAssertEqual(weekday, 2, "Week start should be Monday")

        // Should be start of day (midnight)
        let components = calendar.dateComponents([.hour, .minute, .second], from: weekStart)
        XCTAssertEqual(components.hour, 0)
        XCTAssertEqual(components.minute, 0)
        XCTAssertEqual(components.second, 0)
    }

    func testSyncEndDateWithDefaultConfiguration() {
        let dateHelper = DateHelper()
        let startDate = dateHelper.getCurrentWeekStart()
        let endDate = dateHelper.getSyncEndDate()

        let calendar = Calendar.current
        let weeksBetween = calendar.dateComponents([.weekOfYear], from: startDate, to: endDate)
            .weekOfYear

        XCTAssertEqual(weeksBetween, 2, "Should be exactly 2 weeks difference by default")
        XCTAssertTrue(endDate > startDate, "End date should be after start date")
    }

    func testDateHelperWithCustomSyncWindow() {
        let config = Configuration.with(weeks: 3, startOffset: -1)
        let dateHelper = DateHelper(configuration: config)

        let startDate = dateHelper.getCurrentWeekStart()
        let endDate = dateHelper.getSyncEndDate()

        let calendar = Calendar.current
        let weeksBetween = calendar.dateComponents([.weekOfYear], from: startDate, to: endDate)
            .weekOfYear

        XCTAssertEqual(weeksBetween, 3, "Should respect custom sync window")
    }

    func testDateHelperWithLongerSyncWindow() {
        let config = Configuration.with(weeks: 4, startOffset: 0)
        let dateHelper = DateHelper(configuration: config)

        let startDate = dateHelper.getCurrentWeekStart()
        let endDate = dateHelper.getSyncEndDate()

        let calendar = Calendar.current
        let weeksBetween = calendar.dateComponents([.weekOfYear], from: startDate, to: endDate)
            .weekOfYear

        XCTAssertEqual(weeksBetween, 4, "Should handle longer sync windows")

        // Verify that the window is suitable for recurring events
        let daysBetween = calendar.dateComponents([.day], from: startDate, to: endDate).day
        XCTAssertEqual(daysBetween, 28, "4 weeks should equal 28 days")
    }

    func testDateHelperConsistency() {
        let dateHelper = DateHelper()

        // Multiple calls should return consistent results
        let weekStart1 = dateHelper.getCurrentWeekStart()
        let weekStart2 = dateHelper.getCurrentWeekStart()
        let endDate1 = dateHelper.getSyncEndDate()
        let endDate2 = dateHelper.getSyncEndDate()

        XCTAssertEqual(weekStart1, weekStart2, "Week start should be consistent")
        XCTAssertEqual(endDate1, endDate2, "End date should be consistent")
    }

    func testDateHelperWithNegativeStartOffset() {
        let config = Configuration.with(weeks: 3, startOffset: -2)
        let dateHelper = DateHelper(configuration: config)

        let startDate = dateHelper.getCurrentWeekStart()
        let endDate = dateHelper.getSyncEndDate()

        let calendar = Calendar.current
        let weeksBetween = calendar.dateComponents([.weekOfYear], from: startDate, to: endDate)
            .weekOfYear

        XCTAssertEqual(weeksBetween, 3, "Should maintain configured weeks regardless of offset")

        // Start date should be 2 weeks before current week
        let defaultDateHelper = DateHelper()
        let defaultStart = defaultDateHelper.getCurrentWeekStart()
        let expectedStart = calendar.date(
            byAdding: .weekOfYear, value: -2, to: defaultStart
        )!

        XCTAssertEqual(startDate, expectedStart, "Should apply negative offset correctly")
    }

    // MARK: - DateHelper Static Method Tests

    func testDateFormatting() {
        let testDate = Date()
        let formattedDate = DateHelper.formatDate(testDate)

        XCTAssertFalse(formattedDate.isEmpty, "Formatted date should not be empty")
        XCTAssertTrue(
            formattedDate.contains("/") || formattedDate.contains("-")
                || formattedDate.contains("."),
            "Formatted date should contain date separators: \(formattedDate)"
        )
    }

    func testDateRangeFormatting() {
        let dateHelper = DateHelper()
        let startDate = dateHelper.getCurrentWeekStart()
        let endDate = dateHelper.getSyncEndDate()

        let formattedRange = dateHelper.formatDateRange(start: startDate, end: endDate)

        XCTAssertFalse(formattedRange.isEmpty, "Formatted range should not be empty")
        XCTAssertTrue(formattedRange.contains(" - "), "Formatted range should contain separator")
    }

    func testLongDateFormatting() {
        let testDate = Date()
        let longFormatted = DateHelper.formatDateLong(testDate)

        XCTAssertFalse(longFormatted.isEmpty, "Long formatted date should not be empty")

        // Long format should be more detailed than short format
        let shortFormatted = DateHelper.formatDate(testDate)
        XCTAssertTrue(
            longFormatted.count >= shortFormatted.count,
            "Long format should be at least as detailed as short format"
        )
    }
}
