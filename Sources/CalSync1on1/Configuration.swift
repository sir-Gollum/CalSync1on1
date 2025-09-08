import Foundation
import Yams

// Command line arguments structure
struct CommandLineArgs {

    // MARK: - Properties

    let configPath: String?
    let dryRun: Bool
    let verbose: Bool
    let help: Bool
    let version: Bool
    let setup: Bool

    // MARK: - Static Functions

    static func parse(from args: [String]? = nil) -> CommandLineArgs {
        let arguments = args ?? CommandLine.arguments

        return CommandLineArgs(
            configPath: extractValue(for: "--config", from: arguments),
            dryRun: arguments.contains("--dry-run"),
            verbose: arguments.contains("--verbose"),
            help: arguments.contains("--help") || arguments.contains("-h"),
            version: arguments.contains("--version"),
            setup: arguments.contains("--setup")
        )
    }

    private static func extractValue(for flag: String, from args: [String]) -> String? {
        guard let index = args.firstIndex(of: flag),
              index + 1 < args.count
        else {
            return nil
        }
        return args[index + 1]
    }
}

struct Configuration: Codable {

    // MARK: - Nested Types

    enum CodingKeys: String, CodingKey {
        case version
        case calendarPair = "calendar_pair"
        case syncWindow = "sync_window"
        case filters
        case logging
    }

    struct CalendarPair: Codable {

        // MARK: - Nested Types

        enum CodingKeys: String, CodingKey {
            case name
            case source
            case destination
            case titleTemplate = "title_template"
            case ownerEmail = "owner_email"
        }

        struct CalendarInfo: Codable {
            let account: String?
            let calendar: String
        }

        // MARK: - Properties

        let name: String
        let source: CalendarInfo
        let destination: CalendarInfo
        let titleTemplate: String
        let ownerEmail: String?

    }

    struct SyncWindow: Codable {

        // MARK: - Nested Types

        enum CodingKeys: String, CodingKey {
            case weeks
            case startOffset = "start_offset"
        }

        // MARK: - Properties

        let weeks: Int
        let startOffset: Int

    }

    struct Filters: Codable {

        // MARK: - Nested Types

        enum CodingKeys: String, CodingKey {
            case excludeAllDay = "exclude_all_day"
            case excludeKeywords = "exclude_keywords"
        }

        // MARK: - Properties

        let excludeAllDay: Bool
        let excludeKeywords: [String]

    }

    struct Logging: Codable {

        // MARK: - Nested Types

        enum CodingKeys: String, CodingKey {
            case level
            case coloredOutput = "colored_output" // TODO: not implemented
        }

        // MARK: - Properties

        let level: String
        let coloredOutput: Bool

    }

    // MARK: - Static Properties

    // Default configuration
    static let `default` = Configuration(
        version: "1.0",
        calendarPair: CalendarPair(
            name: "Work to Personal",
            source: CalendarPair.CalendarInfo(account: nil, calendar: "Calendar"),
            destination: CalendarPair.CalendarInfo(account: nil, calendar: "Personal"),
            titleTemplate: "1:1 with {{otherPerson}}",
            ownerEmail: nil
        ),
        syncWindow: SyncWindow(weeks: 2, startOffset: 0),
        filters: Filters(excludeAllDay: true, excludeKeywords: ["standup", "all-hands"]),
        logging: Logging(level: "info", coloredOutput: true)
    )

    // MARK: - Properties

    let version: String
    let calendarPair: CalendarPair
    let syncWindow: SyncWindow
    let filters: Filters
    let logging: Logging

    // MARK: - Static Functions

    // Load configuration from file or use default
    static func load(from path: String? = nil) -> Configuration {
        let configPath = path ?? Configuration.defaultConfigPath()

        guard FileManager.default.fileExists(atPath: configPath) else {
            Logger.info("Using default configuration (config file not found at \(configPath))")
            return .default
        }

        guard let data = try? Data(contentsOf: URL(fileURLWithPath: configPath)) else {
            Logger.error("Error: Could not read configuration file at \(configPath)")
            Logger.info("Using default configuration")
            return .default
        }

        guard let yamlString = String(data: data, encoding: .utf8) else {
            Logger.error("Error: Could not decode configuration file as UTF-8")
            Logger.info("Using default configuration")
            return .default
        }

        do {
            let config = try YAMLDecoder().decode(Configuration.self, from: yamlString)
            Logger.info("✅ Loaded configuration from \(configPath)")
            Logger.info("   Source calendar: \(config.calendarPair.source.calendar)")
            Logger.info("   Destination calendar: \(config.calendarPair.destination.calendar)")
            Logger.info("   Title template: \(config.calendarPair.titleTemplate)")
            Logger.info("   Sync window: \(config.syncWindow.weeks) weeks")
            if !config.filters.excludeKeywords.isEmpty {
                Logger.info(
                    "   Excluded keywords: \(config.filters.excludeKeywords.joined(separator: ", "))"
                )
            }
            return config
        } catch {
            Logger.error("Error: Failed to parse YAML configuration: \(error)")
            Logger.info("Using default configuration")
            return .default
        }
    }

