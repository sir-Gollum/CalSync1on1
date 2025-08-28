import EventKit
import Foundation

class DebugHelper {
    private let logger: Logger
    private let analyzer: MeetingAnalyzer

    init(logger: Logger, analyzer: MeetingAnalyzer) {
        self.logger = logger
        self.analyzer = analyzer
    }

    func printCalendarAccessDetails() {
        if !logger.isVerbose { return }

        let authStatus = EKEventStore.authorizationStatus(for: .event)
        logger.debug("\n🔐 Calendar Access Details:")
        logger.debug("   Authorization status: \(authStatus.rawValue)")
        if #available(macOS 14.0, *) {
            logger.debug("   Has full access: \(authStatus == .fullAccess)")
        } else {
            logger.debug("   Has access: \(authStatus == .authorized)")
        }
    }

    func printAvailableCalendars(_ calendars: [EKCalendar]) {
        if !logger.isVerbose { return }

        logger.debug("\n📋 All available calendars:")
        for calendar in calendars {
            let accountInfo = calendar.source.title
            let calendarType = DebugHelper.calendarTypeDescription(calendar.type)
            let allowsModification = calendar.allowsContentModifications ? "writable" : "read-only"
            logger.debug(
                "   • \(calendar.title) (\(accountInfo)) - \(calendarType), \(allowsModification)")
        }
    }

    func printCalendarInfo(_ calendar: EKCalendar, calendarManager: CalendarManager) {
        if !logger.isVerbose { return }

        logger.debug("\n🔍 Calendar validation:")
        logger.debug("   Calendar: '\(calendar.title)' (\(calendar.source.title))")
        logger.debug("   Type: \(DebugHelper.calendarTypeDescription(calendar.type))")
        logger.debug("   Writable: \(calendar.allowsContentModifications)")

        let accessTest = calendarManager.testEventAccess(
            calendar: calendar, startDate: Date(), endDate: Date()
        )
        logger.debug("   Access test: \(accessTest.success ? "✅" : "❌")")
        if let error = accessTest.error {
            logger.debug("   Error: \(error)")
        }
    }

    func printComprehensiveEventAnalysis(
        _ events: [EKEvent], calendarOwner: String, configuration: Configuration
    ) {
        if !logger.isVerbose || events.isEmpty { return }

        logger.debug("\n📅 DETAILED EVENT ANALYSIS (\(events.count) events):")

        for (index, event) in events.enumerated() {
            logger.debug("\n   ===== EVENT \(index + 1): \(event.title ?? "Untitled") =====")
            logger.debug(
                "   📅 \(DateHelper.formatDate(event.startDate)) - \(DateHelper.formatDate(event.endDate))"
            )
            logger.debug("   All-day: \(event.isAllDay)")

            // Attendee analysis
            let attendeeCount = event.attendees?.count ?? 0
            logger.debug("   👥 Attendees: \(attendeeCount)")
            if let attendees = event.attendees {
                let maxAttendeesToShow = 5
                let attendeesToShow = min(maxAttendeesToShow, attendees.count)

                for i in 0 ..< attendeesToShow {
                    let attendee = attendees[i]
                    let email = attendee.url.absoluteString.replacingOccurrences(
                        of: "mailto:", with: ""
                    )
                    logger.debug(
                        "     [\(i + 1)] \(analyzer.getAttendeeDisplayName(attendee)) <\(email)>")
                }

                if attendees.count > maxAttendeesToShow {
                    let remainingCount = attendees.count - maxAttendeesToShow
                    logger.debug("     ... and \(remainingCount) more")
                }
            }

            // Filter check
            let (passesFilters, reasons) = EventFilter.checkFilters(
                event, configuration: configuration
            )
            logger.debug("   ✅ Passes filters: \(passesFilters)")
            if !passesFilters {
                logger.debug("      Reasons: \(reasons.joined(separator: ", "))")
            }

            // 1:1 analysis
            if attendeeCount == 2, !event.isAllDay {
                let ownerEmails = generateOwnerEmails(from: calendarOwner)
                logger.debug("   🎯 1:1 Check - Owner patterns: \(ownerEmails)")
                if let attendees = event.attendees {
                    for attendee in attendees {
                        let email = attendee.url.absoluteString.replacingOccurrences(
                            of: "mailto:", with: ""
                        )
                        let matches = matchesOwner(email, ownerEmails: ownerEmails)
                        logger.debug("      '\(email)' matches owner: \(matches)")
                    }
                }
            } else {
                logger.debug(
                    "   🎯 1:1 Check: Skipped (\(attendeeCount) attendees, all-day: \(event.isAllDay))"
                )
            }
        }

        // Statistics
        let stats = calculateEventStats(events)
        logger.debug("\n📊 STATISTICS:")
        logger.debug("   All-day: \(stats.allDay) (\(stats.allDayPercent)%)")
        logger.debug("   With attendees: \(stats.withAttendees) (\(stats.withAttendeesPercent)%)")
        logger.debug(
            "   Exactly 2 attendees: \(stats.twoAttendees) (\(stats.twoAttendeesPercent)%)")
        logger.debug("   Recurring: \(stats.recurring) (\(stats.recurringPercent)%)")
    }

    func diagnoseEmptyEventList(
        _ calendar: EKCalendar, startDate: Date, endDate: Date, configuration: Configuration,
        calendarManager: CalendarManager
    ) {
        logger.info("\n⚠️  NO EVENTS FOUND")
        logger.info("   Possible issues: No events in date range, permissions, wrong calendar")

        if !logger.isVerbose { return }

        // Test current calendar
        let accessTest = calendarManager.testEventAccess(
            calendar: calendar, startDate: startDate, endDate: endDate
        )
        logger.debug("\n🔍 DIAGNOSTICS:")
        logger.debug("   Source calendar access: \(accessTest.success ? "✅" : "❌")")

        // Test other calendars
        let allCalendars = calendarManager.listAvailableCalendars()
        var totalEvents = 0
        logger.debug("   Events in other calendars:")
        for testCalendar in allCalendars {
            let events = calendarManager.getEvents(
                from: testCalendar, startDate: startDate, endDate: endDate
            )
            totalEvents += events.count
            if events.count > 0 {
                logger.debug("     \(testCalendar.title): \(events.count)")
            }
        }

        if totalEvents == 0 {
            logger.debug("   No events found in ANY calendar for this date range")
        }

        // Test wider range
        let widerStart = Calendar.current.date(byAdding: .month, value: -3, to: Date()) ?? Date()
        let widerEnd = Calendar.current.date(byAdding: .month, value: 3, to: Date()) ?? Date()
        let widerEvents = calendarManager.getEvents(
            from: calendar, startDate: widerStart, endDate: widerEnd
        )
        logger.debug("   Events in 6-month range: \(widerEvents.count)")

        logger.debug("\n💡 SUGGESTIONS:")
        logger.debug("   • Verify calendar: '\(calendar.title)'")
        logger.debug("   • Expand sync window from \(configuration.syncWindow.weeks) weeks")
        logger.debug("   • Check Calendar app for events in date range")
    }

    func diagnoseNo1on1Meetings(
        _: Int, _ filteredEvents: Int, _ oneOnOneCount: Int, calendarOwner: String
    ) {
        if oneOnOneCount > 0 { return }

        logger.debug("\n💡 No 1:1 meetings found")
        if filteredEvents == 0 {
            logger.debug("   All events were filtered out")
        } else {
            logger.debug("   \(filteredEvents) events passed filters but none detected as 1:1")
            if !calendarOwner.contains("@") {
                logger.debug(
                    "   Owner '\(calendarOwner)' doesn't look like email - this may cause issues")
                logger.debug("   Consider setting 'owner_email' in configuration")
            }
        }
    }

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
                "\(calendarOwner.lowercased().replacingOccurrences(of: " ", with: "."))@gmail.com")
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
