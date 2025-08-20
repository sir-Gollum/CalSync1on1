import Foundation
import EventKit

// Parse command line arguments
let args = CommandLineArgs.parse()

// Handle help and version flags
if args.help {
    print("""
    CalSync1on1 - macOS Calendar Sync Tool

    USAGE:
        calsync1on1 [OPTIONS]

    OPTIONS:
        --config PATH    Path to configuration file (default: ~/.config/calsync1on1/config.yaml)
        --dry-run        Show what changes would be made without applying them
        --verbose        Enable verbose logging with comprehensive event data
        --help, -h       Show this help message
        --version        Show version information

    DESCRIPTION:
        Synchronizes 1:1 meetings from a work calendar to a personal calendar.
        Identifies meetings with exactly 2 attendees (including calendar owner)
        and creates corresponding "1:1 with [Person]" events in the destination calendar.

    CONFIGURATION:
        Configuration is loaded from ~/.config/calsync1on1/config.yaml by default.
        Run with --dry-run first to see what changes would be made.

    DEBUGGING:
        Use --verbose to see complete event data for troubleshooting:
        - All available calendars with permissions
        - Complete event details (attendees, organizer, metadata)
        - Step-by-step 1:1 detection analysis
        - Owner email matching process
        - Filter application results
        - Diagnostic recommendations

    EXAMPLES:
        calsync1on1                    # Run with default settings
        calsync1on1 --dry-run          # Preview changes without applying
        calsync1on1 --config my.yaml  # Use custom configuration file
        calsync1on1 --verbose --dry-run # Debug why 1:1 meetings aren't found
        calsync1on1 --verbose --dry-run > debug.log # Save debug data to file
    """)
    exit(0)
}

if args.version {
    print("CalSync1on1 version 1.0")
    print("macOS Calendar 1:1 Meeting Sync Tool")
    exit(0)
}

// Load configuration
let configuration = Configuration.load(from: args.configPath)

// Initialize managers
let calendarManager = CalendarManager()
let syncManager = SyncManager(configuration: configuration, dryRun: args.dryRun)
let analyzer = MeetingAnalyzer()
let dateHelper = DateHelper(configuration: configuration)

print("📅 CalSync1on1 - Syncing 1:1 meetings from work to personal calendar")
if args.dryRun {
    print("🔍 DRY RUN MODE - No changes will be made")
}
print("")

// Check calendar access permissions
print("🔐 Checking calendar permissions...")
guard calendarManager.requestAccess() else {
    print("❌ Error: Calendar access denied.")
    print("   Please grant permission in System Preferences > Privacy & Security > Calendars")
    print("   Then restart the application.")
    exit(1)
}
print("✅ Calendar access granted")

if args.verbose {
    print("\n🔐 Calendar Access Details:")
    let authStatus = EKEventStore.authorizationStatus(for: .event)
    print("   Authorization status: \(authStatus.rawValue)")
    if #available(macOS 14.0, *) {
        print("   Has full access: \(authStatus == .fullAccess)")
        print("   Has write access: \(authStatus == .fullAccess)")
    } else {
        print("   Has access: \(authStatus == .authorized)")
    }
}

// List all available calendars in verbose mode
if args.verbose {
    let availableCalendars = calendarManager.listAvailableCalendars()
    print("\n📋 All available calendars:")
    for calendar in availableCalendars {
        let accountInfo = calendar.source.title
        let calendarType = calendarTypeDescription(calendar.type)
        let allowsModification = calendar.allowsContentModifications ? "writable" : "read-only"
        print("   • \(calendar.title) (\(accountInfo)) - \(calendarType), \(allowsModification)")
    }
    print("")
}

// Get the primary (and only) calendar pair from configuration
let calendarPair = configuration.primaryCalendarPair
print("\n📋 Calendar Configuration:")
print("   Source: \(calendarPair.source.calendar)")
print("   Destination: \(calendarPair.destination.calendar)")
if args.verbose {
    if let ownerEmail = calendarPair.ownerEmail {
        print("   Configured owner email: \(ownerEmail)")
    } else {
        print("   No owner email configured (will use calendar source)")
    }
}

