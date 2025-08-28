import EventKit
import Foundation

class MeetingAnalyzer {
    func isOneOnOneMeeting(_ event: EKEvent, calendarOwner: String) -> Bool {
        isOneOnOneMeeting(event, calendarOwner: calendarOwner, debug: false)
    }

    func isOneOnOneMeeting(_ event: EKEvent, calendarOwner: String, debug: Bool) -> Bool {
        // Skip all-day events
        if event.isAllDay {
            if debug { print("         DEBUG: Skipping all-day event") }
            return false
        }

        // Check if event has exactly 2 attendees (including organizer)
        let attendees = event.attendees ?? []
        if debug { print("         DEBUG: Event has \(attendees.count) attendees") }
        guard attendees.count == 2 else {
            if debug { print("         DEBUG: Not exactly 2 attendees, skipping") }
            return false
        }

        // Check if calendar owner is one of the attendees
        let ownerEmails = getOwnerEmails(calendarOwner: calendarOwner)
        let attendeeEmails = attendees.compactMap { attendee in
            extractEmailFromParticipant(attendee)
        }

        if debug {
            print("         DEBUG: Owner emails to match: \(ownerEmails)")
            print("         DEBUG: Attendee emails: \(attendeeEmails)")
        }

        // More flexible matching - check if owner is one of the attendees
        let ownerIsAttendee = attendeeEmails.contains { email in
            let matchFound = ownerEmails.contains { ownerEmail in
                // Try multiple matching strategies
                let emailLower = email.lowercased()
                let ownerEmailLower = ownerEmail.lowercased()

                // Direct match
                if emailLower == ownerEmailLower {
                    if debug { print("         DEBUG: Direct match found: '\(email)' == '\(ownerEmail)'") }
                    return true
                }

                // Owner email contains the attendee email (for account names)
                if ownerEmailLower.contains(emailLower) || emailLower.contains(ownerEmailLower) {
                    if debug { print("         DEBUG: Contains match found: '\(email)' <-> '\(ownerEmail)'") }
                    return true
                }

                // Extract domain-less parts and compare
                let emailLocal = emailLower.components(separatedBy: "@").first ?? emailLower
                let ownerLocal = ownerEmailLower.components(separatedBy: "@").first ?? ownerEmailLower

                if emailLocal == ownerLocal {
                    if debug { print("         DEBUG: Local part match found: '\(emailLocal)' == '\(ownerLocal)'") }
                    return true
                }

                return false
            }
            if debug, !matchFound {
                print("         DEBUG: No match found for attendee email: '\(email)'")
            }
            return matchFound
        }

        if debug {
            print("         DEBUG: Owner is attendee: \(ownerIsAttendee)")
        }

        return ownerIsAttendee
    }

    func getOtherPersonName(from event: EKEvent, calendarOwner: String) -> String {
        let attendees = event.attendees ?? []
        let ownerEmails = getOwnerEmails(calendarOwner: calendarOwner)

        for attendee in attendees {
            if let email = extractEmailFromParticipant(attendee) {
                let isOwner = ownerEmails.contains { ownerEmail in
                    // Use same flexible matching logic as isOneOnOneMeeting
                    let emailLower = email.lowercased()
                    let ownerEmailLower = ownerEmail.lowercased()

                    return emailLower == ownerEmailLower ||
                        ownerEmailLower.contains(emailLower) ||
                        emailLower.contains(ownerEmailLower) ||
                        emailLower.components(separatedBy: "@").first ==
                        ownerEmailLower.components(separatedBy: "@").first
                }

                if !isOwner {
                    return extractNameFromEmail(email)
                }
            }
        }

        return "Unknown"
    }

    // MARK: - Recurring Event Support

    struct RecurrenceAnalysis {
        let isRecurring: Bool
        let isOneOnOneRecurringSeries: Bool
        let recurrenceRule: String?
        let shouldSyncSeries: Bool
        let exceptions: [String] // Event IDs of exceptions
    }

