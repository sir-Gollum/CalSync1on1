import Foundation
import XCTest

@testable import CalSync1on1

final class ConfigurationLoadingTests: XCTestCase {

    // MARK: - Properties

    private var tempConfigPath: String!

    // MARK: - Overridden Functions

    override func setUp() {
        super.setUp()
        // Create a temporary config file path
        let tempDir = NSTemporaryDirectory()
        tempConfigPath = tempDir + "test-config-\(UUID().uuidString).yaml"
    }

    override func tearDown() {
        // Clean up temp file
        if FileManager.default.fileExists(atPath: tempConfigPath) {
            try? FileManager.default.removeItem(atPath: tempConfigPath)
        }
        super.tearDown()
    }

    // MARK: - Functions

    func testConfigurationLoadingFromYAMLFile() {
        let yamlContent = """
        version: "1.0"
        calendar_pair:
          name: "Work to Personal Test"
          source:
            account: null
            calendar: "abc@gmail.com"
          destination:
            account: null
            calendar: "CalSyncTesting"
          title_template: "1:1 with {{otherPerson}}"
        sync_window:
          weeks: 3
          start_offset: -1
        filters:
          exclude_all_day: true
          exclude_keywords:
            - "standup"
            - "daily scrum"
            - "team meeting"
        logging:
          level: "debug"
          colored_output: true
        """

        // Write YAML to temp file
        XCTAssertNoThrow(
            try yamlContent.write(
                to: URL(fileURLWithPath: tempConfigPath), atomically: true, encoding: .utf8
            )
        )

        // Load the configuration
        let config = Configuration.load(from: tempConfigPath)

        // Verify all values are loaded correctly
        XCTAssertEqual(config.version, "1.0")

        // Test calendar pair
        XCTAssertEqual(config.calendarPair.name, "Work to Personal Test")
        XCTAssertEqual(config.calendarPair.source.calendar, "abc@gmail.com")
        XCTAssertNil(config.calendarPair.source.account)
        XCTAssertEqual(config.calendarPair.destination.calendar, "CalSyncTesting")
        XCTAssertNil(config.calendarPair.destination.account)
        XCTAssertEqual(config.calendarPair.titleTemplate, "1:1 with {{otherPerson}}")

        // Test sync window
        XCTAssertEqual(config.syncWindow.weeks, 3)
        XCTAssertEqual(config.syncWindow.startOffset, -1)

        // Test filters
        XCTAssertTrue(config.filters.excludeAllDay)
        XCTAssertEqual(config.filters.excludeKeywords, ["standup", "daily scrum", "team meeting"])

        // Test logging
        XCTAssertEqual(config.logging.level, "debug")
        XCTAssertTrue(config.logging.coloredOutput)
    }

    func testConfigurationLoadingWithMissingFile() {
        let nonExistentPath = "/tmp/non-existent-config-\(UUID().uuidString).yaml"

        // Should return default configuration when file doesn't exist
        let config = Configuration.load(from: nonExistentPath)

        // Should be default configuration
        XCTAssertEqual(config.version, Configuration.default.version)
        XCTAssertEqual(config.calendarPair.source.calendar, "Calendar")
        XCTAssertEqual(config.calendarPair.destination.calendar, "Personal")
        XCTAssertEqual(config.calendarPair.titleTemplate, "1:1 with {{otherPerson}}")
    }

    func testConfigurationLoadingWithInvalidYAML() {
        let invalidYaml = """
        version: "1.0"
        calendar_pair:
          name: "Test"
          source:
            calendar: "Work"
        # Missing destination - invalid structure
        sync_window:
          weeks: "invalid_number"  # Should be number, not string
        """

        XCTAssertNoThrow(
            try invalidYaml.write(
                to: URL(fileURLWithPath: tempConfigPath), atomically: true, encoding: .utf8
            )
        )

        // Should return default configuration when YAML is invalid
        let config = Configuration.load(from: tempConfigPath)

        // Should fall back to default
        XCTAssertEqual(config.version, Configuration.default.version)
        XCTAssertEqual(config.calendarPair.source.calendar, "Calendar")
        XCTAssertEqual(config.calendarPair.destination.calendar, "Personal")
    }

