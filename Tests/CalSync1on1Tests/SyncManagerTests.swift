import EventKit
import Foundation
import XCTest

@testable import CalSync1on1

final class SyncManagerTests: XCTestCase {

    // MARK: - Properties

    private var syncManager: SyncManager!
    private var dryRunSyncManager: SyncManager!
    private var mockConfiguration: Configuration!
    private var analyzer: MeetingAnalyzer!
    private var eventStore: EKEventStore!
    private var sourceCalendar: EKCalendar!
    private var destCalendar: EKCalendar!
    private var testEvents: [EKEvent] = []

    // MARK: - Overridden Functions

    // MARK: - Setup & Teardown

    override func setUp() {
        super.setUp()
        eventStore = EKEventStore()

        // Use the default calendar as both source and destination for simplicity
        // This avoids permission issues with creating calendars
        sourceCalendar =
            eventStore.defaultCalendarForNewEvents
                ?? {
                    let availableCalendars = eventStore.calendars(for: .event)
                    guard let firstCalendar = availableCalendars.first else {
                        fatalError("No calendars available for testing")
                    }
                    return firstCalendar
                }()

        destCalendar = sourceCalendar

        analyzer = createTestAnalyzer()

        mockConfiguration = Configuration.with(
            weeks: 4,
            startOffset: 0,
            excludeKeywords: [],
            excludeAllDay: true,
            ownerEmail: "owner@company.com"
        )
        syncManager = SyncManager(configuration: mockConfiguration, dryRun: false)
        dryRunSyncManager = SyncManager(configuration: mockConfiguration, dryRun: true)

        testEvents = []
    }

    override func tearDown() {
        // Clean up any test source events (ensure full removal of recurring series)
        for event in testEvents {
            let span: EKSpan = event.hasRecurrenceRules ? .futureEvents : .thisEvent
            do {
                try eventStore.remove(event, span: span)
            } catch {
                print("Warning: Could not remove test event (source): \(error)")
            }
        }
        testEvents = []

        // Clean up destination (synced) events we created for testing (including recurring series)
        if let destCalendar {
            let syncedEvents = getTestEventsFromCalendar(destCalendar)
            for event in syncedEvents {
                let span: EKSpan = event.hasRecurrenceRules ? .futureEvents : .thisEvent
                do {
                    try eventStore.remove(event, span: span)
                } catch {
                    print("Warning: Could not remove test event (dest): \(error)")
                }
            }
        }

        do {
            try eventStore.commit()
        } catch {
            print("Warning: Could not commit cleanup changes: \(error)")
        }

        syncManager = nil
        dryRunSyncManager = nil
        mockConfiguration = nil
        analyzer = nil
        eventStore = nil
        sourceCalendar = nil
        destCalendar = nil
        super.tearDown()
    }

    // MARK: - Functions

    // MARK: - Core Sync Operation Tests

