import EventKit
import Foundation

class DebugHelper {

    // MARK: - Properties

    private let analyzer: MeetingAnalyzer

    // MARK: - Lifecycle

    init(analyzer: MeetingAnalyzer) {
        self.analyzer = analyzer
    }

    // MARK: - Static Functions

    static func calendarTypeDescription(_ type: EKCalendarType) -> String {
        switch type {
        case .local:
            return "Local"
        case .calDAV:
            return "CalDAV"
        case .exchange:
            return "Exchange"
        case .subscription:
            return "Subscription"
        case .birthday:
            return "Birthday"
        @unknown default:
            return "Unknown"
        }
    }

    // MARK: - Functions

    func printCalendarAccessDetails() {
        if !Logger.isVerbose { return }

        let authStatus = EKEventStore.authorizationStatus(for: .event)
        Logger.debug("\n\t🔐 Calendar Access Details:")
        Logger.debug("   Authorization status: \(authStatus.rawValue)")
        if #available(macOS 14.0, *) {
            Logger.debug("   Has full access: \(authStatus == .fullAccess)")
        } else {
            Logger.debug("   Has access: \(authStatus == .authorized)")
        }
    }

    func printAvailableCalendars(_ calendars: [EKCalendar]) {
        if !Logger.isVerbose { return }

        Logger.debug("\n\t📋 All available calendars:")
        for calendar in calendars {
            let accountInfo = calendar.source.title
            let calendarType = DebugHelper.calendarTypeDescription(calendar.type)
            let allowsModification = calendar.allowsContentModifications ? "writable" : "read-only"
            Logger.debug(
                "   • \(calendar.title) (\(accountInfo)) - \(calendarType), \(allowsModification)"
            )
        }
    }

    func printCalendarInfo(_ calendar: EKCalendar, calendarManager: CalendarManager) {
        if !Logger.isVerbose { return }

        Logger.debug("\n\t🔍 Calendar validation:")
        Logger.debug("   Calendar: '\(calendar.title)' (\(calendar.source.title))")
        Logger.debug("   Type: \(DebugHelper.calendarTypeDescription(calendar.type))")
        Logger.debug("   Writable: \(calendar.allowsContentModifications)")

        let accessTest = calendarManager.testEventAccess(
            calendar: calendar, startDate: Date(), endDate: Date()
        )
        Logger.debug("   Access test: \(accessTest.success ? "✅" : "❌")")
        if let error = accessTest.error {
            Logger.debug("   Error: \(error)")
        }
    }

    func printComprehensiveEventAnalysis(
        _ events: [EKEvent], calendarOwner: String, configuration: Configuration
    ) {
        if !Logger.isVerbose || events.isEmpty { return }

        Logger.debug("\n\t📅 DETAILED EVENT ANALYSIS (\(events.count) events):")

        for (index, event) in events.enumerated() {
            Logger.debug(
                "\n\t   ===== EVENT \(index + 1): \(event.title ?? "Untitled") ====="
            )
            Logger.debug(
                "   📅 \(DateHelper.formatDate(event.startDate)) - \(DateHelper.formatDate(event.endDate))"
            )
            Logger.debug("   All-day: \(event.isAllDay)")

            // Attendee analysis
            let attendeeCount = event.attendees?.count ?? 0
            Logger.debug("   👥 Attendees: \(attendeeCount)")
            if let attendees = event.attendees {
                let maxAttendeesToShow = 5
                let attendeesToShow = min(maxAttendeesToShow, attendees.count)

                for i in 0 ..< attendeesToShow {
                    let attendee = attendees[i]
                    let email = attendee.url.absoluteString.replacingOccurrences(
                        of: "mailto:", with: ""
                    )
                    Logger.debug(
                        "     [\(i + 1)] \(analyzer.getAttendeeDisplayName(attendee)) <\(email)>"
                    )
                }

                if attendees.count > maxAttendeesToShow {
                    let remainingCount = attendees.count - maxAttendeesToShow
                    Logger.debug("     ... and \(remainingCount) more")
                }
            }

            // Filter check
            let (passesFilters, reasons) = EventFilter.checkFilters(
                event, configuration: configuration
            )
            Logger.debug("   ✅ Passes filters: \(passesFilters)")
            if !passesFilters {
                Logger.debug("      Reasons: \(reasons.joined(separator: ", "))")
            }

            // 1:1 analysis
            if attendeeCount == 2, !event.isAllDay {
                let ownerEmails = generateOwnerEmails(from: calendarOwner)
                Logger.debug("   🎯 1:1 Check - Owner patterns: \(ownerEmails)")
                if let attendees = event.attendees {
                    for attendee in attendees {
                        let email = attendee.url.absoluteString.replacingOccurrences(
                            of: "mailto:", with: ""
                        )
                        let matches = matchesOwner(email, ownerEmails: ownerEmails)
                        Logger.debug("      '\(email)' matches owner: \(matches)")
                    }
                }
            } else {
                Logger.debug(
                    "   🎯 1:1 Check: Skipped (\(attendeeCount) attendees, all-day: \(event.isAllDay))"
                )
            }
        }

        // Statistics
        let stats = calculateEventStats(events)
        Logger.debug("\n\t📊 STATISTICS:")
        Logger.debug("   All-day: \(stats.allDay) (\(stats.allDayPercent)%)")
        Logger.debug("   With attendees: \(stats.withAttendees) (\(stats.withAttendeesPercent)%)")
        Logger.debug(
            "   Exactly 2 attendees: \(stats.twoAttendees) (\(stats.twoAttendeesPercent)%)"
        )
        Logger.debug("   Recurring: \(stats.recurring) (\(stats.recurringPercent)%)")
    }

    func diagnoseEmptyEventList(
        _ calendar: EKCalendar, startDate: Date, endDate: Date, configuration: Configuration,
        calendarManager: CalendarManager
    ) {
        Logger.info("\n\t⚠️  NO EVENTS FOUND")
        Logger.info("   Possible issues: No events in date range, permissions, wrong calendar")

        if !Logger.isVerbose { return }

        // Test current calendar
        let accessTest = calendarManager.testEventAccess(
            calendar: calendar, startDate: startDate, endDate: endDate
        )
        Logger.debug("\n\t🔍 DIAGNOSTICS:")
        Logger.debug("   Source calendar access: \(accessTest.success ? "✅" : "❌")")

        // Test other calendars
        let allCalendars = calendarManager.listAvailableCalendars()
        var totalEvents = 0
        Logger.debug("   Events in other calendars:")
        for testCalendar in allCalendars {
            let events = calendarManager.getEvents(
                from: testCalendar, startDate: startDate, endDate: endDate
            )
            totalEvents += events.count
            if events.count > 0 {
                Logger.debug("     \(testCalendar.title): \(events.count)")
            }
        }

        if totalEvents == 0 {
            Logger.debug("   No events found in ANY calendar for this date range")
        }

        // Test wider range
        let widerStart = Calendar.current.date(byAdding: .month, value: -3, to: Date()) ?? Date()
        let widerEnd = Calendar.current.date(byAdding: .month, value: 3, to: Date()) ?? Date()
        let widerEvents = calendarManager.getEvents(
            from: calendar, startDate: widerStart, endDate: widerEnd
        )
        Logger.debug("   Events in 6-month range: \(widerEvents.count)")

        Logger.debug("\n\t💡 SUGGESTIONS:")
        Logger.debug("   • Verify calendar: '\(calendar.title)'")
        Logger.debug("   • Expand sync window from \(configuration.syncWindow.weeks) weeks")
        Logger.debug("   • Check Calendar app for events in date range")
    }

    func diagnoseNo1on1Meetings(
        _: Int, _ filteredEvents: Int, _ oneOnOneCount: Int, calendarOwner: String
    ) {
        if oneOnOneCount > 0 { return }

        Logger.debug("\n\t💡 No 1:1 meetings found")
        if filteredEvents == 0 {
            Logger.debug("   All events were filtered out")
        } else {
            Logger.debug("   \(filteredEvents) events passed filters but none detected as 1:1")
            if !calendarOwner.contains("@") {
                Logger.debug(
                    "   Owner '\(calendarOwner)' doesn't look like email - this may cause issues"
                )
                Logger.debug("   Consider setting 'owner_email' in configuration")
            }
        }
    }

    // MARK: - Private Helpers

    private func calculateEventStats(_ events: [EKEvent]) -> EventStats {
        let total = events.count
        let allDay = events.count { $0.isAllDay }
        let withAttendees = events.count { ($0.attendees?.count ?? 0) > 0 }
        let twoAttendees = events.count { ($0.attendees?.count ?? 0) == 2 }
        let recurring = events.count { $0.hasRecurrenceRules }

        return EventStats(
            allDay: allDay, allDayPercent: percentage(allDay, of: total),
            withAttendees: withAttendees,
            withAttendeesPercent: percentage(withAttendees, of: total),
            twoAttendees: twoAttendees, twoAttendeesPercent: percentage(twoAttendees, of: total),
            recurring: recurring, recurringPercent: percentage(recurring, of: total)
        )
    }

    private func percentage(_ count: Int, of total: Int) -> String {
        guard total > 0 else { return "0" }
        return String(format: "%.0f", Double(count) * 100.0 / Double(total))
    }

    // MARK: - Private Owner Email Matching (same logic as MeetingAnalyzer but private)

    private func generateOwnerEmails(from calendarOwner: String) -> [String] {
        var ownerEmails = [calendarOwner]

        // If the calendar owner looks like an email, also add just the local part
        if calendarOwner.contains("@") {
            let localPart = calendarOwner.components(separatedBy: "@").first ?? calendarOwner
            ownerEmails.append(localPart)
        }

        // If the calendar owner doesn't look like an email, try common variations
        if !calendarOwner.contains("@") {
            ownerEmails.append("\(calendarOwner.lowercased())@gmail.com")
            ownerEmails.append(
                "\(calendarOwner.lowercased().replacingOccurrences(of: " ", with: "."))@gmail.com"
            )
        }

        return ownerEmails
    }

    private func matchesOwner(_ email: String, ownerEmails: [String]) -> Bool {
        ownerEmails.contains { ownerEmail in
            let emailLower = email.lowercased()
            let ownerEmailLower = ownerEmail.lowercased()
            return emailLower == ownerEmailLower
                || ownerEmailLower.contains(emailLower)
                || emailLower.contains(ownerEmailLower)
                || emailLower.components(separatedBy: "@").first
                == ownerEmailLower.components(separatedBy: "@").first
        }
    }
}

private struct EventStats {
    let allDay: Int, allDayPercent: String
    let withAttendees: Int, withAttendeesPercent: String
    let twoAttendees: Int, twoAttendeesPercent: String
    let recurring: Int, recurringPercent: String
}