    static func writeDefaultConfiguration(to path: String? = nil, skipConfirmation: Bool = false)
        -> Bool {
        let configPath = path ?? defaultConfigPath()
        let configDir = URL(fileURLWithPath: configPath).deletingLastPathComponent()

        // Check if config file already exists
        if FileManager.default.fileExists(atPath: configPath) {
            if !skipConfirmation {
                Logger.info("⚠️  Configuration file already exists at:")
                Logger.info("   \(configPath)")
                Logger.info("")

                if !getUserConfirmation("Do you want to overwrite it?") {
                    Logger.info("✅ Keeping existing configuration file")
                    Logger.info("   You can view it with: cat \(configPath)")
                    Logger.info("   Or edit it with: open -t \(configPath)")
                    return false
                }
            }
        }

        // Create config directory if it doesn't exist
        do {
            try FileManager.default.createDirectory(
                at: configDir,
                withIntermediateDirectories: true,
                attributes: nil
            )
        } catch {
            Logger.error("Failed to create config directory: \(error)")
            return false
        }

        // Generate the configuration content
        let configContent = generateDefaultConfigContent()

        // Write the configuration file
        do {
            try configContent.write(
                to: URL(fileURLWithPath: configPath),
                atomically: true,
                encoding: .utf8
            )

            Logger.info("✅ Configuration file created successfully!")
            Logger.info("")
            Logger.info("📍 Configuration file location:")
            Logger.info("   \(configPath)")
            Logger.info("")
            Logger.info("🔍 Next steps:")
            Logger.info(
                "   1. Review the configuration file and update with your actual calendar names"
            )
            Logger.info("   2. Set your owner_email to match your email in meeting attendees")
            Logger.info("   3. Test with: calsync1on1 --dry-run --verbose")
            Logger.info("   4. If everything looks good, run: calsync1on1")
            Logger.info("")
            Logger.info("💡 Pro tip: Run with --verbose to see all available calendar names")

            return true

        } catch {
            Logger.error("Failed to write configuration file: \(error)")
            return false
        }
    }

    static func generateDefaultConfigContent() -> String {
        let header = generateYAMLHeader()
        let calendarSection = generateCalendarSection()
        let syncSection = generateSyncSection()
        let filtersSection = generateFiltersSection()
        let loggingSection = generateLoggingSection()
        let troubleshootingSection = generateTroubleshootingSection()

        return [
            header, calendarSection, syncSection, filtersSection, loggingSection,
            troubleshootingSection,
        ].joined(separator: "\n\n")
    }

    /// Returns the default configuration file path
    private static func defaultConfigPath() -> String {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        return homeDir.appendingPathComponent(".config/calsync1on1/config.yaml").path
    }

    private static func generateYAMLHeader() -> String {
        """
        # CalSync1on1 Configuration
        #
        # This file controls how your 1:1 meetings are synchronized between calendars.
        # For detailed documentation, visit: https://github.com/sir-Gollum/CalSync1on1

        version: "1.0"
        """
    }

    private static func generateCalendarSection() -> String {
        """
        # ═══════════════════════════════════════════════════════════════════════════════════
        # CALENDAR PAIR CONFIGURATION
        # ═══════════════════════════════════════════════════════════════════════════════════
        # Defines which calendars to sync between and how to format the synced events.

        calendar_pair:
          name: "Work to Personal Sync"

          # SOURCE CALENDAR (where 1:1 meetings come from)
          # This is typically your work calendar
          source:
            account: null                    # Recommended: specify account if you have multiple
            calendar: "Calendar"             # EXACT name of your work calendar

          # DESTINATION CALENDAR (where synced events are created)
          # This is typically your personal/family calendar
          destination:
            account: null                    # Recommended: specify account if you have multiple
            calendar: "Personal"             # EXACT name of your personal calendar

          # TITLE TEMPLATE
          # How synced events should be titled. Use {{otherPerson}} as placeholder.
          # Examples: "1:1 with {{otherPerson}}", "Meeting: {{otherPerson}}", "{{otherPerson}}"
          title_template: "1:1 with {{otherPerson}}"

          # OWNER EMAIL - CRITICAL FOR ACCURATE 1:1 DETECTION
          # This MUST be your actual email address as it appears in meeting attendees.
          # The tool uses this to determine which meetings are 1:1s (exactly 2 people including you).
          #
          # 💡 Run "calsync1on1 --verbose --dry-run" to see what emails appear in your events
          # 🚨 If this is wrong, NO meetings will be detected as 1:1s!
          owner_email: "your.email@company.com"
        """
    }