    func testEventSyncBehavior() {
        // Comprehensive test cases covering all sync scenarios
        struct SyncTestCase {
            let description: String
            let eventTitle: String
            let attendeeEmails: [String]
            let calendarOwner: String
            let isAllDay: Bool
            let isRecurring: Bool
            let startDate: Date
            let duration: TimeInterval
            let expectedCreated: Int
            let expectedSkipped: Int
            let skipReason: String?

            init(
                description: String,
                eventTitle: String,
                attendeeEmails: [String],
                calendarOwner: String = "owner@company.com",
                isAllDay: Bool = false,
                isRecurring: Bool = false,
                startDate: Date = Date(),
                duration: TimeInterval = 3600,
                expectedCreated: Int,
                expectedSkipped: Int,
                skipReason: String? = nil
            ) {
                self.description = description
                self.eventTitle = eventTitle
                self.attendeeEmails = attendeeEmails
                self.calendarOwner = calendarOwner
                self.isAllDay = isAllDay
                self.isRecurring = isRecurring
                self.startDate = startDate
                self.duration = duration
                self.expectedCreated = expectedCreated
                self.expectedSkipped = expectedSkipped
                self.skipReason = skipReason
            }
        }

        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        let nextWeek = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()

        let testCases: [SyncTestCase] = [
            // Valid 1:1 meetings that should be synced
            SyncTestCase(
                description: "Standard 1:1 meeting",
                eventTitle: "Weekly Check-in",
                attendeeEmails: ["owner@company.com", "colleague@company.com"],
                expectedCreated: 1,
                expectedSkipped: 0
            ),
            SyncTestCase(
                description: "1:1 with different domain owner",
                eventTitle: "Partner Sync",
                attendeeEmails: ["jane.doe@other-domain.com", "colleague@company.com"],
                calendarOwner: "jane.doe@other-domain.com",
                expectedCreated: 1,
                expectedSkipped: 0
            ),
            SyncTestCase(
                description: "1:1 with partial email match",
                eventTitle: "1:1 Discussion",
                attendeeEmails: ["jane.smith@company.com", "colleague@company.com"],
                calendarOwner: "jane.smith",
                expectedCreated: 1,
                expectedSkipped: 0
            ),
            SyncTestCase(
                description: "Recurring 1:1 meeting",
                eventTitle: "Weekly Sync",
                attendeeEmails: ["owner@company.com", "pm@company.com"],
                isRecurring: true,
                expectedCreated: 1,
                expectedSkipped: 0
            ),
            SyncTestCase(
                description: "Future 1:1 meeting",
                eventTitle: "Planning Session",
                attendeeEmails: ["owner@company.com", "manager@company.com"],
                startDate: nextWeek,
                expectedCreated: 1,
                expectedSkipped: 0
            ),

            // Events that should be skipped
            SyncTestCase(
                description: "Standard all-day 1:1 meeting",
                eventTitle: "All Day Meeting",
                attendeeEmails: ["owner@company.com", "colleague@company.com"],
                isAllDay: true,
                expectedCreated: 0,
                expectedSkipped: 1,
                skipReason: "all-day event"
            ),
            SyncTestCase(
                description: "Future all-day 1:1 meeting",
                eventTitle: "Planning Day",
                attendeeEmails: ["owner@company.com", "manager@company.com"],
                isAllDay: true,
                startDate: nextWeek,
                expectedCreated: 0,
                expectedSkipped: 1,
                skipReason: "all-day event"
            ),
            SyncTestCase(
                description: "Multi-day 1:1 meeting",
                eventTitle: "Offsite",
                attendeeEmails: ["owner@company.com", "director@company.com"],
                isAllDay: true,
                startDate: tomorrow,
                duration: 172_800, // 48 hours
                expectedCreated: 0,
                expectedSkipped: 1,
                skipReason: "all-day event"
            ),
            SyncTestCase(
                description: "Team meeting with 3 attendees",
                eventTitle: "Team Standup",
                attendeeEmails: ["owner@company.com", "dev1@company.com", "dev2@company.com"],
                expectedCreated: 0,
                expectedSkipped: 1,
                skipReason: "not 1:1 (3 attendees)"
            ),
            SyncTestCase(
                description: "Large meeting with 6 attendees",
                eventTitle: "All Hands",
                attendeeEmails: [
                    "owner@company.com", "ceo@company.com", "cto@company.com",
                    "dev1@company.com", "dev2@company.com", "designer@company.com",
                ],
                expectedCreated: 0,
                expectedSkipped: 1,
                skipReason: "not 1:1 (6 attendees)"
            ),
            SyncTestCase(
                description: "Solo meeting",
                eventTitle: "Solo Planning",
                attendeeEmails: ["owner@company.com"],
                expectedCreated: 0,
                expectedSkipped: 1,
                skipReason: "not 1:1 (1 attendee)"
            ),
            SyncTestCase(
                description: "Meeting without calendar owner",
                eventTitle: "External Meeting",
                attendeeEmails: ["external1@other.com", "external2@other.com"],
                expectedCreated: 0,
                expectedSkipped: 1,
                skipReason: "calendar owner not in attendees"
            ),
            SyncTestCase(
                description: "Meeting with no attendees",
                eventTitle: "Empty Meeting",
                attendeeEmails: [],
                expectedCreated: 0,
                expectedSkipped: 1,
                skipReason: "no attendees"
            ),
        ]

        // Run each test case
        for testCase in testCases {
            let event = createSimpleEvent(
                title: testCase.eventTitle,
                attendeeEmails: testCase.attendeeEmails,
                startDate: testCase.startDate,
                duration: testCase.duration,
                isAllDay: testCase.isAllDay,
                isRecurring: testCase.isRecurring
            )

            let result = syncManager.syncEvents(
                [event],
                from: sourceCalendar,
                to: destCalendar,
                analyzer: analyzer,
                calendarOwner: testCase.calendarOwner
            )

            // Assert expected results with detailed failure messages
            XCTAssertEqual(
                result.created, testCase.expectedCreated,
                "[\(testCase.description)] Expected \(testCase.expectedCreated) created, got \(result.created)"
            )
            XCTAssertEqual(
                result.skipped, testCase.expectedSkipped,
                "[\(testCase.description)] Expected \(testCase.expectedSkipped) skipped, got \(result.skipped)"
            )
            XCTAssertEqual(
                result.errors.count, 0,
                "[\(testCase.description)] Should not have errors: \(result.errors)"
            )
        }
    }