// Find source calendar
print("\n🔍 Finding calendars...")
guard let sourceCalendar = calendarManager.findCalendar(named: calendarPair.source.calendar) else {
    print("❌ Error: Could not find source calendar named '\(calendarPair.source.calendar)'")
    print("   Available calendars:")
    let availableCalendars = calendarManager.listAvailableCalendars()
    for calendar in availableCalendars {
        print("   • \(calendar.title) (\(calendar.source.title))")
    }
    print("   Please check your configuration file or create the required calendar.")
    exit(1)
}

// Find destination calendar
guard let destCalendar = calendarManager.findCalendar(named: calendarPair.destination.calendar) else {
    print("❌ Error: Could not find destination calendar named '\(calendarPair.destination.calendar)'")
    print("   Available calendars:")
    let availableCalendars = calendarManager.listAvailableCalendars()
    for calendar in availableCalendars {
        print("   • \(calendar.title) (\(calendar.source.title))")
    }
    print("   Please check your configuration file or create the required calendar.")
    exit(1)
}

print("✅ Found source calendar: \(sourceCalendar.title) (\(sourceCalendar.source.title))")
print("✅ Found destination calendar: \(destCalendar.title) (\(destCalendar.source.title))")

// Validate calendar accessibility
if args.verbose {
    print("\n🔍 Source calendar validation:")
    print("   Calendar title: '\(sourceCalendar.title)'")
    print("   Calendar source: '\(sourceCalendar.source.title)'")
    print("   Calendar type: \(calendarTypeDescription(sourceCalendar.type))")
    print("   Source type: \(sourceCalendar.source.sourceType.rawValue)")
    print("   Allows modifications: \(sourceCalendar.allowsContentModifications)")
    print("   Is immutable: \(sourceCalendar.isImmutable)")

    // Test calendar accessibility
    let accessTest = calendarManager.testEventAccess(calendar: sourceCalendar, startDate: Date(), endDate: Date())
    print("   Event access test: \(accessTest.success ? "✅ Success" : "❌ Failed")")
    if let error = accessTest.error {
        print("   Access error: \(error)")
    }

    if let account = sourceCalendar.source.title.components(separatedBy: " ").first {
        print("   Potential account identifier: '\(account)'")
    }
}

// Calculate date range based on configuration
let startDate = dateHelper.getCurrentWeekStart()
let endDate = dateHelper.getSyncEndDate()

print("\n📅 Sync window: \(configuration.syncWindow.weeks) weeks")
print("   From: \(formatDateLong(startDate))")
print("   To: \(formatDateLong(endDate))")

// Get events from source calendar
print("\n📥 Fetching events from source calendar...")
if args.verbose {
    print("   🔍 Event fetching details:")
    print("   Calendar: \(sourceCalendar.title)")
    print("   Calendar ID: \(sourceCalendar.calendarIdentifier)")
    print("   Date range: \(formatDateLong(startDate)) to \(formatDateLong(endDate))")
    print("   Total days in range: \(Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 0)")

    // Check if calendar allows event queries
    print("   Calendar allows content modifications: \(sourceCalendar.allowsContentModifications)")
    print("   Calendar is subscribed: \(sourceCalendar.isSubscribed)")
    print("   Calendar is immutable: \(sourceCalendar.isImmutable)")
    print("   Calendar source type: \(sourceCalendar.source.sourceType.rawValue)")

    // Test if we can create a predicate
    let testPredicate = calendarManager.eventStore.predicateForEvents(
        withStart: startDate,
        end: endDate,
        calendars: [sourceCalendar]
    )
    print("   ✅ Successfully created event predicate")
    print("   Predicate: \(testPredicate)")
}

let events = args.verbose ?
    calendarManager.getEvents(from: sourceCalendar, startDate: startDate, endDate: endDate, debug: true) :
    calendarManager.getEvents(from: sourceCalendar, startDate: startDate, endDate: endDate)


print("📊 Found \(events.count) total events in source calendar")