    func testConfigurationLoadingWithMinimalYAML() {
        let minimalYaml = """
        version: "1.0"
        calendar_pair:
          name: "Minimal Test"
          source:
            calendar: "MinimalWork"
          destination:
            calendar: "MinimalPersonal"
          title_template: "Meeting: {{otherPerson}}"
        sync_window:
          weeks: 1
          start_offset: 0
        filters:
          exclude_all_day: false
          exclude_keywords: []
        logging:
          level: "info"
          colored_output: false
        """

        XCTAssertNoThrow(
            try minimalYaml.write(
                to: URL(fileURLWithPath: tempConfigPath), atomically: true, encoding: .utf8
            )
        )

        let config = Configuration.load(from: tempConfigPath)

        XCTAssertEqual(config.version, "1.0")
        XCTAssertEqual(config.calendarPair.name, "Minimal Test")
        XCTAssertEqual(config.calendarPair.source.calendar, "MinimalWork")
        XCTAssertEqual(config.calendarPair.destination.calendar, "MinimalPersonal")
        XCTAssertEqual(config.calendarPair.titleTemplate, "Meeting: {{otherPerson}}")
        XCTAssertEqual(config.syncWindow.weeks, 1)
        XCTAssertEqual(config.syncWindow.startOffset, 0)
        XCTAssertFalse(config.filters.excludeAllDay)
        XCTAssertTrue(config.filters.excludeKeywords.isEmpty)
        XCTAssertEqual(config.logging.level, "info")
        XCTAssertFalse(config.logging.coloredOutput)
    }

    func testConfigurationLoadingWithComplexFilters() {
        let complexFiltersYaml = """
        version: "1.0"
        calendar_pair:
          name: "Complex Filters Test"
          source:
            account: "work@company.com"
            calendar: "Work Calendar"
          destination:
            account: "personal@gmail.com"
            calendar: "Personal Calendar"
          title_template: "1:1 meeting with {{otherPerson}}"
        sync_window:
          weeks: 4
          start_offset: -2
        filters:
          exclude_all_day: true
          exclude_keywords:
            - "standup"
            - "daily"
            - "scrum"
            - "retrospective"
            - "all-hands"
            - "team meeting"
            - "planning"
            - "review"
        logging:
          level: "debug"
          colored_output: true
        """

        XCTAssertNoThrow(
            try complexFiltersYaml.write(
                to: URL(fileURLWithPath: tempConfigPath), atomically: true, encoding: .utf8
            )
        )

        let config = Configuration.load(from: tempConfigPath)

        XCTAssertEqual(config.calendarPair.name, "Complex Filters Test")
        XCTAssertEqual(config.calendarPair.source.account, "work@company.com")
        XCTAssertEqual(config.calendarPair.source.calendar, "Work Calendar")
        XCTAssertEqual(config.calendarPair.destination.account, "personal@gmail.com")
        XCTAssertEqual(config.calendarPair.destination.calendar, "Personal Calendar")
        XCTAssertEqual(config.calendarPair.titleTemplate, "1:1 meeting with {{otherPerson}}")

        XCTAssertEqual(config.syncWindow.weeks, 4)
        XCTAssertEqual(config.syncWindow.startOffset, -2)

        XCTAssertTrue(config.filters.excludeAllDay)
        XCTAssertEqual(config.filters.excludeKeywords.count, 8)
        XCTAssertTrue(config.filters.excludeKeywords.contains("standup"))
        XCTAssertTrue(config.filters.excludeKeywords.contains("all-hands"))
        XCTAssertTrue(config.filters.excludeKeywords.contains("review"))

        XCTAssertEqual(config.logging.level, "debug")
        XCTAssertTrue(config.logging.coloredOutput)
    }