    private static func generateSyncSection() -> String {
        """
        # ═══════════════════════════════════════════════════════════════════════════════════
        # SYNC WINDOW CONFIGURATION
        # ═══════════════════════════════════════════════════════════════════════════════════
        # Controls the time range for synchronization

        sync_window:
          # Number of weeks to sync (including current week)
          # 2 = current week + next week, 4 = current + next 3 weeks
          weeks: 2

          # Week offset from current week (0 = start with current week)
          # Use -1 to include last week (useful for testing)
          start_offset: 0
        """
    }

    private static func generateFiltersSection() -> String {
        """
        # ═══════════════════════════════════════════════════════════════════════════════════
        # EVENT FILTERING RULES
        # ═══════════════════════════════════════════════════════════════════════════════════
        # Controls which events are considered for synchronization

        filters:
          # Skip all-day events (usually not relevant for 1:1 meetings)
          exclude_all_day: true

          # Skip events containing these keywords (case-insensitive)
          # Add or remove keywords based on your meeting patterns
          exclude_keywords:
            - "standup"
            - "all-hands"
            - "team meeting"
        """
    }

    private static func generateLoggingSection() -> String {
        """
        # ═══════════════════════════════════════════════════════════════════════════════════
        # LOGGING CONFIGURATION (To be implemented)
        # ═══════════════════════════════════════════════════════════════════════════════════

        logging:
          # Log levels: error, warn, info, debug
          # Use "debug" for troubleshooting, "info" for normal operation
          level: "info"

          # Enable colored console output (recommended)
          colored_output: true
        """
    }

    private static func generateTroubleshootingSection() -> String {
        """
        # ═══════════════════════════════════════════════════════════════════════════════════
        # TROUBLESHOOTING GUIDE
        # ═══════════════════════════════════════════════════════════════════════════════════
        #
        # 🔍 DEBUGGING STEPS:
        #   1. ALWAYS start with: calsync1on1 --verbose --dry-run
        #   2. This shows all available calendars and event details
        #
        # 🚨 COMMON ISSUES:
        #
        #   "No 1:1 meetings found":
        #     ➤ Check owner_email matches your email in meeting attendees
        #     ➤ Look for "events with 2 attendees NOT detected as 1:1" in verbose output
        #     ➤ Verify you're included as an attendee in the meetings
        #
        #   "Could not find calendar named 'X'":
        #     ➤ Calendar names must match EXACTLY (case-sensitive)
        #     ➤ Use --verbose to see all available calendar names
        #     ➤ Look for the "Available calendars:" section in output
        #
        #   "Events being filtered out":
        #     ➤ Set exclude_all_day: false if your 1:1s are all-day events
        #     ➤ Remove keywords that might match your 1:1 meeting titles
        #     ➤ Use --verbose to see why specific events are filtered
        #
        #   "Calendar access denied":
        #     ➤ Grant permission: System Settings > Privacy & Security > Calendars
        #     ➤ Restart the app after granting permission
        #
        # 🛠️ TESTING CONFIGURATION:
        #   For wider date range testing, temporarily set:
        #     weeks: 4
        #     start_offset: -1
        #
        # 📚 MORE HELP:
        #   Run: calsync1on1 --help
        #   Documentation: https://github.com/sir-Gollum/CalSync1on1/blob/main/README.md
        """
    }

    private static func getUserConfirmation(_ question: String) -> Bool {
        Logger.info("\(question) (y/N):")

        guard let input = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        else {
            return false
        }

        if input.isEmpty {
            return false
        }

        return input.starts(with: "y")
    }

    // MARK: - Functions

    // Save configuration to file
    func save(to path: String? = nil) throws {
        let configPath = path ?? Configuration.defaultConfigPath()
        let configDir = URL(fileURLWithPath: configPath).deletingLastPathComponent()

        // Create config directory if it doesn't exist
        try FileManager.default.createDirectory(
            at: configDir, withIntermediateDirectories: true, attributes: nil
        )

        let yamlString = try YAMLEncoder().encode(self)
        try yamlString.write(
            to: URL(fileURLWithPath: configPath), atomically: true, encoding: .utf8
        )
    }

}