// Add detailed debugging if no events found
if events.isEmpty {
    print("\n⚠️  NO EVENTS FOUND - Debugging:")
    print("   This could indicate:")
    print("   • No events exist in the specified date range")
    print("   • Calendar permissions issue")
    print("   • Wrong calendar selected")
    print("   • Date range too narrow")

    if args.verbose {
        print("\n   🔍 Detailed troubleshooting:")

        // Test calendar access for the selected calendar
        let accessTest = calendarManager.testEventAccess(calendar: sourceCalendar, startDate: startDate, endDate: endDate)
        print("   📋 Source calendar access test:")
        print("     Success: \(accessTest.success)")
        print("     Event count: \(accessTest.eventCount)")
        if let error = accessTest.error {
            print("     Error: \(error)")
        }

        // Try fetching from ALL calendars to see if any have events
        print("\n   🔍 Testing event access across all calendars...")
        let allCalendars = calendarManager.listAvailableCalendars()
        var totalEventsFound = 0
        for testCalendar in allCalendars {
            let testEvents = calendarManager.getEvents(from: testCalendar, startDate: startDate, endDate: endDate)
            totalEventsFound += testEvents.count
            let status = testCalendar.title == sourceCalendar.title ? " ← SOURCE" : ""
            print("   • \(testCalendar.title): \(testEvents.count) events\(status)")
        }

        if totalEventsFound == 0 {
            print("   ⚠️  No events found in ANY calendar for this date range")
            print("   💡 This suggests a date range issue")
        } else {
            print("   ℹ️  Found \(totalEventsFound) total events across all calendars")
            if totalEventsFound > 0 && events.isEmpty {
                print("   ⚠️  Other calendars have events, but your source calendar doesn't")
                print("   💡 Check if you selected the correct source calendar")
            }
        }

        // Try a much wider date range on source calendar
        let widerStartDate = Calendar.current.date(byAdding: .month, value: -6, to: Date()) ?? Date()
        let widerEndDate = Calendar.current.date(byAdding: .month, value: 6, to: Date()) ?? Date()
        print("\n   🔍 Testing wider date range...")
        let widerEvents = calendarManager.getEvents(from: sourceCalendar, startDate: widerStartDate, endDate: widerEndDate, debug: true)
        print("   📅 Events in 12-month range (\(formatDate(widerStartDate)) to \(formatDate(widerEndDate))): \(widerEvents.count)")

        if widerEvents.count > 0 {
            print("   ✅ Events exist in source calendar but outside your sync window!")
            print("   💡 Your current sync window:")
            print("       From: \(formatDateLong(startDate))")
            print("       To: \(formatDateLong(endDate))")
            print("   💡 Consider adjusting sync_window settings:")
            print("       weeks: 8  # Increase from \(configuration.syncWindow.weeks)")
            print("       start_offset: -2  # Include past 2 weeks")

            // Show when the events actually are
            let eventDates = widerEvents.map { $0.startDate }.sorted()
            if let earliest = eventDates.first, let latest = eventDates.last {
                print("   📅 Your events span from \(formatDate(earliest)) to \(formatDate(latest))")
            }
        } else {
            print("   ❌ No events found even in 12-month range")
            print("   💡 This could mean:")
            print("       • Calendar is empty")
            print("       • Calendar permissions issue")
            print("       • Wrong calendar selected")
        }

        // Check calendar store authorization again
        let authStatus = EKEventStore.authorizationStatus(for: .event)
        print("\n   🔐 Authorization check:")
        print("     Current status: \(authStatus.rawValue)")
        if #available(macOS 14.0, *) {
            print("     Has full access: \(authStatus == .fullAccess)")
            print("     Has write access: \(authStatus == .fullAccess)")
        } else {
            print("     Has access: \(authStatus == .authorized)")
        }

        // Test different time periods
        print("\n   📅 Testing specific time periods:")
        let periods = [
            ("Today", Calendar.current.startOfDay(for: Date()), Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date())) ?? Date()),
            ("This week", dateHelper.getCurrentWeekStart(), Calendar.current.date(byAdding: .weekOfYear, value: 1, to: dateHelper.getCurrentWeekStart()) ?? Date()),
            ("Last 30 days", Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date(), Date()),
            ("Next 30 days", Date(), Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date())
        ]

        for (name, start, end) in periods {
            let periodEvents = calendarManager.getEvents(from: sourceCalendar, startDate: start, endDate: end)
            print("     \(name): \(periodEvents.count) events")
        }

        // Add specific recommendations for 0 events case
        print("\n   💡 SPECIFIC SOLUTIONS TO TRY:")
        print("   1. Verify calendar selection:")
        print("      • Check that '\(sourceCalendar.title)' is the calendar with your meetings")
        print("      • Try running with different calendar names from the available list above")

        print("\n   2. Expand date range in config:")
        print("      sync_window:")
        print("        weeks: 8          # Increase from \(configuration.syncWindow.weeks)")
        print("        start_offset: -2  # Include past 2 weeks")

        print("\n   3. Check Calendar app:")
        print("      • Open Calendar app and verify events exist in '\(sourceCalendar.title)'")
        print("      • Check if events are in the date range: \(formatDateLong(startDate)) to \(formatDateLong(endDate))")

        print("\n   4. Calendar permissions:")
        print("      • Go to System Preferences > Privacy & Security > Calendars")
        print("      • Ensure this app has full calendar access")

        print("\n   5. Try a different source calendar:")
        print("      Available calendars with event counts:")
        for testCalendar in allCalendars {
            let testEvents = calendarManager.getEvents(from: testCalendar, startDate: startDate, endDate: endDate)
            if testEvents.count > 0 {
                print("      ✅ '\(testCalendar.title)': \(testEvents.count) events")
            }
        }
    }
} else {
    // Events were found - show summary
    if args.verbose {
        print("   ✅ Successfully fetched \(events.count) events from source calendar")
    }
}

