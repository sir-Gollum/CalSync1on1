import EventKit
import Foundation
import XCTest

@testable import CalSync1on1

// MARK: - XCTestCase Extensions

extension XCTestCase {
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
    ) -> Configuration {
        return Configuration(
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
}