    func testConfigurationSaveAndLoad() {
        // Create a custom configuration
        let customConfig = Configuration(
            version: "1.0",
            calendarPair: Configuration.CalendarPair(
                name: "Save Test",
                source: Configuration.CalendarPair.CalendarInfo(
                    account: "test@work.com", calendar: "Test Work"
                ),
                destination: Configuration.CalendarPair.CalendarInfo(
                    account: "test@personal.com", calendar: "Test Personal"
                ),
                titleTemplate: "Test: {{otherPerson}}",
                ownerEmail: nil
            ),
            syncWindow: Configuration.SyncWindow(weeks: 5, startOffset: 1),
            filters: Configuration.Filters(
                excludeAllDay: false, excludeKeywords: ["test1", "test2"]
            ),
            logging: Configuration.Logging(level: "warn", coloredOutput: false)
        )

        // Save configuration to temp file
        XCTAssertNoThrow(try customConfig.save(to: tempConfigPath))

        // Verify file was created
        XCTAssertTrue(FileManager.default.fileExists(atPath: tempConfigPath))

        // Load configuration from temp file
        let loadedConfig = Configuration.load(from: tempConfigPath)

        // Verify loaded config matches original
        XCTAssertEqual(loadedConfig.version, customConfig.version)
        XCTAssertEqual(loadedConfig.calendarPair.name, customConfig.calendarPair.name)
        XCTAssertEqual(
            loadedConfig.calendarPair.source.account, customConfig.calendarPair.source.account
        )
        XCTAssertEqual(
            loadedConfig.calendarPair.source.calendar, customConfig.calendarPair.source.calendar
        )
        XCTAssertEqual(
            loadedConfig.calendarPair.destination.account,
            customConfig.calendarPair.destination.account
        )
        XCTAssertEqual(
            loadedConfig.calendarPair.destination.calendar,
            customConfig.calendarPair.destination.calendar
        )
        XCTAssertEqual(
            loadedConfig.calendarPair.titleTemplate, customConfig.calendarPair.titleTemplate
        )
        XCTAssertEqual(loadedConfig.syncWindow.weeks, customConfig.syncWindow.weeks)
        XCTAssertEqual(loadedConfig.syncWindow.startOffset, customConfig.syncWindow.startOffset)
        XCTAssertEqual(loadedConfig.filters.excludeKeywords, customConfig.filters.excludeKeywords)
        XCTAssertEqual(loadedConfig.logging.level, customConfig.logging.level)
        XCTAssertEqual(loadedConfig.logging.coloredOutput, customConfig.logging.coloredOutput)
    }

    func testConfigurationLoadingWithEmptyKeywords() {
        let emptyKeywordsYaml = """
        version: "1.0"
        calendar_pair:
          name: "Empty Keywords Test"
          source:
            calendar: "Work"
          destination:
            calendar: "Personal"
          title_template: "1:1 with {{otherPerson}}"
        sync_window:
          weeks: 2
          start_offset: 0
        filters:
          exclude_all_day: true
          exclude_keywords: []
        logging:
          level: "info"
          colored_output: true
        """

        XCTAssertNoThrow(
            try emptyKeywordsYaml.write(
                to: URL(fileURLWithPath: tempConfigPath), atomically: true, encoding: .utf8
            )
        )

        let config = Configuration.load(from: tempConfigPath)

        XCTAssertTrue(config.filters.excludeKeywords.isEmpty)
        XCTAssertEqual(config.filters.excludeKeywords.count, 0)
    }

    func testConfigurationLoadingWithNullAccounts() {
        let nullAccountsYaml = """
        version: "1.0"
        calendar_pair:
          name: "Null Accounts Test"
          source:
            account: null
            calendar: "Test Source"
          destination:
            account: null
            calendar: "Test Destination"
          title_template: "1:1 with {{otherPerson}}"
        sync_window:
          weeks: 2
          start_offset: 0
        filters:
          exclude_all_day: true
          exclude_keywords: ["test"]
        logging:
          level: "info"
          colored_output: true
        """

        XCTAssertNoThrow(
            try nullAccountsYaml.write(
                to: URL(fileURLWithPath: tempConfigPath), atomically: true, encoding: .utf8
            )
        )

        let config = Configuration.load(from: tempConfigPath)

        XCTAssertNil(config.calendarPair.source.account)
        XCTAssertNil(config.calendarPair.destination.account)
        XCTAssertEqual(config.calendarPair.source.calendar, "Test Source")
        XCTAssertEqual(config.calendarPair.destination.calendar, "Test Destination")
    }

    func testcalendarPairAccess() {
        let testYaml = """
        version: "1.0"
        calendar_pair:
          name: "Primary Test"
          source:
            calendar: "Primary Source"
          destination:
            calendar: "Primary Destination"
          title_template: "Primary: {{otherPerson}}"
        sync_window:
          weeks: 2
          start_offset: 0
        filters:
          exclude_all_day: true
          exclude_keywords: []
        logging:
          level: "info"
          colored_output: true
        """

        XCTAssertNoThrow(
            try testYaml.write(
                to: URL(fileURLWithPath: tempConfigPath), atomically: true, encoding: .utf8
            )
        )

        let config = Configuration.load(from: tempConfigPath)
        let calendarPair = config.calendarPair

        XCTAssertEqual(calendarPair.name, "Primary Test")
        XCTAssertEqual(calendarPair.source.calendar, "Primary Source")
        XCTAssertEqual(calendarPair.destination.calendar, "Primary Destination")
        XCTAssertEqual(calendarPair.titleTemplate, "Primary: {{otherPerson}}")
    }
}
