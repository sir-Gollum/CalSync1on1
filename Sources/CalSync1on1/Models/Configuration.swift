import Foundation
import Yams

// Command line arguments structure
struct CommandLineArgs {
    let configPath: String?
    let dryRun: Bool
    let verbose: Bool
    let help: Bool
    let version: Bool

    static func parse() -> CommandLineArgs {
        let args = CommandLine.arguments

        return CommandLineArgs(
            configPath: extractValue(for: "--config", from: args),
            dryRun: args.contains("--dry-run"),
            verbose: args.contains("--verbose"),
            help: args.contains("--help") || args.contains("-h"),
            version: args.contains("--version")
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
    let version: String
    let calendarPair: CalendarPair
    let syncWindow: SyncWindow
    let filters: Filters
    let logging: Logging

    enum CodingKeys: String, CodingKey {
        case version
        case calendarPair = "calendar_pair"
        case syncWindow = "sync_window"
        case filters
        case logging
    }

    struct CalendarPair: Codable {
        let name: String
        let source: CalendarInfo
        let destination: CalendarInfo
        let titleTemplate: String
        let ownerEmail: String?

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
    }

    struct SyncWindow: Codable {
        let weeks: Int
        let startOffset: Int

        enum CodingKeys: String, CodingKey {
            case weeks
            case startOffset = "start_offset"
        }
    }

    struct Filters: Codable {
        let excludeAllDay: Bool
        let excludeKeywords: [String]

        enum CodingKeys: String, CodingKey {
            case excludeAllDay = "exclude_all_day"
            case excludeKeywords = "exclude_keywords"
        }
    }

    struct Logging: Codable {
        let level: String
        let coloredOutput: Bool

        enum CodingKeys: String, CodingKey {
            case level
            case coloredOutput = "colored_output" // TODO: not implemented
        }
    }

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

    // Load configuration from file or use default
    static func load(from path: String? = nil) -> Configuration {
        let configPath = path ?? defaultConfigPath()

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

    private static func defaultConfigPath() -> String {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        return homeDir.appendingPathComponent(".config/calsync1on1/config.yaml").path
    }
}
