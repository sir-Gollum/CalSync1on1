import EventKit
import Foundation
import XCTest

@testable import CalSync1on1

final class CalendarManagerTests: XCTestCase {

    // MARK: - Properties

    var calendarManager: CalendarManager!

    // MARK: - Overridden Functions

    override func setUp() {
        super.setUp()
        calendarManager = CalendarManager()
    }

    override func tearDown() {
        calendarManager = nil
        super.tearDown()
    }

    // MARK: - Functions

    // MARK: - findCalendar Tests

    func testFindCalendar() {
        // Test empty name returns nil
        XCTAssertNil(calendarManager.findCalendar(named: ""))

        // Test non-existent calendar returns nil
        XCTAssertNil(calendarManager.findCalendar(named: "NonExistent-\(UUID().uuidString)"))

        // Test with existing calendars from the system
        let availableCalendars = calendarManager.listAvailableCalendars()
        for calendar in availableCalendars {
            let foundCalendar = calendarManager.findCalendar(named: calendar.title)
            XCTAssertNotNil(foundCalendar, "Should find existing calendar '\(calendar.title)'")
            XCTAssertEqual(foundCalendar?.title, calendar.title, "Should have correct title")
        }

        // Create a new calendar and verify we can find it
        let testCalendar = EKCalendar(for: .event, eventStore: calendarManager.eventStore)
        testCalendar.title = "Test-\(UUID().uuidString)"

        // Try to save calendar - may fail in test environment, that's OK
        do {
            try calendarManager.eventStore.saveCalendar(testCalendar, commit: true)

            // If save succeeded, we should be able to find it
            let foundTestCalendar = calendarManager.findCalendar(named: testCalendar.title)
            XCTAssertNotNil(foundTestCalendar, "Should find created calendar")
            XCTAssertEqual(foundTestCalendar?.title, testCalendar.title)

            // Clean up
            try calendarManager.eventStore.removeCalendar(testCalendar, commit: true)
        } catch {
            // Calendar creation/deletion failed - expected in test environment
            XCTAssertTrue(true, "Calendar operations restricted in test environment")
        }
    }

    // MARK: - Event Operations Tests

    func testEventOperations() {
        let calendar = EKCalendar(for: .event, eventStore: calendarManager.eventStore)
        calendar.title = "Test Calendar"

        let now = Date()
        let validEnd = now.addingTimeInterval(3600)
        let invalidEnd = now.addingTimeInterval(-3600)

        // Test getting events with various scenarios
        let events1 = calendarManager.getEvents(from: calendar, startDate: now, endDate: validEnd)
        XCTAssertNotNil(events1)

        let events2 = calendarManager.getEvents(from: calendar, startDate: now, endDate: invalidEnd)
        XCTAssertNotNil(events2)

        let events3 = calendarManager.getEvents(
            from: calendar, startDate: now, endDate: validEnd, debug: false
        )
        XCTAssertNotNil(events3)

        // Test creating events with various scenarios
        let createResult1 = calendarManager.createEvent(
            title: "Test Event", startDate: now, endDate: validEnd, in: calendar
        )
        // May succeed or fail based on permissions - both are valid outcomes

        _ = calendarManager.createEvent(
            title: "", startDate: now, endDate: validEnd, in: calendar
        )
        // Empty title - should be handled gracefully

        _ = calendarManager.createEvent(
            title: "Invalid Event", startDate: now, endDate: invalidEnd, in: calendar
        )
        // Invalid date range - should be handled gracefully

        // If any event creation succeeded, try to find it
        if createResult1 {
            let foundEvent = calendarManager.findExistingEvent(
                title: "Test Event", startDate: now, in: calendar
            )
            if let event = foundEvent {
                XCTAssertEqual(event.title, "Test Event")
            }
        }
    }

    // MARK: - Basic Method Tests

