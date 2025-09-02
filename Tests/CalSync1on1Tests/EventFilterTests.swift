import EventKit
import Foundation
import XCTest

@testable import CalSync1on1

final class EventFilterTests: XCTestCase {

    // MARK: - Properties

    private var eventStore: EKEventStore!

    // MARK: - Overridden Functions

    // MARK: - Setup and Teardown

    override func setUp() {
        super.setUp()
        eventStore = EKEventStore()
    }

    override func tearDown() {
        eventStore = nil
        super.tearDown()
    }

    // MARK: - Functions

    // MARK: - Configuration Helpers

    func createTestConfiguration(
        excludeKeywords: [String] = [
            "standup",
            "scrum",
            "retrospective",
            "all-hands",
            "training",
            "townhall",
        ],
        excludeAllDay: Bool = true,
        weeks: Int = 2,
        startOffset: Int = 0,
        ownerEmail: String = "owner@company.com"
    )
        -> Configuration {
        Configuration(
            version: "1.0",
            calendarPair: Configuration.CalendarPair(
                name: "Test Sync",
                source: Configuration.CalendarPair.CalendarInfo(
                    account: nil,
                    calendar: "Work Calendar"
                ),
                destination: Configuration.CalendarPair.CalendarInfo(
                    account: nil,
                    calendar: "1:1 Meetings"
                ),
                titleTemplate: "1:1 with {person}",
                ownerEmail: ownerEmail
            ),
            syncWindow: Configuration.SyncWindow(
                weeks: weeks,
                startOffset: startOffset
            ),
            filters: Configuration.Filters(
                excludeAllDay: excludeAllDay,
                excludeKeywords: excludeKeywords
            ),
            logging: Configuration.Logging(
                level: "info",
                coloredOutput: false
            )
        )
    }

    // MARK: - Keyword Filtering Tests

    func testKeywordFilteringCaseInsensitive() {
        let configuration = createTestConfiguration(excludeKeywords: ["standup", "scrum"])

        let testCases = [
            ("Daily Standup", false),
            ("STANDUP Meeting", false),
            ("standup with team", false),
            ("Team SCRUM", false),
            ("scrum planning", false),
            ("Project Discussion", true),
            ("1:1 Meeting", true),
        ]

        for (title, shouldPass) in testCases {
            let event = createSimpleEvent(title: title)

            let (passes, reasons) = EventFilter.checkFilters(event, configuration: configuration)

            XCTAssertEqual(
                passes, shouldPass,
                "Event '\(title)' should \(shouldPass ? "pass" : "fail") keyword filter"
            )

            if !shouldPass {
                XCTAssertTrue(
                    reasons.contains { $0.lowercased().contains("keyword") },
                    "Expected keyword-related reason for '\(title)', got: \(reasons)"
                )
            }
        }
    }

    func testKeywordFilteringPartialMatches() {
        let configuration = createTestConfiguration(excludeKeywords: ["standup"])

        let testCases = [
            ("standup", false),
            ("standups", false),
            ("pre-standup", false),
            ("standup-meeting", false),
            ("My standup notes", false),
            ("standard meeting", true), // Should not match "standup"
            ("stand", true), // Should not match "standup"
        ]

        for (title, shouldPass) in testCases {
            let event = createSimpleEvent(title: title)
            let (passes, _) = EventFilter.checkFilters(event, configuration: configuration)

            XCTAssertEqual(
                passes, shouldPass,
                "Event '\(title)' keyword filtering failed expectation"
            )
        }
    }

    func testKeywordFilteringMultipleKeywords() {
        let configuration = createTestConfiguration(
            excludeKeywords: ["standup", "scrum", "retrospective", "planning"]
        )

        let testCases = [
            ("Sprint planning and retrospective", false), // Contains multiple keywords
            ("Standup scrum meeting", false), // Contains multiple keywords
            ("Project planning session", false), // Contains one keyword
            ("Team meeting", true), // Contains no keywords
        ]

        for (title, shouldPass) in testCases {
            let event = createSimpleEvent(title: title)
            let (passes, reasons) = EventFilter.checkFilters(event, configuration: configuration)

            XCTAssertEqual(passes, shouldPass, "Event '\(title)' failed multiple keyword test")

            if !shouldPass, title.contains("planning"), title.contains("retrospective") {
                // Should have reasons for both keywords
                XCTAssertTrue(
                    reasons.count >= 2,
                    "Expected multiple keyword reasons for '\(title)', got: \(reasons)"
                )
            }
        }
    }