// Filter events based on configuration
let filteredEvents = events.filter { event in
    // Apply configuration filters
    if configuration.filters.excludeAllDay && event.isAllDay {
        if args.verbose {
            print("   ⏭️ Skipping all-day event: \(event.title ?? "Untitled")")
        }
        return false
    }

    // Check for excluded keywords
    if let title = event.title?.lowercased() {
        for keyword in configuration.filters.excludeKeywords {
            if title.contains(keyword.lowercased()) {
                if args.verbose {
                    print("   ⏭️ Skipping event with excluded keyword '\(keyword)': \(event.title ?? "Untitled")")
                }
                return false
            }
        }
    }

    return true
}

print("📊 \(filteredEvents.count) events after applying filters")

// Show comprehensive event data in verbose mode
if args.verbose {
    if !events.isEmpty {
        print("\n📅 ALL EVENTS COMPREHENSIVE DATA:")
        print("   Total events fetched: \(events.count)")
        print("")

        for (index, event) in events.enumerated() {
            print("   ========== EVENT \(index + 1) ==========")
            print("   📝 BASIC INFO:")
            print("     Title: \(event.title ?? "Untitled")")
            print("     Event ID: \(event.eventIdentifier ?? "No ID")")
            print("     Start: \(formatDate(event.startDate))")
            print("     End: \(formatDate(event.endDate))")
            print("     All-day: \(event.isAllDay)")
            print("     Duration: \(event.endDate.timeIntervalSince(event.startDate) / 60) minutes")
            print("     Notes: \(event.notes ?? "No notes")")
            print("     Location: \(event.location ?? "No location")")
            print("     URL: \(event.url?.absoluteString ?? "No URL")")
            print("     Status: \(event.status.rawValue)")
            print("     Availability: \(event.availability.rawValue)")

            print("   🔄 RECURRENCE:")
            print("     Has recurrence rules: \(event.hasRecurrenceRules)")
            if let rules = event.recurrenceRules {
                for (i, rule) in rules.enumerated() {
                    print("     Rule \(i + 1): \(rule)")
                }
            }

            print("   👤 ORGANIZER:")
            if let organizer = event.organizer {
                let organizerEmail = organizer.url.absoluteString.replacingOccurrences(of: "mailto:", with: "")
                print("     Name: \(organizer.name ?? "No name")")
                print("     Email: \(organizerEmail)")
                print("     Type: \(organizer.participantType.rawValue)")
                print("     Role: \(organizer.participantRole.rawValue)")
                print("     Status: \(organizer.participantStatus.rawValue)")
            } else {
                print("     No organizer information")
            }

            print("   👥 ATTENDEES:")
            if let attendees = event.attendees {
                print("     Count: \(attendees.count)")
                if attendees.isEmpty {
                    print("     No attendees")
                } else {
                    for (i, attendee) in attendees.enumerated() {
                        let attendeeEmail = attendee.url.absoluteString.replacingOccurrences(of: "mailto:", with: "")
                        print("     [\(i + 1)] Name: \(attendee.name ?? "No name")")
                        print("         Email: \(attendeeEmail)")
                        print("         URL (raw): \(attendee.url.absoluteString)")
                        print("         Type: \(attendee.participantType.rawValue) (1=Person, 2=Room, 3=Group)")
                        print("         Role: \(attendee.participantRole.rawValue) (1=Chair, 2=Required, 3=Optional)")
                        print("         Status: \(attendee.participantStatus.rawValue) (1=Unknown, 2=Pending, 3=Accepted, 4=Declined, 5=Tentative)")
                    }
                }
            } else {
                print("     Attendees list is nil")
            }

            print("   📆 CALENDAR INFO:")
            print("     Calendar: \(event.calendar?.title ?? "No calendar")")
            print("     Calendar source: \(event.calendar?.source.title ?? "No source")")
            print("     Calendar type: \(event.calendar != nil ? calendarTypeDescription(event.calendar!.type) : "Unknown")")

            print("   🔍 METADATA:")
            print("     Created: \(event.creationDate != nil ? formatDate(event.creationDate!) : "Unknown")")
            print("     Modified: \(event.lastModifiedDate != nil ? formatDate(event.lastModifiedDate!) : "Unknown")")
            print("     Time zone: \(event.timeZone?.identifier ?? "No timezone")")

            // Show filtering result for this event
            var passesFilters = true
            var filterReasons: [String] = []

            if configuration.filters.excludeAllDay && event.isAllDay {
                passesFilters = false
                filterReasons.append("All-day event excluded")
            }

            if let title = event.title?.lowercased() {
                for keyword in configuration.filters.excludeKeywords {
                    if title.contains(keyword.lowercased()) {
                        passesFilters = false
                        filterReasons.append("Contains excluded keyword '\(keyword)'")
                    }
                }
            }

            print("   ✅ FILTER STATUS:")
            print("     Passes filters: \(passesFilters)")
            if !passesFilters {
                for reason in filterReasons {
                    print("     Reason: \(reason)")
                }
            }

            print("   🎯 1:1 ANALYSIS (Raw Check):")
            if event.isAllDay {
                print("     Skipped: All-day event")
            } else if (event.attendees?.count ?? 0) != 2 {
                print("     Skipped: Has \(event.attendees?.count ?? 0) attendees (need exactly 2)")
            } else {
                print("     Has exactly 2 attendees - checking owner match...")
                if let attendees = event.attendees {
                    let ownerEmails = getOwnerEmailsForDebugging(calendarOwner: calendarOwnerIdentifier)
                    print("     Owner patterns: \(ownerEmails)")
                    for (i, attendee) in attendees.enumerated() {
                        let attendeeEmail = attendee.url.absoluteString.replacingOccurrences(of: "mailto:", with: "")
                        let matches = ownerEmails.contains { ownerEmail in
                            let emailLower = attendeeEmail.lowercased()
                            let ownerEmailLower = ownerEmail.lowercased()
                            return emailLower == ownerEmailLower ||
                                   ownerEmailLower.contains(emailLower) ||
                                   emailLower.contains(ownerEmailLower) ||
                                   emailLower.components(separatedBy: "@").first == ownerEmailLower.components(separatedBy: "@").first
                        }
                        print("     Attendee [\(i+1)] '\(attendeeEmail)' matches owner: \(matches)")
                    }
                }
            }

            print("   📊 RAW EVENT DATA SUMMARY:")
            print("     JSON-like representation:")
            print("     {")
            print("       \"title\": \"\(event.title ?? "null")\",")
            print("       \"eventIdentifier\": \"\(event.eventIdentifier ?? "null")\",")
            print("       \"isAllDay\": \(event.isAllDay),")
            print("       \"attendeeCount\": \(event.attendees?.count ?? 0),")
            print("       \"hasRecurrenceRules\": \(event.hasRecurrenceRules),")
            print("       \"status\": \(event.status.rawValue),")
            print("       \"availability\": \(event.availability.rawValue)")
            if let attendees = event.attendees {
                print("       \"attendees\": [")
                for (i, attendee) in attendees.enumerated() {
                    let attendeeEmail = attendee.url.absoluteString.replacingOccurrences(of: "mailto:", with: "")
                    let comma = i < attendees.count - 1 ? "," : ""
                    print("         {")
                    print("           \"name\": \"\(attendee.name ?? "null")\",")
                    print("           \"email\": \"\(attendeeEmail)\",")
                    print("           \"participantType\": \(attendee.participantType.rawValue),")
                    print("           \"participantRole\": \(attendee.participantRole.rawValue),")
                    print("           \"participantStatus\": \(attendee.participantStatus.rawValue)")
                    print("         }\(comma)")
                }
                print("       ]")
            }
            print("     }")

            print("")
        }

        print("\n📈 EVENT STATISTICS:")
        let totalEvents = events.count
        let allDayCount = events.filter { $0.isAllDay }.count
        let withAttendeesCount = events.filter { ($0.attendees?.count ?? 0) > 0 }.count
        let twoAttendeeCount = events.filter { ($0.attendees?.count ?? 0) == 2 }.count
        let recurringCount = events.filter { $0.hasRecurrenceRules }.count

        print("   Total events: \(totalEvents)")
        print("   All-day events: \(allDayCount) (\(totalEvents > 0 ? String(format: "%.1f", Double(allDayCount) * 100.0 / Double(totalEvents)) : "0")%)")
        print("   Events with attendees: \(withAttendeesCount) (\(totalEvents > 0 ? String(format: "%.1f", Double(withAttendeesCount) * 100.0 / Double(totalEvents)) : "0")%)")
        print("   Events with exactly 2 attendees: \(twoAttendeeCount) (\(totalEvents > 0 ? String(format: "%.1f", Double(twoAttendeeCount) * 100.0 / Double(totalEvents)) : "0")%)")
        print("   Recurring events: \(recurringCount) (\(totalEvents > 0 ? String(format: "%.1f", Double(recurringCount) * 100.0 / Double(totalEvents)) : "0")%)")

    } else {
        print("\n📅 No events found in the specified date range")
        print("   Check your sync window settings:")
        print("   - Start date: \(formatDateLong(startDate))")
        print("   - End date: \(formatDateLong(endDate))")
        print("   - Consider extending the sync window or adjusting start_offset")
    }
}