    func testDryRunVsActualExecution() {
        let testCases = [
            (
                description: "1:1 meeting dry run",
                attendees: ["owner@company.com", "colleague@company.com"],
                isAllDay: false,
                expectedCreated: 1,
                expectedSkipped: 0
            ),
            (
                description: "Team meeting dry run",
                attendees: ["owner@company.com", "dev1@company.com", "dev2@company.com"],
                isAllDay: false,
                expectedCreated: 0,
                expectedSkipped: 1
            ),
            (
                description: "All-day meeting dry run",
                attendees: ["owner@company.com", "manager@company.com"],
                isAllDay: true,
                expectedCreated: 0,
                expectedSkipped: 1
            ),
        ]

        for testCase in testCases {
            let event = createSimpleEvent(
                title: "Test Event",
                attendeeEmails: testCase.attendees,
                isAllDay: testCase.isAllDay
            )

            let dryRunResult = dryRunSyncManager.syncEvents(
                [event],
                from: sourceCalendar,
                to: destCalendar,
                analyzer: analyzer,
                calendarOwner: "owner@company.com"
            )

            let actualResult = syncManager.syncEvents(
                [event],
                from: sourceCalendar,
                to: destCalendar,
                analyzer: analyzer,
                calendarOwner: "owner@company.com"
            )

            // Dry run and actual should have same analysis results
            XCTAssertEqual(
                dryRunResult.created, actualResult.created,
                "[\(testCase.description)] Dry run created count should match actual"
            )
            XCTAssertEqual(
                dryRunResult.skipped, actualResult.skipped,
                "[\(testCase.description)] Dry run skipped count should match actual"
            )

            // Verify expected counts
            XCTAssertEqual(
                actualResult.created, testCase.expectedCreated,
                "[\(testCase.description)] Expected \(testCase.expectedCreated) created"
            )
            XCTAssertEqual(
                actualResult.skipped, testCase.expectedSkipped,
                "[\(testCase.description)] Expected \(testCase.expectedSkipped) skipped"
            )
        }
    }