    func testKeywordFilteringWithEmptyKeywords() {
        let configuration = createTestConfiguration(excludeKeywords: [])

        let event = createSimpleEvent(title: "standup scrum retrospective")

        let (passes, reasons) = EventFilter.checkFilters(event, configuration: configuration)

        XCTAssertTrue(passes, "Event should pass when no keywords are excluded")
        XCTAssertTrue(
            reasons.isEmpty || !reasons.contains { $0.lowercased().contains("keyword") },
            "Should not have keyword-related reasons when no keywords configured"
        )
    }

    // MARK: - All-Day Event Filtering Tests

    func testAllDayEventFiltering() {
        let configuration = createTestConfiguration(excludeAllDay: true)

        let regularEvent = createSimpleEvent(title: "Regular meeting", isAllDay: false)
        let allDayEvent = createSimpleEvent(title: "All day event", isAllDay: true)

        // Regular event should pass
        let (regularPasses, regularReasons) = EventFilter.checkFilters(
            regularEvent, configuration: configuration
        )
        XCTAssertTrue(regularPasses, "Regular event should pass all-day filter")
        XCTAssertFalse(
            regularReasons.contains { $0.lowercased().contains("all-day") },
            "Regular event should not have all-day related reasons"
        )

        // All-day event should not pass
        let (allDayPasses, allDayReasons) = EventFilter.checkFilters(
            allDayEvent, configuration: configuration
        )
        XCTAssertFalse(allDayPasses, "All-day event should not pass when excluded")
        XCTAssertTrue(
            allDayReasons.contains { $0.lowercased().contains("all-day") },
            "All-day event should have all-day related reason"
        )
    }

    func testAllDayEventFilteringDisabled() {
        let configuration = createTestConfiguration(excludeAllDay: false)

        let allDayEvent = createSimpleEvent(title: "All day event", isAllDay: true)

        let (passes, reasons) = EventFilter.checkFilters(allDayEvent, configuration: configuration)

        XCTAssertTrue(passes, "All-day event should pass when all-day filtering is disabled")
        XCTAssertFalse(
            reasons.contains { $0.lowercased().contains("all-day") },
            "Should not have all-day related reasons when filtering disabled"
        )
    }

    // MARK: - Combined Filter Tests

    func testCombinedFilters() {
        let configuration = createTestConfiguration(
            excludeKeywords: ["standup"],
            excludeAllDay: true
        )

        let testCases = [
            // Should pass (no filters triggered)
            ("Regular meeting", false, true, []),

            // Should fail - all-day only
            ("Regular meeting", true, false, ["all-day"]),

            // Should fail - keyword only
            ("Daily standup", false, false, ["keyword"]),

            // Should fail - both filters
            ("All day standup", true, false, ["all-day", "keyword"]),
        ]

        for (title, isAllDay, shouldPass, expectedReasonTypes) in testCases {
            let event = createSimpleEvent(title: title, isAllDay: isAllDay)

            let (passes, reasons) = EventFilter.checkFilters(event, configuration: configuration)

            XCTAssertEqual(
                passes, shouldPass,
                "Event '\(title)' (all-day: \(isAllDay)) failed combined filter test"
            )

            // Check that expected reason types are present
            for expectedType in expectedReasonTypes {
                XCTAssertTrue(
                    reasons.contains { $0.lowercased().contains(expectedType) },
                    "Expected reason containing '\(expectedType)' for '\(title)', got: \(reasons)"
                )
            }

            // If no expected reasons, should have no reasons
            if expectedReasonTypes.isEmpty {
                XCTAssertTrue(
                    reasons.isEmpty, "Expected no reasons for '\(title)', got: \(reasons)"
                )
            }
        }
    }