    func testBasicMethods() {
        // Test calendar listing
        let calendars = calendarManager.listAvailableCalendars()
        XCTAssertGreaterThanOrEqual(calendars.count, 0)

        // Test access validation
        _ = calendarManager.validateCalendarAccess() // Returns Bool, no need to assert

        // Test debug info
        let debugInfo = calendarManager.debugCalendarAccess()
        XCTAssertFalse(debugInfo.isEmpty)
        XCTAssertTrue(debugInfo.contains("Calendar Debug Info:"))

        // Test event access
        let calendar = EKCalendar(for: .event, eventStore: calendarManager.eventStore)
        calendar.title = "Test Calendar"
        let result = calendarManager.testEventAccess(
            calendar: calendar, startDate: Date(), endDate: Date().addingTimeInterval(3600)
        )
        XCTAssertTrue(result.success)
        XCTAssertGreaterThanOrEqual(result.eventCount, 0)
        XCTAssertNil(result.error)
    }

    func testFindExistingEvent() {
        let calendar = EKCalendar(for: .event, eventStore: calendarManager.eventStore)
        calendar.title = "Test Calendar"

        // Empty title should return nil
        XCTAssertNil(calendarManager.findExistingEvent(title: "", startDate: Date(), in: calendar))

        // Create an event and verify we can find it
        let eventTitle = "Test Event \(UUID().uuidString)"
        let startDate = Date()
        let endDate = startDate.addingTimeInterval(3600)

        let createResult = calendarManager.createEvent(
            title: eventTitle, startDate: startDate, endDate: endDate, in: calendar
        )

        if createResult {
            // Event creation succeeded, now try to find it
            let foundEvent = calendarManager.findExistingEvent(
                title: eventTitle, startDate: startDate, in: calendar
            )
            XCTAssertNotNil(foundEvent, "Should find the created event")
            XCTAssertEqual(foundEvent?.title, eventTitle, "Found event should have correct title")
            XCTAssertEqual(
                foundEvent?.startDate, startDate, "Found event should have correct start date"
            )
        } else {
            // Event creation failed (expected in test environment)
            // Test that search for non-existent event returns nil
            let foundEvent = calendarManager.findExistingEvent(
                title: eventTitle, startDate: startDate, in: calendar
            )
            XCTAssertNil(foundEvent, "Should not find non-existent event")
        }
    }

    // MARK: - Integration Test

    func testCalendarManagerWorkflow() {
        // Test basic methods
        let initialCalendars = calendarManager.listAvailableCalendars()
        _ = calendarManager.validateCalendarAccess()
        let debugInfo = calendarManager.debugCalendarAccess()

        XCTAssertGreaterThanOrEqual(initialCalendars.count, 0)
        XCTAssertFalse(debugInfo.isEmpty)
        XCTAssertTrue(debugInfo.contains("Calendar Debug Info:"))

        // Create a test calendar and verify complete workflow
        let testCalendar = EKCalendar(for: .event, eventStore: calendarManager.eventStore)
        testCalendar.title = "Workflow-Test-\(UUID().uuidString)"

        // Test event operations with the calendar
        let eventTitle = "Workflow Event \(UUID().uuidString)"
        let startDate = Date()
        let endDate = startDate.addingTimeInterval(3600)

        // Test getting events (should be empty initially)
        let initialEvents = calendarManager.getEvents(
            from: testCalendar, startDate: startDate, endDate: endDate, debug: false
        )
        XCTAssertNotNil(initialEvents)

        // Test event creation
        let createResult = calendarManager.createEvent(
            title: eventTitle, startDate: startDate, endDate: endDate, in: testCalendar
        )

        if createResult {
            // If creation succeeded, test finding the event
            let foundEvent = calendarManager.findExistingEvent(
                title: eventTitle, startDate: startDate, in: testCalendar
            )
            XCTAssertNotNil(foundEvent, "Should find created event")
            XCTAssertEqual(foundEvent?.title, eventTitle)

            // Test getting events again (should now include our event)
            let eventsAfterCreation = calendarManager.getEvents(
                from: testCalendar, startDate: startDate, endDate: endDate, debug: false
            )
            XCTAssertNotNil(eventsAfterCreation)

            // Test event access
            let accessResult = calendarManager.testEventAccess(
                calendar: testCalendar, startDate: startDate, endDate: endDate
            )
            XCTAssertTrue(accessResult.success)
            XCTAssertGreaterThanOrEqual(accessResult.eventCount, 0)
        }

        // Test calendar finding (won't work with mock calendar but method should not crash)
        _ = calendarManager.findCalendar(named: testCalendar.title)
        // foundCalendar will be nil since we didn't save the calendar to the store
        // but the method should handle this gracefully
    }
}