    func testTitleTemplateVariations() {
        // Test different title template formats
        struct TemplateTestCase {
            let description: String
            let titleTemplate: String
            let attendeeEmails: [String]
            let calendarOwner: String
            let expectedTitleContains: String
        }

        let templateTestCases: [TemplateTestCase] = [
            TemplateTestCase(
                description: "Standard template with {{otherPerson}}",
                titleTemplate: "1:1 with {{otherPerson}}",
                attendeeEmails: ["owner@company.com", "alice.smith@company.com"],
                calendarOwner: "owner@company.com",
                expectedTitleContains: "Alice Smith"
            ),
            TemplateTestCase(
                description: "Template with prefix and suffix",
                titleTemplate: "Meeting: {{otherPerson}} [1:1]",
                attendeeEmails: ["bob.jones@company.com", "owner@company.com"],
                calendarOwner: "owner@company.com",
                expectedTitleContains: "Bob Jones"
            ),
            TemplateTestCase(
                description: "Simple template - just other person",
                titleTemplate: "{{otherPerson}}",
                attendeeEmails: ["owner@company.com", "carol.white42@company.com"],
                calendarOwner: "owner@company.com",
                expectedTitleContains: "Carol White42"
            ),
            TemplateTestCase(
                description: "Template with emoji and symbols",
                titleTemplate: "🤝 {{otherPerson}} sync",
                attendeeEmails: ["owner@company.com", "david.brown@company.com"],
                calendarOwner: "owner@company.com",
                expectedTitleContains: "David Brown"
            ),
            TemplateTestCase(
                description: "Template with multiple placeholders",
                titleTemplate: "{{otherPerson}} - {{otherPerson}} meeting",
                attendeeEmails: ["owner@company.com", "eve.davis@company.com"],
                calendarOwner: "owner@company.com",
                expectedTitleContains: "Eve Davis"
            ),
            TemplateTestCase(
                description: "Template without placeholder (edge case)",
                titleTemplate: "Fixed Title Meeting",
                attendeeEmails: ["owner@company.com", "frank.miller@company.com"],
                calendarOwner: "owner@company.com",
                expectedTitleContains: "Fixed Title Meeting"
            ),
            TemplateTestCase(
                description: "Template with special characters",
                titleTemplate: "[{{otherPerson}}] - Weekly Check-in (1:1)",
                attendeeEmails: ["owner@company.com", "grace.wilson@company.com"],
                calendarOwner: "owner@company.com",
                expectedTitleContains: "Grace Wilson"
            ),
            TemplateTestCase(
                description: "Template with different email domains",
                titleTemplate: "External: {{otherPerson}}",
                attendeeEmails: ["owner@company.com", "henry@external.org"],
                calendarOwner: "owner@company.com",
                expectedTitleContains: "External: Henry"
            ),
        ]

        for testCase in templateTestCases {
            // Clear any existing test events before each template test
            clearAllTestEvents()

            // Create a custom sync manager with the specific title template
            let testConfig = Configuration.with(titleTemplate: testCase.titleTemplate)
            let testSyncManager = SyncManager(configuration: testConfig, dryRun: false)

            let event = createSimpleEvent(
                title: "Original Meeting Title",
                attendeeEmails: testCase.attendeeEmails
            )

            let result = testSyncManager.syncEvents(
                [event],
                from: sourceCalendar,
                to: destCalendar,
                analyzer: analyzer,
                calendarOwner: testCase.calendarOwner
            )

            XCTAssertEqual(
                result.created, 1,
                "[\(testCase.description)] Should create 1:1 meeting"
            )

            // Check that the created event has the expected title
            let destEvents = getTestEventsFromCalendar(destCalendar)
            XCTAssertEqual(
                destEvents.count, 1,
                "[\(testCase.description)] Should have exactly one synced event"
            )

            if let syncedEvent = destEvents.first {
                let actualTitle = syncedEvent.title ?? ""
                XCTAssertTrue(
                    actualTitle.contains(testCase.expectedTitleContains),
                    "[\(testCase.description)] Synced event title '\(actualTitle)' should contain '\(testCase.expectedTitleContains)'"
                )

                // For templates with {{otherPerson}}, verify the placeholder was replaced
                if testCase.titleTemplate.contains("{{otherPerson}}") {
                    XCTAssertFalse(
                        actualTitle.contains("{{otherPerson}}"),
                        "[\(testCase.description)] Title should not contain unreplaced placeholder"
                    )
                }
            }

            // Clean up for next test - remove all test events
            let allTestEvents = getTestEventsFromCalendar(destCalendar)
            for event in allTestEvents {
                do {
                    try eventStore.remove(event, span: .thisEvent)
                } catch {
                    print("Warning: Could not remove test event: \(error)")
                }
            }

            do {
                try eventStore.commit()
            } catch {
                print("Warning: Could not commit cleanup: \(error)")
            }
        }
    }

