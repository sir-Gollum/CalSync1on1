import EventKit
import Foundation

struct EventAccessResult {
    let success: Bool
    let eventCount: Int
    let error: String?
}

class CalendarManager {

    // MARK: - Properties

    let eventStore = EKEventStore()

    // MARK: - Functions

    func requestAccess() -> Bool {
        let semaphore = DispatchSemaphore(value: 0)
        var accessGranted = false

        eventStore.requestAccess(to: .event) { granted, error in
            accessGranted = granted
            if let error {
                Logger.error("Calendar access error: \(error.localizedDescription)")
            }
            semaphore.signal()
        }

        semaphore.wait()
        return accessGranted
    }

    func findCalendar(named name: String) -> EKCalendar? {
        let calendars = eventStore.calendars(for: .event)
        return calendars.first { $0.title == name }
    }

    func getEvents(from calendar: EKCalendar, startDate: Date, endDate: Date) -> [EKEvent] {
        getEvents(from: calendar, startDate: startDate, endDate: endDate, debug: false)
    }

    func getEvents(from calendar: EKCalendar, startDate: Date, endDate: Date, debug: Bool)
        -> [EKEvent] {
        if debug {
            Logger.debug("     🔍 CalendarManager.getEvents debug:")
            Logger.debug("       Calendar: \(calendar.title) (\(calendar.calendarIdentifier))")
            Logger.debug("       Start: \(startDate)")
            Logger.debug("       End: \(endDate)")
            Logger.debug("       Calendar type: \(calendar.type.rawValue)")
            Logger.debug("       Calendar source: \(calendar.source.title)")
        }

        let predicate = eventStore.predicateForEvents(
            withStart: startDate,
            end: endDate,
            calendars: [calendar]
        )

        if debug {
            Logger.debug("       ✅ Predicate created successfully")
        }

        let events = eventStore.events(matching: predicate)

        if debug {
            Logger.debug("       📊 Raw events returned: \(events.count)")
            if events.count > 0 {
                Logger.debug("       Sample events:")
                for (i, event) in events.prefix(3).enumerated() {
                    Logger.debug(
                        "         [\(i + 1)] \(event.title ?? "Untitled") at \(String(describing: event.startDate))"
                    )
                }
            }
        }

        return events
    }

    func createEvent(title: String, startDate: Date, endDate: Date, in calendar: EKCalendar) -> Bool {
        let event = EKEvent(eventStore: eventStore)
        event.title = title
        event.startDate = startDate
        event.endDate = endDate
        event.calendar = calendar

        do {
            try eventStore.save(event, span: .thisEvent)
            return true
        } catch {
            Logger.error("Error creating event: \(error.localizedDescription)")
            return false
        }
    }

    func findExistingEvent(title: String, startDate: Date, in calendar: EKCalendar) -> EKEvent? {
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startDate) ?? startDate
        let predicate = eventStore.predicateForEvents(
            withStart: startDate,
            end: endOfDay,
            calendars: [calendar]
        )

        let events = eventStore.events(matching: predicate)
        return events.first { $0.title == title }
    }

    func validateCalendarAccess() -> Bool {
        let authStatus = EKEventStore.authorizationStatus(for: .event)
        if #available(macOS 14.0, *) {
            return authStatus == .authorized || authStatus == .fullAccess
        } else {
            return authStatus == .authorized
        }
    }

    func listAvailableCalendars() -> [EKCalendar] {
        eventStore.calendars(for: .event)
    }

    // Debug helper methods
    func debugCalendarAccess() -> String {
        var debug = "Calendar Debug Info:\n"
        let authStatus = EKEventStore.authorizationStatus(for: .event)
        debug += "  Authorization status: \(authStatus.rawValue)\n"

        if #available(macOS 14.0, *) {
            debug += "  Full access: \(authStatus == .fullAccess)\n"
            debug += "  Write access: \(authStatus == .writeOnly || authStatus == .fullAccess)\n"
        } else {
            debug += "  Has access: \(authStatus == .authorized)\n"
        }

        let calendars = listAvailableCalendars()
        debug += "  Available calendars: \(calendars.count)\n"

        for calendar in calendars {
            debug += "    • \(calendar.title) (\(calendar.source.title))\n"
            debug +=
                "      Type: \(calendar.type.rawValue), Writable: \(calendar.allowsContentModifications)\n"
        }

        return debug
    }

    func testEventAccess(calendar: EKCalendar, startDate: Date, endDate: Date) -> EventAccessResult {
        let predicate = eventStore.predicateForEvents(
            withStart: startDate,
            end: endDate,
            calendars: [calendar]
        )

        let events = eventStore.events(matching: predicate)
        return EventAccessResult(success: true, eventCount: events.count, error: nil)
    }
}
