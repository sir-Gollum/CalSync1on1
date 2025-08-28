import EventKit
import Foundation

let HELP_TEXT =
    """
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
        calsync1on1                     # Run with default settings
        calsync1on1 --dry-run           # Preview changes without applying
        calsync1on1 --config my.yaml    # Use custom configuration file
        calsync1on1 --verbose --dry-run # Debug mode with detailed output
    """

let VERSION_TEXT =
    """
    CalSync1on1 version 0.5
    macOS Calendar 1:1 Meeting Sync Tool
    """

func main() {
    // Parse command line arguments
    let args = CommandLineArgs.parse()

    // Handle help and version flags
    if args.help {
        print(HELP_TEXT)
        exit(0)
    }

    if args.version {
        print(VERSION_TEXT)
        exit(0)
    }

    // Initialize components
    let logger = Logger(verbose: args.verbose)
    let configuration = Configuration.load(from: args.configPath)
    let calendarManager = CalendarManager()
    let analyzer = MeetingAnalyzer()
    let dateHelper = DateHelper(configuration: configuration)
    let debugHelper = DebugHelper(logger: logger, analyzer: analyzer)
    let syncManager = SyncManager(configuration: configuration, dryRun: args.dryRun)

    logger.info("📅 CalSync1on1 - Syncing 1:1 meetings")
    if args.dryRun { logger.info("🔍 DRY RUN MODE") }

    // Calendar access
    logger.info("\n🔐 Checking calendar permissions...")
    guard calendarManager.requestAccess() else {
        logger.error(
            "Calendar access denied. Check System Preferences > Privacy & Security > Calendars")
        exit(1)
    }
    logger.info("✅ Calendar access granted")
    debugHelper.printCalendarAccessDetails()

    // Find calendars
    logger.info("\n🔍 Finding calendars...")
    let availableCalendars = calendarManager.listAvailableCalendars()
    debugHelper.printAvailableCalendars(availableCalendars)

    let calendarPair = configuration.calendarPair
    guard let sourceCalendar = calendarManager.findCalendar(named: calendarPair.source.calendar),
          let destCalendar = calendarManager.findCalendar(named: calendarPair.destination.calendar)
    else {
        logger.error("Could not find required calendars. Available:")
        for calendar in availableCalendars {
            logger.info("   • \(calendar.title)")
        }
        exit(1)
    }

    logger.info("✅ Source: \(sourceCalendar.title)")
    debugHelper.printCalendarInfo(sourceCalendar, calendarManager: calendarManager)
    logger.info("✅ Destination: \(destCalendar.title)")
    debugHelper.printCalendarInfo(destCalendar, calendarManager: calendarManager)

    // Sync window
    let startDate = dateHelper.getCurrentWeekStart()
    let endDate = dateHelper.getSyncEndDate()
    logger.info(
        "\n📅 Sync window: \(DateHelper.formatDateLong(startDate)) to \(DateHelper.formatDateLong(endDate))"
    )

    // Fetch events
    logger.info("\n📥 Fetching events...")
    let events = calendarManager.getEvents(
        from: sourceCalendar, startDate: startDate, endDate: endDate, debug: logger.isVerbose
    )
    logger.info("Found \(events.count) total events")

    // Handle empty events
    if events.isEmpty {
        debugHelper.diagnoseEmptyEventList(
            sourceCalendar, startDate: startDate, endDate: endDate,
            configuration: configuration, calendarManager: calendarManager
        )
        exit(0)
    }

    // Analyze events
    let calendarOwner = calendarPair.ownerEmail ?? sourceCalendar.source.title
    logger.debug("Using owner identifier: '\(calendarOwner)'")

    debugHelper.printComprehensiveEventAnalysis(
        events, calendarOwner: calendarOwner, configuration: configuration
    )

    // Apply filters
    let filteredEvents = EventFilter.applyFilters(
        events, configuration: configuration, logger: logger
    )
    logger.info("📊 \(filteredEvents.count) events left after filtering")

    // Find 1:1 meetings
    let oneOnOneMeetings = filteredEvents.filter {
        analyzer.isOneOnOneMeeting($0, calendarOwner: calendarOwner)
    }
    logger.info("📊 Found \(oneOnOneMeetings.count) 1:1 meetings")

    // Debug 1:1 details
    if logger.isVerbose, !oneOnOneMeetings.isEmpty {
        logger.debug("1:1 meetings:")
        for meeting in oneOnOneMeetings {
            let otherPerson = analyzer.getOtherPersonName(
                from: meeting, calendarOwner: calendarOwner
            )
            logger.debug("   • \(meeting.title ?? "Untitled") with \(otherPerson)")
        }
    }

    debugHelper.diagnoseNo1on1Meetings(
        events.count, filteredEvents.count, oneOnOneMeetings.count, calendarOwner: calendarOwner
    )

    // Sync
    if !oneOnOneMeetings.isEmpty {
        logger.info("\n🔄 Synchronizing...")
        let result = syncManager.syncEvents(
            oneOnOneMeetings, from: sourceCalendar, to: destCalendar,
            analyzer: analyzer, calendarOwner: calendarOwner
        )
        syncManager.printSummary(result)

        if !result.errors.isEmpty { exit(1) }
    }

    logger.info(args.dryRun ? "\n💡 Run without --dry-run to apply changes" : "\n🎉 Sync completed!")
}

main()