// Show filtered events summary in verbose mode
if args.verbose && !filteredEvents.isEmpty {
    print("\n🔍 FILTERED EVENTS ANALYSIS (events that passed filters):")
    for (index, event) in filteredEvents.enumerated() {
        let attendeeCount = event.attendees?.count ?? 0
        print("   [\(index + 1)] \(event.title ?? "Untitled") - \(attendeeCount) attendees at \(formatDate(event.startDate))")
    }
}

// Analyze events for 1:1 meetings
print("\n🔍 Analyzing events for 1:1 meetings...")

// Use configured owner email if available, otherwise fall back to calendar source
let calendarOwnerIdentifier = calendarPair.ownerEmail ?? sourceCalendar.source.title
print("   Using calendar owner identifier: '\(calendarOwnerIdentifier)'")

if args.verbose {
    print("   🔍 Owner identification details:")
    if calendarPair.ownerEmail != nil {
        print("     ✅ Using configured owner email: '\(calendarOwnerIdentifier)'")
    } else {
        print("     ⚠️  Using calendar source title: '\(calendarOwnerIdentifier)'")
        print("     💡 Consider setting 'owner_email' in config for better accuracy")
    }

    let debugOwnerEmails = getOwnerEmailsForDebugging(calendarOwner: calendarOwnerIdentifier)
    print("     Generated matching patterns: \(debugOwnerEmails)")

    // Check if this looks like an email or account name
    if calendarOwnerIdentifier.contains("@") {
        print("     ✅ Owner identifier looks like an email address")
    } else {
        print("     ⚠️  Owner identifier looks like an account name")
        print("     💡 This may cause matching issues with attendee emails")
    }
}

