import EventKit
import Foundation
import XCTest

@testable import CalSync1on1

// MARK: - Configuration Extensions

extension Configuration {

    /// Creates a configuration with modified settings, using defaults for unspecified parameters
    static func with(
        weeks: Int? = nil,
        startOffset: Int? = nil,
        excludeKeywords: [String]? = nil,
        excludeAllDay: Bool? = nil,
        titleTemplate: String? = nil,
        ownerEmail: String? = nil
    )
        -> Configuration {
        let syncWindow = Configuration.SyncWindow(
            weeks: weeks ?? Configuration.default.syncWindow.weeks,
            startOffset: startOffset ?? Configuration.default.syncWindow.startOffset
        )

        let filters = Configuration.Filters(
            excludeAllDay: excludeAllDay ?? Configuration.default.filters.excludeAllDay,
            excludeKeywords: excludeKeywords ?? Configuration.default.filters.excludeKeywords
        )

        let calendarPair = Configuration.CalendarPair(
            name: Configuration.default.calendarPair.name,
            source: Configuration.default.calendarPair.source,
            destination: Configuration.default.calendarPair.destination,
            titleTemplate: titleTemplate ?? Configuration.default.calendarPair.titleTemplate,
            ownerEmail: ownerEmail ?? Configuration.default.calendarPair.ownerEmail
        )

        return Configuration(
            version: Configuration.default.version,
            calendarPair: calendarPair,
            syncWindow: syncWindow,
            filters: filters,
            logging: Configuration.default.logging
        )
    }
}

// MARK: - XCTest Extensions

extension XCTestCase {

    /// Creates a simple test event
    func createTestEvent(
        title: String,
        startDate: Date = Date(),
        duration: TimeInterval = 3600,
        isAllDay: Bool = false,
        eventStore: EKEventStore? = nil
    )
        -> EKEvent {
        let store = eventStore ?? EKEventStore()
        let event = EKEvent(eventStore: store)

        event.title = title
        event.startDate = startDate
        event.endDate = startDate.addingTimeInterval(duration)
        event.isAllDay = isAllDay

        return event
    }
}