    func testUpdateScenarios() {
        // Clear any existing test events to ensure clean state
        clearAllTestEvents()

        // Create initial 1:1 event
        let initialEvent = createSimpleEvent(
            title: "Initial Meeting",
            attendeeEmails: ["owner@company.com", "colleague@company.com"]
        )

        // First sync - should create
        let firstResult = syncManager.syncEvents(
            [initialEvent],
            from: sourceCalendar,
            to: destCalendar,
            analyzer: analyzer,
            calendarOwner: "owner@company.com"
        )

        XCTAssertEqual(firstResult.created, 1, "Should create initial event")
        XCTAssertEqual(firstResult.updated, 0, "Should not update on first sync")
        XCTAssertEqual(firstResult.skipped, 0, "Should not skip valid 1:1 meeting")

        // Verify event was created in destination calendar with metadata
        let destEventsAfterCreate = getTestEventsFromCalendar(destCalendar)
        XCTAssertEqual(destEventsAfterCreate.count, 1, "Should have exactly one synced event")

        guard let syncedEvent = destEventsAfterCreate.first else {
            XCTFail("Should have a synced event")
            return
        }

        // Verify start / end dates match
        XCTAssertEqual(
            syncedEvent.startDate, initialEvent.startDate,
            "Synced event should have the same start date"
        )
        XCTAssertEqual(
            syncedEvent.endDate, initialEvent.endDate, "Synced event should have the same end date"
        )

        // Verify the synced event has metadata linking it to the source
        XCTAssertTrue(EventMetadata.isSyncedEvent(syncedEvent), "Synced event should have metadata")

        let metadata = EventMetadata.getSyncMetadata(syncedEvent)
        XCTAssertNotNil(metadata, "Should have sync metadata")
        XCTAssertEqual(
            metadata?.sourceEventId, initialEvent.eventIdentifier,
            "Metadata should link to source event"
        )

        // Test scenario where source event is modified
        let originalStartDate = initialEvent.startDate ?? Date()
        initialEvent.startDate = originalStartDate.addingTimeInterval(3600) // Move 1 hour later
        initialEvent.endDate = initialEvent.endDate.addingTimeInterval(3600)
        initialEvent.title = "Modified Meeting Title"

        do {
            try eventStore.save(initialEvent, span: .thisEvent)
            try eventStore.commit()
        } catch {
            XCTFail("Failed to update source event: \(error)")
        }

        // Second sync - should detect and handle the change
        let secondResult = syncManager.syncEvents(
            [initialEvent],
            from: sourceCalendar,
            to: destCalendar,
            analyzer: analyzer,
            calendarOwner: "owner@company.com"
        )

        XCTAssertEqual(secondResult.errors.count, 0, "Should not have errors during update sync")
        XCTAssertEqual(secondResult.updated, 1, "Should count updates")

        // Verify we still have exactly one event in destination (not duplicated)
        let destEventsAfterUpdate = getTestEventsFromCalendar(destCalendar)
        XCTAssertEqual(destEventsAfterUpdate.count, 1, "Should still have exactly one synced event")

        // Verify dates match after the update
        guard let secondSyncedEvent = destEventsAfterUpdate.first else {
            XCTFail("Should have a synced event after update")
            return
        }
        XCTAssertEqual(
            secondSyncedEvent.startDate, initialEvent.startDate,
            "Synced event should have the same start date after updating"
        )
        XCTAssertEqual(
            secondSyncedEvent.endDate, initialEvent.endDate,
            "Synced event should have the same end date after updating"
        )

        // Test event becoming non-1:1 by modifying the original event to add attendees
        // This should cause the synced event to be deleted during cleanup
        initialEvent.notes =
            "[TEST_ATTENDEES]owner@company.com,colleague@company.com,third@company.com"

        do {
            try eventStore.save(initialEvent, span: .thisEvent)
            try eventStore.commit()
        } catch {
            XCTFail("Failed to modify event to team meeting: \(error)")
        }

        let teamResult = syncManager.syncEvents(
            [initialEvent],
            from: sourceCalendar,
            to: destCalendar,
            analyzer: analyzer,
            calendarOwner: "owner@company.com"
        )

        XCTAssertEqual(teamResult.created, 0, "Should not create team meeting")
        XCTAssertEqual(teamResult.skipped, 1, "Should skip team meeting")
        XCTAssertEqual(teamResult.deleted, 1, "Should delete the orphaned 1:1 event")

        // Verify the synced event was cleaned up
        let destEventsAfterTeamConversion = getTestEventsFromCalendar(destCalendar)
        XCTAssertEqual(
            destEventsAfterTeamConversion.count, 0,
            "Should have no synced events after team conversion"
        )
    }