let oneOnOneMeetings = filteredEvents.filter { event in
    let isOneOnOne = analyzer.isOneOnOneMeeting(event, calendarOwner: calendarOwnerIdentifier)

    if args.verbose {
        let attendeeCount = event.attendees?.count ?? 0
        print("\n   📋 Analyzing '\(event.title ?? "Untitled")':")
        print("     - Attendee count: \(attendeeCount)")
        print("     - All-day event: \(event.isAllDay)")
        print("     - Has attendees list: \(event.attendees != nil)")

        if let attendees = event.attendees {
            print("     - Attendee details:")
            for (i, attendee) in attendees.enumerated() {
                let email = attendee.url.absoluteString.replacingOccurrences(of: "mailto:", with: "")
                let participantType = attendee.participantType.rawValue
                let participantRole = attendee.participantRole.rawValue
                let participantStatus = attendee.participantStatus.rawValue
                print("       [\(i+1)] \(attendee.name ?? "No name") <\(email)>")
                print("           Type: \(participantType), Role: \(participantRole), Status: \(participantStatus)")
            }

            // Show owner matching details
            print("     - Owner matching analysis:")
            print("       Calendar owner identifier: '\(calendarOwnerIdentifier)'")

            let ownerEmails = getOwnerEmailsForDebugging(calendarOwner: calendarOwnerIdentifier)
            print("       Generated owner emails: \(ownerEmails)")

            let attendeeEmails = attendees.compactMap { attendee in
                attendee.url.absoluteString.replacingOccurrences(of: "mailto:", with: "")
            }
            print("       Attendee emails: \(attendeeEmails)")

            // Check each attendee for owner match
            for (i, attendeeEmail) in attendeeEmails.enumerated() {
                let matches = ownerEmails.contains { ownerEmail in
                    let emailLower = attendeeEmail.lowercased()
                    let ownerEmailLower = ownerEmail.lowercased()
                    return emailLower == ownerEmailLower ||
                           ownerEmailLower.contains(emailLower) ||
                           emailLower.contains(ownerEmailLower) ||
                           emailLower.components(separatedBy: "@").first == ownerEmailLower.components(separatedBy: "@").first
                }
                print("       Attendee [\(i+1)] '\(attendeeEmail)' matches owner: \(matches)")
            }
        } else {
            print("     - No attendees found in event")
        }

        print("     - Final 1:1 detection result: \(isOneOnOne)")

        if attendeeCount == 2 && !isOneOnOne {
            print("   ❌ Event has exactly 2 attendees but was NOT detected as 1:1")
            print("      This suggests an issue with owner email matching.")
        } else if attendeeCount != 2 {
            print("   ℹ️  Event has \(attendeeCount) attendees (need exactly 2 for 1:1)")
        } else if isOneOnOne {
            print("   ✅ Successfully detected as 1:1 meeting")
        }
    }

    return isOneOnOne
}