    func testFilterReasoningOutput() {
        let configuration = createTestConfiguration(
            excludeKeywords: ["meeting", "standup"],
            excludeAllDay: true
        )

        // Event that triggers both filters
        let event = createSimpleEvent(title: "All day standup meeting", isAllDay: true)

        let (passes, reasons) = EventFilter.checkFilters(event, configuration: configuration)

        XCTAssertFalse(passes, "Event should not pass filters")
        XCTAssertFalse(reasons.isEmpty, "Should have reasons for rejection")

        // Should have reason for all-day
        XCTAssertTrue(
            reasons.contains { $0.contains("All-day event excluded") },
            "Should have all-day exclusion reason"
        )

        // Should have reasons for keywords
        let keywordReasons = reasons.filter { $0.contains("Contains excluded keyword") }
        XCTAssertFalse(keywordReasons.isEmpty, "Should have keyword-related reasons")

        // Should mention specific keywords
        XCTAssertTrue(
            keywordReasons.contains { $0.contains("'meeting'") }
                || keywordReasons.contains { $0.contains("'standup'") },
            "Should mention specific excluded keywords"
        )
    }

    func testCheckFiltersReturnsTupleFormat() {
        let configuration = createTestConfiguration()
        let event = createSimpleEvent(title: "Test")

        let result = EventFilter.checkFilters(event, configuration: configuration)

        // Verify tuple structure
        XCTAssertTrue(result.passes, "Should pass basic filters")
        XCTAssertTrue(result.reasons.isEmpty, "Should have no reasons when passing")

        // Test with failing case
        let failingEvent = createSimpleEvent(title: "Failing event", isAllDay: true)
        let failingResult = EventFilter.checkFilters(failingEvent, configuration: configuration)

        XCTAssertFalse(failingResult.passes, "Should fail all-day filter")
        XCTAssertFalse(failingResult.reasons.isEmpty, "Should have reasons when failing")
    }

    // MARK: - applyFilters Tests

    func testApplyFiltersReturnsFilteredEvents() {
        let configuration = createTestConfiguration(
            excludeKeywords: ["standup"],
            excludeAllDay: true
        )

        let events = [
            createSimpleEvent(title: "Good meeting"),
            createSimpleEvent(title: "Daily standup"),
            createSimpleEvent(title: "All day event", isAllDay: true),
            createSimpleEvent(title: "Another good meeting"),
            createSimpleEvent(title: "Team standup", isAllDay: true),
        ]

        let filteredEvents = EventFilter.applyFilters(events, configuration: configuration)

        XCTAssertEqual(filteredEvents.count, 2, "Should filter out 3 events")

        let titles = filteredEvents.compactMap(\.title)
        XCTAssertTrue(titles.contains("Good meeting"), "Should include good meeting")
        XCTAssertTrue(
            titles.contains("Another good meeting"), "Should include another good meeting"
        )
        XCTAssertFalse(titles.contains("Daily standup"), "Should exclude standup meeting")
        XCTAssertFalse(titles.contains("All day event"), "Should exclude all-day event")
        XCTAssertFalse(titles.contains("Team standup"), "Should exclude all-day standup")
    }

    func testApplyFiltersWithEmptyEvents() {
        let configuration = createTestConfiguration()
        let emptyEvents: [EKEvent] = []

        let filteredEvents = EventFilter.applyFilters(emptyEvents, configuration: configuration)

        XCTAssertTrue(filteredEvents.isEmpty, "Empty input should return empty output")
    }

    func testApplyFiltersPreservesEventOrder() {
        let configuration = createTestConfiguration()

        let events = [
            createSimpleEvent(title: "First meeting"),
            createSimpleEvent(title: "Second meeting"),
            createSimpleEvent(title: "Third meeting"),
        ]

        let filteredEvents = EventFilter.applyFilters(events, configuration: configuration)

        XCTAssertEqual(filteredEvents.count, 3, "All events should pass")
        XCTAssertEqual(filteredEvents[0].title, "First meeting", "Order should be preserved (1)")
        XCTAssertEqual(filteredEvents[1].title, "Second meeting", "Order should be preserved (2)")
        XCTAssertEqual(filteredEvents[2].title, "Third meeting", "Order should be preserved (3)")
    }

