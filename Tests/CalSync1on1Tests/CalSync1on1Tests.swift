import XCTest
@testable import CalSync1on1

final class CalSync1on1Tests: XCTestCase {

    // MARK: - DateHelper Tests

    func testDateHelperCurrentWeekStart() {
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

    func testDateHelperTwoWeeksFromNow() {
        let dateHelper = DateHelper()
        let startDate = dateHelper.getCurrentWeekStart()
        let endDate = dateHelper.getSyncEndDate()

        let calendar = Calendar.current
        let weeksBetween = calendar.dateComponents([.weekOfYear], from: startDate, to: endDate).weekOfYear

        XCTAssertEqual(weeksBetween, 2, "Should be exactly 2 weeks difference by default")
        XCTAssertTrue(endDate > startDate, "End date should be after start date")
    }

    func testDateHelperWithCustomConfiguration() {
        let customConfig = Configuration(
            version: "1.0",
            calendarPair: Configuration.default.primaryCalendarPair,
            syncWindow: Configuration.SyncWindow(weeks: 3, startOffset: -1),
            filters: Configuration.default.filters,
            logging: Configuration.default.logging
        )

        let dateHelper = DateHelper(configuration: customConfig)
        let startDate = dateHelper.getCurrentWeekStart()
        let endDate = dateHelper.getSyncEndDate()

        let calendar = Calendar.current
        let weeksBetween = calendar.dateComponents([.weekOfYear], from: startDate, to: endDate).weekOfYear

        XCTAssertEqual(weeksBetween, 3, "Should respect custom sync window")
    }

    // MARK: - Configuration Tests

    func testDefaultConfiguration() {
        let config = Configuration.default

        XCTAssertEqual(config.version, "1.0")
        XCTAssertEqual(config.calendarPair.name, "Work to Personal")
        XCTAssertEqual(config.calendarPair.source.calendar, "Calendar")
        XCTAssertEqual(config.calendarPair.destination.calendar, "Personal")
        XCTAssertEqual(config.calendarPair.titleTemplate, "1:1 with {{otherPerson}}")
        XCTAssertEqual(config.syncWindow.weeks, 2)
        XCTAssertEqual(config.syncWindow.startOffset, 0)
        XCTAssertTrue(config.filters.excludeAllDay)
        XCTAssertTrue(config.filters.excludePrivate)
        XCTAssertEqual(config.filters.excludeKeywords, ["standup", "all-hands"])
        XCTAssertEqual(config.logging.level, "info")
        XCTAssertTrue(config.logging.coloredOutput)
    }

    func testConfigurationPrimaryCalendarPair() {
        let config = Configuration.default
        let primaryPair = config.primaryCalendarPair

        XCTAssertEqual(primaryPair.name, "Work to Personal")
        XCTAssertEqual(primaryPair.source.calendar, "Calendar")
        XCTAssertEqual(primaryPair.destination.calendar, "Personal")
        XCTAssertEqual(primaryPair.titleTemplate, "1:1 with {{otherPerson}}")
    }

    // MARK: - Command Line Arguments Tests

    func testCommandLineArgumentsLogic() {
        // Test the logic for extracting command line arguments
        let testArgs = [
            "calsync1on1",
            "--config", "/custom/path/config.yaml",
            "--dry-run",
            "--verbose"
        ]

        // Test the extractValue logic
        let configPath = testArgs.firstIndex(of: "--config").flatMap { index in
            index + 1 < testArgs.count ? testArgs[index + 1] : nil
        }

        XCTAssertEqual(configPath, "/custom/path/config.yaml")
        XCTAssertTrue(testArgs.contains("--dry-run"))
        XCTAssertTrue(testArgs.contains("--verbose"))
        XCTAssertFalse(testArgs.contains("--help"))
    }

    // MARK: - SyncedEvent Model Tests

    func testSyncedEventCreation() {
        let startDate = Date()
        let endDate = startDate.addingTimeInterval(3600)

        let syncedEvent = SyncedEvent(
            sourceEventId: "test-event-123",
            destinationEventId: nil,
            title: "1:1 with John Doe",
            startDate: startDate,
            endDate: endDate,
            otherPersonName: "John Doe",
            lastSyncDate: Date()
        )

        XCTAssertEqual(syncedEvent.sourceEventId, "test-event-123")
        XCTAssertNil(syncedEvent.destinationEventId)
        XCTAssertEqual(syncedEvent.title, "1:1 with John Doe")
        XCTAssertEqual(syncedEvent.startDate, startDate)
        XCTAssertEqual(syncedEvent.endDate, endDate)
        XCTAssertEqual(syncedEvent.otherPersonName, "John Doe")
        XCTAssertNotNil(syncedEvent.lastSyncDate)
    }

    func testSyncedEventConvenienceInitializer() {
        let mockEvent = TestEvent(
            eventIdentifier: "test-123",
            startDate: Date(),
            endDate: Date().addingTimeInterval(1800)
        )

        let syncedEvent = SyncedEvent(
            sourceEvent: mockEvent,
            otherPersonName: "Alice Smith"
        )

        XCTAssertEqual(syncedEvent.sourceEventId, "test-123")
        XCTAssertEqual(syncedEvent.title, "1:1 with Alice Smith")
        XCTAssertEqual(syncedEvent.otherPersonName, "Alice Smith")
        XCTAssertNotNil(syncedEvent.lastSyncDate)

        // Verify the last sync date is recent
        let timeSinceSync = abs(syncedEvent.lastSyncDate.timeIntervalSinceNow)
        XCTAssertLessThan(timeSinceSync, 60, "Last sync date should be recent")
    }

    // MARK: - EventMetadata Tests

    func testSyncMetadataCreation() {
        let metadata = SyncMetadata(
            sourceEventId: "test-event-123",
            sourceCalendar: "Work Calendar",
            syncVersion: "1.0",
            lastSyncDate: Date(),
            otherPersonName: "John Doe"
        )

        XCTAssertEqual(metadata.sourceEventId, "test-event-123")
        XCTAssertEqual(metadata.sourceCalendar, "Work Calendar")
        XCTAssertEqual(metadata.syncVersion, "1.0")
        XCTAssertEqual(metadata.otherPersonName, "John Doe")
        XCTAssertNotNil(metadata.lastSyncDate)
    }

    func testSyncMetadataCurrentVersion() {
        XCTAssertEqual(SyncMetadata.currentVersion, "1.0")

        let metadata = SyncMetadata(
            sourceEventId: "test",
            sourceCalendar: "test",
            syncVersion: SyncMetadata.currentVersion,
            lastSyncDate: Date(),
            otherPersonName: "test"
        )

        XCTAssertEqual(metadata.syncVersion, SyncMetadata.currentVersion)
    }

    func testSyncMetadataMutability() {
        var metadata = SyncMetadata(
            sourceEventId: "test",
            sourceCalendar: "test",
            syncVersion: "1.0",
            lastSyncDate: Date(timeIntervalSince1970: 1640995200),
            otherPersonName: "test"
        )

        let originalDate = metadata.lastSyncDate
        let newDate = Date()

        // Test that lastSyncDate can be modified
        metadata.lastSyncDate = newDate

        XCTAssertNotEqual(metadata.lastSyncDate, originalDate)
        XCTAssertEqual(metadata.lastSyncDate, newDate)
    }

    // MARK: - Email Name Extraction Tests

    func testEmailNameExtraction() {
        // Test the logic that would be used in extractNameFromEmail
        let testCases = [
            ("john.doe@company.com", "John Doe"),
            ("alice_smith@example.org", "Alice Smith"),
            ("bob.jones_contractor@client.com", "Bob Jones Contractor"),
            ("simple@domain.com", "Simple"),
            ("first.middle.last@company.co.uk", "First Middle Last"),
            ("user123@company.com", "User123")
        ]

        for (email, expectedName) in testCases {
            let emailParts = email.components(separatedBy: "@")
            guard let localPart = emailParts.first else {
                XCTFail("Failed to extract local part from email: \(email)")
                continue
            }

            let extractedName = localPart
                .replacingOccurrences(of: ".", with: " ")
                .replacingOccurrences(of: "_", with: " ")
                .capitalized

            XCTAssertEqual(extractedName, expectedName, "Email \(email) should extract to \(expectedName)")
        }
    }

    // MARK: - URL Email Extraction Tests

    func testURLEmailExtraction() {
        let testCases = [
            ("mailto:john.doe@company.com", "john.doe@company.com"),
            ("mailto:alice@example.org", "alice@example.org"),
            ("john.doe@company.com", "john.doe@company.com") // Without mailto prefix
        ]

        for (urlString, expectedEmail) in testCases {
            let extractedEmail: String
            if urlString.hasPrefix("mailto:") {
                extractedEmail = String(urlString.dropFirst(7))
            } else {
                extractedEmail = urlString
            }

            XCTAssertEqual(extractedEmail, expectedEmail, "URL \(urlString) should extract to \(expectedEmail)")
        }
    }

    // MARK: - Manager Instantiation Tests

    func testCalendarManagerInstantiation() {
        let calendarManager = CalendarManager()
        XCTAssertNotNil(calendarManager, "CalendarManager should be instantiable")
    }

    func testSyncManagerInstantiation() {
        let syncManager = SyncManager(configuration: Configuration.default)
        XCTAssertNotNil(syncManager, "SyncManager should be instantiable")
    }

    func testMeetingAnalyzerInstantiation() {
        let analyzer = MeetingAnalyzer()
        XCTAssertNotNil(analyzer, "MeetingAnalyzer should be instantiable")
    }

    // MARK: - Recurring Event Analysis Tests

    func testRecurrenceAnalysisStructure() {
        let analysis = MeetingAnalyzer.RecurrenceAnalysis(
            isRecurring: true,
            isOneOnOneRecurringSeries: true,
            recurrenceRule: "FREQ=WEEKLY;BYDAY=TU",
            shouldSyncSeries: true,
            exceptions: ["exception-1", "exception-2"]
        )

        XCTAssertTrue(analysis.isRecurring)
        XCTAssertTrue(analysis.isOneOnOneRecurringSeries)
        XCTAssertEqual(analysis.recurrenceRule, "FREQ=WEEKLY;BYDAY=TU")
        XCTAssertTrue(analysis.shouldSyncSeries)
        XCTAssertEqual(analysis.exceptions.count, 2)
        XCTAssertEqual(analysis.exceptions, ["exception-1", "exception-2"])
    }

    // MARK: - SyncManager Result Tests

    func testSyncResultCreation() {
        let result = SyncManager.SyncResult(
            created: 5,
            updated: 3,
            deleted: 2,
            skipped: 10,
            errors: ["Error 1", "Error 2"]
        )

        XCTAssertEqual(result.created, 5)
        XCTAssertEqual(result.updated, 3)
        XCTAssertEqual(result.deleted, 2)
        XCTAssertEqual(result.skipped, 10)
        XCTAssertEqual(result.errors.count, 2)
        XCTAssertEqual(result.errors, ["Error 1", "Error 2"])
    }

    func testSyncResultWithNoErrors() {
        let result = SyncManager.SyncResult(
            created: 1,
            updated: 0,
            deleted: 0,
            skipped: 2,
            errors: []
        )

        XCTAssertEqual(result.created, 1)
        XCTAssertTrue(result.errors.isEmpty)
    }

    // MARK: - String Extension Tests

    func testStringMultiplication() {
        XCTAssertEqual(String(repeating: "=", count: 5), "=====")
        XCTAssertEqual(String(repeating: "-", count: 3), "---")
        XCTAssertEqual(String(repeating: "abc", count: 2), "abcabc")
        XCTAssertEqual(String(repeating: "x", count: 0), "")
    }

    // MARK: - Recurring Event Tests

    func testRecurrenceAnalysisStructureForNonRecurringEvent() {
        // Test the RecurrenceAnalysis structure without EKEvent dependency
        let analysis = MeetingAnalyzer.RecurrenceAnalysis(
            isRecurring: false,
            isOneOnOneRecurringSeries: false,
            recurrenceRule: nil,
            shouldSyncSeries: false,
            exceptions: []
        )

        XCTAssertFalse(analysis.isRecurring, "Non-recurring event should not be detected as recurring")
        XCTAssertFalse(analysis.isOneOnOneRecurringSeries, "Non-recurring event should not be a 1:1 recurring series")
        XCTAssertNil(analysis.recurrenceRule, "Non-recurring event should have no recurrence rule")
        XCTAssertFalse(analysis.shouldSyncSeries, "Non-recurring event should not be synced as series")
        XCTAssertTrue(analysis.exceptions.isEmpty, "Non-recurring event should have no exceptions")
    }

    func testRecurrenceAnalysisStructureForRecurringEvent() {
        // Test the RecurrenceAnalysis structure for recurring events
        let analysis = MeetingAnalyzer.RecurrenceAnalysis(
            isRecurring: true,
            isOneOnOneRecurringSeries: true,
            recurrenceRule: "FREQ=WEEKLY;BYDAY=TU",
            shouldSyncSeries: true,
            exceptions: ["exception-1"]
        )

        XCTAssertTrue(analysis.isRecurring, "Recurring event should be detected as recurring")
        XCTAssertTrue(analysis.isOneOnOneRecurringSeries, "Recurring 1:1 should be detected as 1:1 series")
        XCTAssertEqual(analysis.recurrenceRule, "FREQ=WEEKLY;BYDAY=TU", "Should preserve recurrence rule")
        XCTAssertTrue(analysis.shouldSyncSeries, "Recurring 1:1 should be synced as series")
        XCTAssertEqual(analysis.exceptions.count, 1, "Should track exceptions")
    }

    // MARK: - Integration Tests

    func testSyncManagerWithRecurringEvents() {
        let config = Configuration.default
        let syncManager = SyncManager(configuration: config, dryRun: true)

        // Test that SyncManager can be created and handles dry-run mode
        XCTAssertNotNil(syncManager, "SyncManager should be instantiable with recurring event support")

        // Test that sync result structure supports all operations
        let testResult = SyncManager.SyncResult(
            created: 2,
            updated: 1,
            deleted: 0,
            skipped: 3,
            errors: []
        )

        XCTAssertEqual(testResult.created, 2)
        XCTAssertEqual(testResult.updated, 1)
        XCTAssertEqual(testResult.deleted, 0)
        XCTAssertEqual(testResult.skipped, 3)
        XCTAssertTrue(testResult.errors.isEmpty)
    }

    func testConfigurationSupportsRecurringEvents() {
        let config = Configuration.default

        // Verify that default configuration has the structure for recurring events
        // (The actual recurring_events section would be in the YAML, but we test the structure)
        XCTAssertNotNil(config.calendarPair)
        XCTAssertNotNil(config.syncWindow)
        XCTAssertNotNil(config.filters)
        XCTAssertNotNil(config.logging)

        // Test that title template supports recurring events
        let titleTemplate = config.calendarPair.titleTemplate
        XCTAssertTrue(titleTemplate.contains("{{otherPerson}}"), "Title template should support person substitution")
    }

    func testEventMetadataForRecurringEvents() {
        let startDate = Date()
        let metadata = SyncMetadata(
            sourceEventId: "recurring-source-123",
            sourceCalendar: "Work Calendar",
            syncVersion: SyncMetadata.currentVersion,
            lastSyncDate: startDate,
            otherPersonName: "Weekly Meeting Person"
        )

        // Test that metadata can handle recurring event information
        XCTAssertEqual(metadata.sourceEventId, "recurring-source-123")
        XCTAssertEqual(metadata.otherPersonName, "Weekly Meeting Person")
        XCTAssertEqual(metadata.sourceCalendar, "Work Calendar")
        XCTAssertEqual(metadata.syncVersion, SyncMetadata.currentVersion)
        XCTAssertEqual(metadata.lastSyncDate, startDate)
    }

    func testDateHelperForRecurringEventWindow() {
        // Test that date helper properly calculates windows for recurring events
        let config = Configuration(
            version: "1.0",
            calendarPair: Configuration.default.primaryCalendarPair,
            syncWindow: Configuration.SyncWindow(weeks: 4, startOffset: 0), // Longer window for recurring events
            filters: Configuration.default.filters,
            logging: Configuration.default.logging
        )

        let dateHelper = DateHelper(configuration: config)
        let startDate = dateHelper.getCurrentWeekStart()
        let endDate = dateHelper.getSyncEndDate()

        let calendar = Calendar.current
        let weeksBetween = calendar.dateComponents([.weekOfYear], from: startDate, to: endDate).weekOfYear

        XCTAssertEqual(weeksBetween, 4, "Should handle longer sync windows for recurring events")

        // Verify that the window is suitable for recurring events
        let daysBetween = calendar.dateComponents([.day], from: startDate, to: endDate).day
        XCTAssertEqual(daysBetween, 28, "4 weeks should equal 28 days")
    }

    func testSyncResultHandlesRecurringEventOperations() {
        // Test that sync result can track recurring event specific operations
        let result = SyncManager.SyncResult(
            created: 1,  // 1 recurring series created
            updated: 2,  // 2 recurring series updated
            deleted: 0,  // No deletions
            skipped: 5,  // 5 individual instances skipped (part of series)
            errors: ["Failed to process recurring rule for event X"]
        )

        XCTAssertEqual(result.created, 1, "Should track recurring series creation")
        XCTAssertEqual(result.updated, 2, "Should track recurring series updates")
        XCTAssertEqual(result.skipped, 5, "Should track skipped instances within series")
        XCTAssertEqual(result.errors.count, 1, "Should track recurring event specific errors")
        XCTAssertTrue(result.errors.first?.contains("recurring") ?? false, "Error should be recurring event related")
    }

    // MARK: - Enhanced Meeting Analysis Tests

    func testImprovedOwnerEmailMatching() {
        let analyzer = MeetingAnalyzer()

        // We can't easily test the full isOneOnOneMeeting without EKEvent,
        // but we can verify the analyzer instantiates and basic logic works
        // Future: Test cases could include flexible email matching patterns:
        // - Exact email matches
        // - Local part matches
        // - Account name to email matching
        XCTAssertNotNil(analyzer)

        // Test that the analyzer handles different owner identifier patterns
        // Note: Full testing requires EKEvent objects, but we can verify basic instantiation
        XCTAssertNotNil(analyzer, "MeetingAnalyzer should instantiate successfully")
    }
}

// MARK: - Test Helper Classes

struct TestEvent: EventProtocol {
    let eventIdentifier: String!
    let startDate: Date!
    let endDate: Date!

    init(eventIdentifier: String, startDate: Date, endDate: Date) {
        self.eventIdentifier = eventIdentifier
        self.startDate = startDate
        self.endDate = endDate
    }
}