print("📊 Found \(oneOnOneMeetings.count) 1:1 meetings")

// Add comprehensive debugging summary in verbose mode
if args.verbose {
    print("\n📊 DEBUGGING SUMMARY:")
    print("   Total events fetched: \(events.count)")
    print("   Events after filtering: \(filteredEvents.count)")
    print("   Events detected as 1:1: \(oneOnOneMeetings.count)")

    // Analyze attendee count distribution
    let attendeeCountStats = filteredEvents.reduce(into: [Int: Int]()) { counts, event in
        let count = event.attendees?.count ?? 0
        counts[count, default: 0] += 1
    }

    print("\n   📈 Attendee count distribution:")
    for (count, eventCount) in attendeeCountStats.sorted(by: { $0.key < $1.key }) {
        let percentage = Double(eventCount) / Double(filteredEvents.count) * 100
        print("     \(count) attendees: \(eventCount) events (\(String(format: "%.1f", percentage))%)")
    }

    // Show events with exactly 2 attendees that weren't detected as 1:1
    let twoAttendeeEvents = filteredEvents.filter { ($0.attendees?.count ?? 0) == 2 }
    let missed1on1s = twoAttendeeEvents.filter { !analyzer.isOneOnOneMeeting($0, calendarOwner: calendarOwnerIdentifier) }

    if !missed1on1s.isEmpty {
        print("\n   ⚠️  \(missed1on1s.count) events with 2 attendees NOT detected as 1:1:")
        for (index, event) in missed1on1s.enumerated() {
            print("     [\(index + 1)] \(event.title ?? "Untitled")")
            if let attendees = event.attendees {
                for attendee in attendees {
                    let email = attendee.url.absoluteString.replacingOccurrences(of: "mailto:", with: "")
                    print("        - \(attendee.name ?? "No name") <\(email)>")
                }
            }

            // Add diagnostic recommendations
            print("\n💡 DIAGNOSTIC RECOMMENDATIONS:")

            if oneOnOneMeetings.isEmpty && !filteredEvents.isEmpty {
                print("   🔍 No 1:1 meetings found. Potential issues:")

                let hasEventsWithTwoAttendees = filteredEvents.contains { ($0.attendees?.count ?? 0) == 2 }
                if hasEventsWithTwoAttendees {
                    print("     • Events with 2 attendees exist but owner matching failed")
                    print("     • Try setting 'owner_email' in your configuration")
                    print("     • Check if your email matches the attendee emails in events")
                } else {
                    print("     • No events with exactly 2 attendees found")
                    print("     • Check your calendar has 1:1 meetings in the date range")
                }

                if calendarPair.ownerEmail == nil {
                    print("     • No 'owner_email' configured - using calendar source: '\(calendarOwnerIdentifier)'")
                    print("     • Consider adding 'owner_email: your.email@domain.com' to config")
                }

                if !calendarOwnerIdentifier.contains("@") {
                    print("     • Owner identifier '\(calendarOwnerIdentifier)' doesn't look like an email")
                    print("     • This may cause matching issues with event attendees")
                }

                let organizerCount = Set(filteredEvents.compactMap { $0.organizer?.url.absoluteString }).count
                if organizerCount > 0 {
                    print("     • Found \(organizerCount) unique organizers - check if any match your identity")
                }
            }

            if filteredEvents.count < events.count {
                let filtered = events.count - filteredEvents.count
                print("   📝 \(filtered) events were filtered out - check filter settings if needed")
            }
        }
        print("   💡 This suggests potential issues with owner email matching.")
        print("   💡 Consider setting 'owner_email' in your configuration.")
    }

    // Show organizer patterns
    let organizerEmails = Set(filteredEvents.compactMap { event in
        event.organizer?.url.absoluteString.replacingOccurrences(of: "mailto:", with: "")
    })

    if !organizerEmails.isEmpty {
        print("\n   📧 Unique organizer emails found:")
        for email in organizerEmails.sorted().prefix(10) {
            print("     - \(email)")
        }
        if organizerEmails.count > 10 {
            print("     ... and \(organizerEmails.count - 10) more")
        }
    }
}

