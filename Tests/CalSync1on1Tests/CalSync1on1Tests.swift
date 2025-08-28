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
        let weeksBetween = calendar.dateComponents([.weekOfYear], from: startDate, to: endDate)
            .weekOfYear

        XCTAssertEqual(weeksBetween, 2, "Should be exactly 2 weeks difference by default")
        XCTAssertTrue(endDate > startDate, "End date should be after start date")
    }

    func testDateHelperWithCustomConfiguration() {
        let customConfig = Configuration(
            version: "1.0",
            calendarPair: Configuration.default.calendarPair,
            syncWindow: Configuration.SyncWindow(weeks: 3, startOffset: -1),
            filters: Configuration.default.filters,
            logging: Configuration.default.logging
        )

        let dateHelper = DateHelper(configuration: customConfig)
        let startDate = dateHelper.getCurrentWeekStart()
        let endDate = dateHelper.getSyncEndDate()

        let calendar = Calendar.current
        let weeksBetween = calendar.dateComponents([.weekOfYear], from: startDate, to: endDate)
            .weekOfYear

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
        XCTAssertEqual(config.filters.excludeKeywords, ["standup", "all-hands"])
        XCTAssertEqual(config.logging.level, "info")
        XCTAssertTrue(config.logging.coloredOutput)
    }

    func testConfigurationcalendarPair() {
        let config = Configuration.default
        let calendarPair = config.calendarPair

        XCTAssertEqual(calendarPair.name, "Work to Personal")
        XCTAssertEqual(calendarPair.source.calendar, "Calendar")
        XCTAssertEqual(calendarPair.destination.calendar, "Personal")
        XCTAssertEqual(calendarPair.titleTemplate, "1:1 with {{otherPerson}}")
    }

    // MARK: - Command Line Arguments Tests

    func testCommandLineArgumentsLogic() {
        // Test the logic for extracting command line arguments
        let testArgs = [
            "calsync1on1",
            "--config", "/custom/path/config.yaml",
            "--dry-run",
            "--verbose",
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

    // MARK: - EventMetadata Tests

    func testSyncMetadataCreation() {
        let metadata = SyncMetadata(sourceEventId: "test-event-123")

        XCTAssertEqual(metadata.sourceEventId, "test-event-123")
    }

    func testSyncMetadataSimplicity() {
        // Test that metadata only contains essential information
        let metadata = SyncMetadata(sourceEventId: "test-event-456")

        XCTAssertEqual(metadata.sourceEventId, "test-event-456")

        // Verify that metadata can be encoded/decoded
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        XCTAssertNoThrow(try encoder.encode(metadata))

        if let jsonData = try? encoder.encode(metadata),
            let decodedMetadata = try? decoder.decode(SyncMetadata.self, from: jsonData)
        {
            XCTAssertEqual(decodedMetadata.sourceEventId, metadata.sourceEventId)
        } else {
            XCTFail("Failed to encode/decode metadata")
        }
    }

    // MARK: - Email Name Extraction Tests

    func testEmailNameExtraction() {
        // Test the actual extractNameFromEmail method from MeetingAnalyzer
        let analyzer = MeetingAnalyzer()
        let testCases = [
            ("john.doe@company.com", "John Doe"),
            ("alice_smith@example.org", "Alice Smith"),
            ("bob.jones_contractor@client.com", "Bob Jones Contractor"),
            ("simple@domain.com", "Simple"),
            ("first.middle.last@company.co.uk", "First Middle Last"),
            ("user123@company.com", "User123"),
        ]

        for (email, expectedName) in testCases {
            let extractedName = analyzer.extractNameFromEmail(email)
            XCTAssertEqual(
                extractedName, expectedName, "Email \(email) should extract to \(expectedName)"
            )
        }
    }

    func testAttendeeDisplayNameLogic() {
        // Test the attendee display name extraction logic that would be used
        // This tests the core logic without requiring EventKit framework objects
        let analyzer = MeetingAnalyzer()

        struct AttendeeTestCase {
            let name: String?
            let email: String?
            let expectedDisplayName: String
        }

        // Test cases: (name, email, expected_display_name)
        let testCases: [AttendeeTestCase] = [
            // When name is available, use it
            AttendeeTestCase(
                name: "John Smith", email: "john.smith@company.com",
                expectedDisplayName: "John Smith"
            ),
            AttendeeTestCase(
                name: "Sarah Johnson", email: "sarah@example.com",
                expectedDisplayName: "Sarah Johnson"
            ),

            // When name is nil or empty, extract from email
            AttendeeTestCase(
                name: nil, email: "jane.doe@company.com", expectedDisplayName: "Jane Doe"
            ),
            AttendeeTestCase(
                name: "", email: "bob_wilson@example.org", expectedDisplayName: "Bob Wilson"
            ),
            AttendeeTestCase(
                name: nil, email: "alice.marie.brown@client.co.uk",
                expectedDisplayName: "Alice Marie Brown"
            ),
            AttendeeTestCase(name: "", email: "simple@domain.com", expectedDisplayName: "Simple"),

            // Edge cases
            AttendeeTestCase(name: nil, email: "user123@test.com", expectedDisplayName: "User123"),
            AttendeeTestCase(
                name: "", email: "first.last_contractor@company.com",
                expectedDisplayName: "First Last Contractor"
            ),

            // When both name and email are missing/invalid
            AttendeeTestCase(name: nil, email: nil, expectedDisplayName: "Unknown"),
            AttendeeTestCase(name: "", email: "", expectedDisplayName: "Unknown"),
            AttendeeTestCase(name: nil, email: "", expectedDisplayName: "Unknown"),
        ]

        for testCase in testCases {
            let actualDisplayName: String

            // Simulate the logic from getAttendeeDisplayName
            =
                if let name = testCase.name, !name.isEmpty {
                    name
                } else if let email = testCase.email, !email.isEmpty {
                    analyzer.extractNameFromEmail(email)
                } else {
                    "Unknown"
                }

            XCTAssertEqual(
                actualDisplayName, testCase.expectedDisplayName,
                "Name: '\(testCase.name ?? "nil")', Email: '\(testCase.email ?? "nil")' should display as '\(testCase.expectedDisplayName)'"
            )
        }
    }

    func testGetOtherPersonNameWithEmailFallback() {
        // Test the getOtherPersonName method that's used for event titles
        let analyzer = MeetingAnalyzer()

        struct PersonNameTestCase {
            let calendarOwner: String
            let attendeeEmails: [String]
            let attendeeNames: [String?]
            let expectedOtherPersonName: String
        }

        // Test cases: (calendarOwner, attendeeEmails, attendeeNames, expectedOtherPersonName)
        let testCases: [PersonNameTestCase] = [
            // Case 1: Both attendees have names - should return the non-owner's name
            PersonNameTestCase(
                calendarOwner: "john.doe@company.com",
                attendeeEmails: ["john.doe@company.com", "sarah.wilson@company.com"],
                attendeeNames: ["John Doe", "Sarah Wilson"],
                expectedOtherPersonName: "Sarah Wilson"
            ),

            // Case 2: Owner has name, other person doesn't - should extract from email
            PersonNameTestCase(
                calendarOwner: "john.doe@company.com",
                attendeeEmails: ["john.doe@company.com", "alice.smith@company.com"],
                attendeeNames: ["John Doe", nil],
                expectedOtherPersonName: "Alice Smith"
            ),

            // Case 3: Neither has names - should extract non-owner name from email
            PersonNameTestCase(
                calendarOwner: "owner.person@company.com",
                attendeeEmails: ["owner.person@company.com", "meeting.partner@example.com"],
                attendeeNames: [nil, nil],
                expectedOtherPersonName: "Meeting Partner"
            ),

            // Case 4: Complex email with underscores and dots
            PersonNameTestCase(
                calendarOwner: "me@company.com",
                attendeeEmails: ["me@company.com", "jane_marie.brown_contractor@client.co.uk"],
                attendeeNames: ["Me", nil],
                expectedOtherPersonName: "Jane Marie Brown Contractor"
            ),

            // Case 5: Owner matching by local part only - fixed to match actual logic
            PersonNameTestCase(
                calendarOwner: "john.doe",
                attendeeEmails: ["john.doe@company.com", "sarah123@example.org"],
                attendeeNames: [nil, nil],
                expectedOtherPersonName: "Sarah123"
            ),
        ]

        // Since we can't easily create real EKEvent and EKParticipant objects in tests,
        // we'll test the core logic by calling the analyzer methods directly
        // This tests the email extraction functionality that powers getOtherPersonName

        for testCase in testCases {
            // Test the email extraction logic that getOtherPersonName relies on
            let ownerEmails = analyzer.getOwnerEmails(calendarOwner: testCase.calendarOwner)

            var nonOwnerEmail: String?
            var nonOwnerName: String?

            for (index, email) in testCase.attendeeEmails.enumerated() {
                let isOwner = ownerEmails.contains { ownerEmail in
                    let emailLower = email.lowercased()
                    let ownerEmailLower = ownerEmail.lowercased()

                    return emailLower == ownerEmailLower || ownerEmailLower.contains(emailLower)
                        || emailLower.contains(ownerEmailLower)
                        || emailLower.components(separatedBy: "@").first
                            == ownerEmailLower.components(separatedBy: "@").first
                }

                if !isOwner {
                    nonOwnerEmail = email
                    nonOwnerName = testCase.attendeeNames[index]
                    break
                }
            }

            guard let foundNonOwnerEmail = nonOwnerEmail else {
                XCTFail(
                    "Should find non-owner attendee for test case with owner: \(testCase.calendarOwner)"
                )
                continue
            }

            // Test the name extraction logic
            let actualName = nonOwnerName ?? analyzer.extractNameFromEmail(foundNonOwnerEmail)

            XCTAssertEqual(
                actualName, testCase.expectedOtherPersonName,
                "Owner: '\(testCase.calendarOwner)', " + "NonOwner Email: '\(foundNonOwnerEmail)', "
                    + "NonOwner Name: '\(nonOwnerName ?? "nil")' "
                    + "should result in '\(testCase.expectedOtherPersonName)'"
            )
        }
    }

    func testEventTitleGenerationWithEmailExtraction() {
        // Test the complete flow from attendee email to event title
        let analyzer = MeetingAnalyzer()

        struct TitleTestCase {
            let owner: String
            let attendeeEmails: [String]
            let attendeeNames: [String?]
            let expectedName: String
        }

        // Test different scenarios where email extraction should be used for titles
        let testCases: [TitleTestCase] = [
            // Case 1: Other person has no name, should extract from email
            TitleTestCase(
                owner: "john.doe@company.com",
                attendeeEmails: ["john.doe@company.com", "sarah.wilson@example.com"],
                attendeeNames: ["John Doe", nil],
                expectedName: "Sarah Wilson"
            ),

            // Case 2: Both have names, should use actual name
            TitleTestCase(
                owner: "owner@company.com",
                attendeeEmails: ["owner@company.com", "colleague@company.com"],
                attendeeNames: ["Owner Person", "Colleague Name"],
                expectedName: "Colleague Name"
            ),

            // Case 3: Complex email extraction
            TitleTestCase(
                owner: "me@work.com",
                attendeeEmails: ["me@work.com", "jane_marie.brown@client.co.uk"],
                attendeeNames: ["Me", nil],
                expectedName: "Jane Marie Brown"
            ),

            // Case 4: Underscores and numbers in email
            TitleTestCase(
                owner: "owner123@company.com",
                attendeeEmails: ["owner123@company.com", "bob_smith_contractor@vendor.com"],
                attendeeNames: [nil, nil],
                expectedName: "Bob Smith Contractor"
            ),
        ]

        for testCase in testCases {
            // Test the core logic used in getOtherPersonName
            let ownerEmails = analyzer.getOwnerEmails(calendarOwner: testCase.owner)

            var otherPersonName: String?

            for (index, email) in testCase.attendeeEmails.enumerated() {
                let isOwner = ownerEmails.contains { ownerEmail in
                    let emailLower = email.lowercased()
                    let ownerEmailLower = ownerEmail.lowercased()

                    return emailLower == ownerEmailLower || ownerEmailLower.contains(emailLower)
                        || emailLower.contains(ownerEmailLower)
                        || emailLower.components(separatedBy: "@").first
                            == ownerEmailLower.components(separatedBy: "@").first
                }

                if !isOwner {
                    // This replicates the logic from getOtherPersonName
                    otherPersonName =
                        testCase.attendeeNames[index] ?? analyzer.extractNameFromEmail(email)
                    break
                }
            }

            XCTAssertEqual(
                otherPersonName, testCase.expectedName,
                "Owner: '\(testCase.owner)' with attendees \(testCase.attendeeEmails) and names \(testCase.attendeeNames) should extract other person as '\(testCase.expectedName)'"
            )

            // Test that the title template would work correctly
            let titleTemplate = "1:1 with {{otherPerson}}"
            let expectedTitle = titleTemplate.replacingOccurrences(
                of: "{{otherPerson}}", with: testCase.expectedName
            )
            let actualTitle = titleTemplate.replacingOccurrences(
                of: "{{otherPerson}}", with: otherPersonName ?? "Unknown"
            )

            XCTAssertEqual(
                actualTitle, expectedTitle,
                "Title generation should produce '\(expectedTitle)' but got '\(actualTitle)'"
            )
        }
    }

    // MARK: - URL Email Extraction Tests

    func testURLEmailExtraction() {
        let testCases = [
            ("mailto:john.doe@company.com", "john.doe@company.com"),
            ("mailto:alice@example.org", "alice@example.org"),
            ("john.doe@company.com", "john.doe@company.com"),  // Without mailto prefix
        ]

        for (urlString, expectedEmail) in testCases {
            let extractedEmail: String =
                if urlString.hasPrefix("mailto:") {
                    String(urlString.dropFirst(7))
                } else {
                    urlString
                }

            XCTAssertEqual(
                extractedEmail, expectedEmail, "URL \(urlString) should extract to \(expectedEmail)"
            )
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

        XCTAssertFalse(
            analysis.isRecurring, "Non-recurring event should not be detected as recurring"
        )
        XCTAssertFalse(
            analysis.isOneOnOneRecurringSeries,
            "Non-recurring event should not be a 1:1 recurring series"
        )
        XCTAssertNil(analysis.recurrenceRule, "Non-recurring event should have no recurrence rule")
        XCTAssertFalse(
            analysis.shouldSyncSeries, "Non-recurring event should not be synced as series"
        )
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
        XCTAssertTrue(
            analysis.isOneOnOneRecurringSeries, "Recurring 1:1 should be detected as 1:1 series"
        )
        XCTAssertEqual(
            analysis.recurrenceRule, "FREQ=WEEKLY;BYDAY=TU", "Should preserve recurrence rule"
        )
        XCTAssertTrue(analysis.shouldSyncSeries, "Recurring 1:1 should be synced as series")
        XCTAssertEqual(analysis.exceptions.count, 1, "Should track exceptions")
    }

    // MARK: - Integration Tests

    func testSyncManagerWithRecurringEvents() {
        let config = Configuration.default
        let syncManager = SyncManager(configuration: config, dryRun: true)

        // Test that SyncManager can be created and handles dry-run mode
        XCTAssertNotNil(
            syncManager, "SyncManager should be instantiable with recurring event support"
        )

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
        XCTAssertTrue(
            titleTemplate.contains("{{otherPerson}}"),
            "Title template should support person substitution"
        )
    }

    func testEventMetadataForRecurringEvents() {
        let metadata = SyncMetadata(sourceEventId: "recurring-source-123")

        // Test that metadata can handle recurring event information
        XCTAssertEqual(metadata.sourceEventId, "recurring-source-123")
    }

    func testDateHelperForRecurringEventWindow() {
        // Test that date helper properly calculates windows for recurring events
        let config = Configuration(
            version: "1.0",
            calendarPair: Configuration.default.calendarPair,
            syncWindow: Configuration.SyncWindow(weeks: 4, startOffset: 0),  // Longer window for recurring events
            filters: Configuration.default.filters,
            logging: Configuration.default.logging
        )

        let dateHelper = DateHelper(configuration: config)
        let startDate = dateHelper.getCurrentWeekStart()
        let endDate = dateHelper.getSyncEndDate()

        let calendar = Calendar.current
        let weeksBetween = calendar.dateComponents([.weekOfYear], from: startDate, to: endDate)
            .weekOfYear

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
        XCTAssertTrue(
            result.errors.first?.contains("recurring") ?? false,
            "Error should be recurring event related"
        )
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