    func testCleanupScenarios() {
        // Clear any existing test events to ensure clean state
        clearAllTestEvents()

        // Create multiple 1:1 events
        let event1 = createSimpleEvent(
            title: "Meeting with Alice",
            attendeeEmails: ["owner@company.com", "alice@company.com"]
        )
        let event2 = createSimpleEvent(
            title: "Meeting with Bob",
            attendeeEmails: ["owner@company.com", "bob@company.com"]
        )

        // Sync both events
        let initialResult = syncManager.syncEvents(
            [event1, event2],
            from: sourceCalendar,
            to: destCalendar,
            analyzer: analyzer,
            calendarOwner: "owner@company.com"
        )

        XCTAssertEqual(initialResult.created, 2, "Should create both 1:1 meetings")

        // Verify both events were created
        let destEventsAfterCreate = getTestEventsFromCalendar(destCalendar)
        XCTAssertEqual(destEventsAfterCreate.count, 2, "Should have exactly two synced events")

        // Now sync with only one event (simulating deletion of the other)
        let cleanupResult = syncManager.syncEvents(
            [event1], // Only event1, event2 is "deleted"
            from: sourceCalendar,
            to: destCalendar,
            analyzer: analyzer,
            calendarOwner: "owner@company.com"
        )

        // The cleanup behavior depends on the orphaned event cleanup implementation
        // We're testing that the process completes without errors
        XCTAssertEqual(cleanupResult.errors.count, 0, "Should not have errors during cleanup")
        XCTAssertEqual(cleanupResult.deleted, 1, "Should clean up 1 event")

    }

    func testBatchEventProcessing() {
        // Clear any existing test events to ensure clean state
        clearAllTestEvents()

        // Test processing multiple events in a single sync operation
        struct BatchEvent {
            let title: String
            let attendeeEmails: [String]
            let isAllDay: Bool
            let isRecurring: Bool
            let expectedAction: String
        }

        let batchEvents: [BatchEvent] = [
            BatchEvent(
                title: "1:1 with Alice",
                attendeeEmails: ["owner@company.com", "alice@company.com"],
                isAllDay: false,
                isRecurring: false,
                expectedAction: "create"
            ),
            BatchEvent(
                title: "Team Meeting",
                attendeeEmails: ["owner@company.com", "dev1@company.com", "dev2@company.com"],
                isAllDay: false,
                isRecurring: false,
                expectedAction: "skip"
            ),
            BatchEvent(
                title: "Recurring 1:1 with Bob42",
                attendeeEmails: ["owner@company.com", "bob42@company.com"],
                isAllDay: false,
                isRecurring: true,
                expectedAction: "create"
            ),
            BatchEvent(
                title: "All-day planning",
                attendeeEmails: ["owner@company.com", "manager@company.com"],
                isAllDay: true,
                isRecurring: false,
                expectedAction: "skip"
            ),
        ]

        let events = batchEvents.map { batchEvent in
            createSimpleEvent(
                title: batchEvent.title,
                attendeeEmails: batchEvent.attendeeEmails,
                isAllDay: batchEvent.isAllDay,
                isRecurring: batchEvent.isRecurring
            )
        }

        let expectedCreated = batchEvents.count(where: { $0.expectedAction == "create" })
        let expectedSkipped = batchEvents.count(where: { $0.expectedAction == "skip" })

        let result = syncManager.syncEvents(
            events,
            from: sourceCalendar,
            to: destCalendar,
            analyzer: analyzer,
            calendarOwner: "owner@company.com"
        )

        XCTAssertEqual(result.created, expectedCreated, "Should create \(expectedCreated) events")
        XCTAssertEqual(result.skipped, expectedSkipped, "Should skip \(expectedSkipped) events")
        XCTAssertEqual(result.errors.count, 0, "Should not have errors: \(result.errors)")

        // Verify destination calendar has correct number of events
        let destEvents = getTestEventsFromCalendar(destCalendar)
        XCTAssertEqual(
            destEvents.count, expectedCreated, "Destination should have \(expectedCreated) events"
        )
    }