if args.verbose && !oneOnOneMeetings.isEmpty {
    print("   1:1 meetings found:")
    for meeting in oneOnOneMeetings {
        let otherPerson = analyzer.getOtherPersonName(from: meeting, calendarOwner: calendarOwnerIdentifier)
        let recurringInfo = meeting.hasRecurrenceRules ? " (recurring)" : ""
        print("   • \(meeting.title ?? "Untitled") with \(otherPerson) at \(formatDate(meeting.startDate))\(recurringInfo)")
    }
}

// Perform sync operation
print("\n🔄 Starting synchronization...")
let syncResult = syncManager.syncEvents(
    oneOnOneMeetings,
    from: sourceCalendar,
    to: destCalendar,
    analyzer: analyzer,
    calendarOwner: calendarOwnerIdentifier
)

// Print summary
syncManager.printSummary(syncResult, dryRun: args.dryRun)

// Handle errors
if !syncResult.errors.isEmpty {
    print("\n⚠️  Some operations failed. Check the error messages above.")
    exit(1)
}

// Success message
if args.dryRun {
    print("\n💡 To apply these changes, run the command again without --dry-run")
} else {
    print("\n🎉 Synchronization completed successfully!")
}

// Helper functions
func formatDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .short
    return formatter.string(from: date)
}

func formatDateLong(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateStyle = .full
    formatter.timeStyle = .none
    return formatter.string(from: date)
}

func calendarTypeDescription(_ type: EKCalendarType) -> String {
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

// Helper function for debugging owner email matching
func getOwnerEmailsForDebugging(calendarOwner: String) -> [String] {
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