    // MARK: - Edge Cases and Error Handling

    func testFilteringWithUnicodeCharacters() {
        let configuration = createTestConfiguration(excludeKeywords: ["café", "naïve"])

        let testCases = [
            ("Meeting with müşteri", true),
            ("Café standup", false),
            ("Naïve approach discussion", false),
            ("Regular meeting", true),
        ]

        for (title, shouldPass) in testCases {
            let event = createSimpleEvent(title: title)
            let (passes, _) = EventFilter.checkFilters(event, configuration: configuration)

            XCTAssertEqual(passes, shouldPass, "Unicode keyword filtering failed for '\(title)'")
        }
    }

    func testFilteringWithSpecialCharacters() {
        let configuration = createTestConfiguration(excludeKeywords: ["stand-up", "1:1", "Q&A"])

        let testCases = [
            ("Daily stand-up", false),
            ("1:1 meeting", false),
            ("Q&A session", false),
            ("Team meeting", true),
        ]

        for (title, shouldPass) in testCases {
            let event = createSimpleEvent(title: title)
            let (passes, _) = EventFilter.checkFilters(event, configuration: configuration)

            XCTAssertEqual(passes, shouldPass, "Special character filtering failed for '\(title)'")
        }
    }

    func testFilteringReasonsAreDescriptive() {
        let configuration = createTestConfiguration(
            excludeKeywords: ["standup", "scrum"],
            excludeAllDay: true
        )

        // Test keyword reasons
        let keywordEvent = createSimpleEvent(title: "Daily standup")
        let (_, keywordReasons) = EventFilter.checkFilters(
            keywordEvent, configuration: configuration
        )

        XCTAssertTrue(
            keywordReasons.contains("Contains excluded keyword 'standup'"),
            "Keyword reason should be specific and descriptive"
        )

        // Test all-day reason
        let allDayEvent = createSimpleEvent(title: "All day meeting", isAllDay: true)
        let (_, allDayReasons) = EventFilter.checkFilters(allDayEvent, configuration: configuration)

        XCTAssertTrue(
            allDayReasons.contains("All-day event excluded"),
            "All-day reason should be clear"
        )
    }

    // MARK: - Integration-style Tests

    func testRealisticFilteringScenarios() {
        let configuration = createTestConfiguration(
            excludeKeywords: [
                "standup", "scrum", "retrospective", "planning",
                "all-hands", "townhall", "training", "workshop",
            ],
            excludeAllDay: true
        )

        let realWorldEvents = [
            // Should pass
            createSimpleEvent(title: "1:1 with Sarah"),
            createSimpleEvent(title: "Project sync"),
            createSimpleEvent(title: "Code review"),

            // Should be filtered - keywords
            createSimpleEvent(title: "Daily standup"),
            createSimpleEvent(title: "Sprint planning"),
            createSimpleEvent(title: "Retrospective meeting"),
            createSimpleEvent(title: "All-hands meeting"),

            // Should be filtered - all-day
            createSimpleEvent(title: "Company outing", isAllDay: true),
            createSimpleEvent(title: "Holiday", isAllDay: true),

            // Should be filtered - both
            createSimpleEvent(title: "All day training", isAllDay: true),
        ]

        let filtered = EventFilter.applyFilters(realWorldEvents, configuration: configuration)

        XCTAssertEqual(filtered.count, 3, "Should only pass the 3 legitimate meetings")

        let passedTitles = filtered.compactMap(\.title)
        XCTAssertTrue(passedTitles.contains("1:1 with Sarah"))
        XCTAssertTrue(passedTitles.contains("Project sync"))
        XCTAssertTrue(passedTitles.contains("Code review"))
    }

    // MARK: - Helper Methods

    private func createSimpleEvent(title: String, isAllDay: Bool = false) -> EKEvent {
        let event = EKEvent(eventStore: eventStore)
        event.title = title
        event.isAllDay = isAllDay
        event.startDate = Date()
        event.endDate = Date().addingTimeInterval(3600)
        return event
    }

}