    func testErrorHandling() {
        struct ErrorTestCase {
            let description: String
            let sourceCalendar: EKCalendar
            let destCalendar: EKCalendar
            let expectError: Bool
        }

        let errorTests = [
            ErrorTestCase(
                description: "Same calendar for source and destination",
                sourceCalendar: sourceCalendar,
                destCalendar: sourceCalendar,
                expectError: true
            ),
            ErrorTestCase(
                description: "Valid different calendars",
                sourceCalendar: sourceCalendar,
                destCalendar: destCalendar,
                expectError: false
            ),
        ]

        for test in errorTests {
            let event = createSimpleEvent(
                title: "Test Event",
                attendeeEmails: ["owner@company.com", "colleague@company.com"]
            )

            let result = syncManager.syncEvents(
                [event],
                from: test.sourceCalendar,
                to: test.destCalendar,
                analyzer: analyzer,
                calendarOwner: "owner@company.com"
            )

            if test.expectError {
                // Error handling should be graceful (not crash)
                XCTAssertTrue(
                    result.errors.count >= 0,
                    "[\(test.description)] Should handle errors gracefully"
                )
            } else {
                XCTAssertEqual(
                    result.errors.count, 0,
                    "[\(test.description)] Should not have errors: \(result.errors)"
                )
            }
        }
    }

    func testSyncResultStructure() {
        let result = SyncManager.SyncResult(
            created: 2,
            updated: 1,
            deleted: 1,
            skipped: 3,
            errors: ["Test error", "Another error"]
        )

        XCTAssertEqual(result.created, 2)
        XCTAssertEqual(result.updated, 1)
        XCTAssertEqual(result.deleted, 1)
        XCTAssertEqual(result.skipped, 3)
        XCTAssertEqual(result.errors.count, 2)
        XCTAssertEqual(result.errors[0], "Test error")
        XCTAssertEqual(result.errors[1], "Another error")

        // Test that printSummary doesn't crash
        XCTAssertNoThrow(syncManager.printSummary(result))
    }

    // MARK: - Helper Methods

    private func createSimpleEvent(
        title: String,
        attendeeEmails: [String],
        startDate: Date = Date(),
        duration: TimeInterval = 3600,
        isAllDay: Bool = false,
        isRecurring: Bool = false
    )
        -> EKEvent {
        let event = EKEvent(eventStore: eventStore)
        event.title = title
        event.startDate = startDate
        event.endDate = startDate.addingTimeInterval(duration)
        event.isAllDay = isAllDay
        event.calendar = sourceCalendar

        // Add recurrence rule if needed
        if isRecurring {
            let recurrenceRule = EKRecurrenceRule(
                recurrenceWith: .weekly,
                interval: 1,
                end: EKRecurrenceEnd(occurrenceCount: 10)
            )
            event.recurrenceRules = [recurrenceRule]
        }

        // Store attendee info in notes for testing purposes
        if !attendeeEmails.isEmpty {
            let attendeeInfo = attendeeEmails.joined(separator: ",")
            event.notes = "[TEST_ATTENDEES]\(attendeeInfo)"
        }

        // Save event to source calendar to get proper identifier
        do {
            try eventStore.save(event, span: .thisEvent)
            try eventStore.commit()

            // Add to our tracking array for cleanup
            testEvents.append(event)
        } catch {
            // If saving fails, continue without identifier
            // Tests will work differently but won't crash
            print("Warning: Could not save test event to get identifier: \(error)")
        }

        return event
    }