    func analyzeRecurringSeries(_ event: EKEvent, calendarOwner: String) -> RecurrenceAnalysis {
        let baseAnalysis = isOneOnOneMeeting(event, calendarOwner: calendarOwner)

        let hasRecurrenceRules = event.hasRecurrenceRules
        let recurrenceRule = event.recurrenceRules?.first

        return RecurrenceAnalysis(
            isRecurring: hasRecurrenceRules,
            isOneOnOneRecurringSeries: baseAnalysis && hasRecurrenceRules,
            recurrenceRule: recurrenceRule?.description,
            shouldSyncSeries: baseAnalysis, // Sync recurring 1:1 series
            exceptions: [] // FIXME: Implement exception tracking in future version
        )
    }

    // MARK: - Private Helper Methods

    private func extractEmailFromParticipant(_ participant: EKParticipant) -> String? {
        let urlString = participant.url.absoluteString
        if urlString.hasPrefix("mailto:") {
            return String(urlString.dropFirst(7)) // Remove "mailto:" prefix
        }
        return urlString
    }

    func getOwnerEmails(calendarOwner: String) -> [String] {
        var ownerEmails = [calendarOwner]

        // If the calendar owner looks like an email, also add just the local part
        if calendarOwner.contains("@") {
            let localPart = calendarOwner.components(separatedBy: "@").first ?? calendarOwner
            ownerEmails.append(localPart)
        }

        // If the calendar owner doesn't look like an email, try common variations
        if !calendarOwner.contains("@") {
            // Add some common email patterns
            ownerEmails.append("\(calendarOwner.lowercased())@gmail.com")
            ownerEmails.append("\(calendarOwner.lowercased().replacingOccurrences(of: " ", with: "."))@gmail.com")
        }

        return ownerEmails
    }

    func extractNameFromEmail(_ email: String) -> String {
        let parts = email.components(separatedBy: "@")
        guard let localPart = parts.first else {
            return email
        }

        // Replace dots and underscores with spaces and capitalize
        return localPart
            .replacingOccurrences(of: ".", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }

    func getAttendeeDisplayName(_ attendee: EKParticipant) -> String {
        if let name = attendee.name, !name.isEmpty {
            return name
        }

        if let email = extractEmailFromParticipant(attendee) {
            return extractNameFromEmail(email)
        }

        return "Unknown"
    }

    // Debug helper methods
    func debugEventDetails(_ event: EKEvent, calendarOwner: String) -> String {
        var details = "Event Debug Details:\n"
        details += "  Title: \(event.title ?? "Untitled")\n"
        details += "  Start: \(String(describing: event.startDate))\n"
        details += "  All-day: \(event.isAllDay)\n"
        details += "  Attendee count: \(event.attendees?.count ?? 0)\n"

        if let attendees = event.attendees {
            details += "  Attendees:\n"
            for (i, attendee) in attendees.enumerated() {
                let email = extractEmailFromParticipant(attendee)
                details += "    [\(i + 1)] \(getAttendeeDisplayName(attendee)) <\(email ?? "No email")>\n"
                details += "        Type: \(attendee.participantType.rawValue)\n"
                details += "        Role: \(attendee.participantRole.rawValue)\n"
                details += "        Status: \(attendee.participantStatus.rawValue)\n"
            }
        }

        details += "  Calendar owner: '\(calendarOwner)'\n"
        details += "  Owner emails: \(getOwnerEmails(calendarOwner: calendarOwner))\n"

        let is1on1 = isOneOnOneMeeting(event, calendarOwner: calendarOwner, debug: true)
        details += "  Is 1:1 meeting: \(is1on1)\n"

        return details
    }

    func getParticipantTypeLabel(participantType: Int) -> String {
        switch participantType {
        case 1:
            "Person"
        case 2:
            "Room"
        default:
            "Group"
        }
    }

    func getParticipantRoleLabel(participantRole: Int) -> String {
        switch participantRole {
        case 1:
            "Chair"
        case 2:
            "Required"
        default:
            "Optional"
        }
    }

    func getParticipantStatusLabel(participantStatus: Int) -> String {
        switch participantStatus {
        case 1:
            "Unknown"
        case 2:
            "Pending"
        case 3:
            "Accepted"
        case 4:
            "Declines"
        default:
            "Tentative"
        }
    }
}