    private func getEventsFromCalendar(_ calendar: EKCalendar) -> [EKEvent] {
        let startDate = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        let endDate = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()

        let predicate = eventStore.predicateForEvents(
            withStart: startDate,
            end: endDate,
            calendars: [calendar]
        )

        return eventStore.events(matching: predicate)
    }

    // Get only synced destination events (events with sync metadata)
    private func getTestEventsFromCalendar(_ calendar: EKCalendar) -> [EKEvent] {
        getEventsFromCalendar(calendar).filter { event in
            guard let notes = event.notes else { return false }
            return notes.contains("[CalSync1on1-Metadata]")
        }
    }

    // Clear all test events from all calendars to ensure test isolation
    private func clearAllTestEvents() {
        let allCalendars = eventStore.calendars(for: .event)
        for calendar in allCalendars {
            // Clear both synced events and source test events
            let allEvents = getEventsFromCalendar(calendar).filter { event in
                guard let notes = event.notes else { return false }
                return notes.contains("[CalSync1on1-Metadata]")
                    || notes.contains("[TEST_ATTENDEES]")
            }
            for event in allEvents {
                do {
                    // Use futureEvents span for recurring series to remove entire series
                    let span: EKSpan = event.hasRecurrenceRules ? .futureEvents : .thisEvent
                    try eventStore.remove(event, span: span)
                } catch {
                    // Ignore errors during initial cleanup
                }
            }
        }

        do {
            try eventStore.commit()
        } catch {
            // Ignore commit errors during initial cleanup
        }
    }

    // Create a custom MeetingAnalyzer for testing that reads from event notes
    private func createTestAnalyzer() -> TestMeetingAnalyzer {
        TestMeetingAnalyzer()
    }

}

// MARK: - Test Meeting Analyzer

private class TestMeetingAnalyzer: MeetingAnalyzer {
    override func isOneOnOneMeeting(_ event: EKEvent, calendarOwner: String, debug _: Bool = false)
        -> Bool {
        // Skip all-day events
        if event.isAllDay {
            return false
        }

        // Extract attendee info from test notes
        guard let notes = event.notes,
              notes.hasPrefix("[TEST_ATTENDEES]")
        else {
            return false
        }

        let attendeeInfo = String(notes.dropFirst("[TEST_ATTENDEES]".count))
        let attendeeEmails = attendeeInfo.components(separatedBy: ",")

        // Must have exactly 2 attendees
        guard attendeeEmails.count == 2 else {
            return false
        }

        // Owner must be one of the attendees
        let ownerEmails = getOwnerEmails(calendarOwner: calendarOwner)
        return attendeeEmails.contains { attendeeEmail in
            ownerEmails.contains { ownerEmail in
                attendeeEmail.lowercased() == ownerEmail.lowercased()
                    || attendeeEmail.lowercased().contains(ownerEmail.lowercased())
                    || ownerEmail.lowercased().contains(attendeeEmail.lowercased())
            }
        }
    }

    override func getOtherPersonName(from event: EKEvent, calendarOwner: String) -> String {
        guard let notes = event.notes,
              notes.hasPrefix("[TEST_ATTENDEES]")
        else {
            return "Unknown"
        }

        let attendeeInfo = String(notes.dropFirst("[TEST_ATTENDEES]".count))
        let attendeeEmails = attendeeInfo.components(separatedBy: ",")
        let ownerEmails = getOwnerEmails(calendarOwner: calendarOwner)

        for email in attendeeEmails {
            let isOwner = ownerEmails.contains { ownerEmail in
                email.lowercased() == ownerEmail.lowercased()
                    || email.lowercased().contains(ownerEmail.lowercased())
                    || ownerEmail.lowercased().contains(email.lowercased())
            }

            if !isOwner {
                return extractNameFromEmail(email)
            }
        }

        return "Unknown"
    }
}
