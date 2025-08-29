import Foundation
import XCTest

@testable import CalSync1on1

final class ConfigurationSetupTests: XCTestCase {

    // MARK: - Properties

    private var tempConfigPath: String!

    // MARK: - Overridden Functions

    override func setUp() {
        super.setUp()

        // Create a temporary config file path
        let tempDir = NSTemporaryDirectory()
        tempConfigPath = tempDir + "test-config-setup-\(UUID().uuidString).yaml"
    }

    override func tearDown() {
        // Clean up temp file
        if FileManager.default.fileExists(atPath: tempConfigPath) {
            try? FileManager.default.removeItem(atPath: tempConfigPath)
        }
        super.tearDown()
    }

    // MARK: - Functions

    func testConfigurationSetupModuleExists() {
        // Test that the setup functionality is available through the Configuration class
        // We test this indirectly by verifying the content generation works
        let content = Configuration.generateDefaultConfigContent()
        XCTAssertFalse(content.isEmpty, "Configuration content should be generated")
        XCTAssertTrue(content.contains("version: \"1.0\""), "Generated content should be valid")
    }

    func testGeneratedConfigurationContentAndStructure() {
        // Test the content generation, YAML validity, and essential content all in one
        let content = Configuration.generateDefaultConfigContent()

        // Write to temp file and verify it can be loaded as valid YAML
        try! content.write(
            to: URL(fileURLWithPath: tempConfigPath),
            atomically: true,
            encoding: .utf8
        )

        let loadedConfig = Configuration.load(from: tempConfigPath)

        // Verify basic structure and default values
        XCTAssertEqual(loadedConfig.version, "1.0")
        XCTAssertEqual(loadedConfig.calendarPair.source.calendar, "Calendar")
        XCTAssertEqual(loadedConfig.calendarPair.destination.calendar, "Personal")
        XCTAssertEqual(loadedConfig.calendarPair.titleTemplate, "1:1 with {{otherPerson}}")
        XCTAssertEqual(loadedConfig.calendarPair.ownerEmail, "your.email@company.com")
        XCTAssertEqual(loadedConfig.syncWindow.weeks, 2)
        XCTAssertEqual(loadedConfig.syncWindow.startOffset, 0)
        XCTAssertTrue(loadedConfig.filters.excludeAllDay)
        XCTAssertEqual(
            loadedConfig.filters.excludeKeywords, ["standup", "all-hands", "team meeting"]
        )
        XCTAssertEqual(loadedConfig.logging.level, "info")
        XCTAssertTrue(loadedConfig.logging.coloredOutput)
        XCTAssertNil(loadedConfig.calendarPair.source.account)
        XCTAssertNil(loadedConfig.calendarPair.destination.account)
    }

    func testGeneratedConfigHasComprehensiveDocumentation() {
        let content = Configuration.generateDefaultConfigContent()

        // Verify essential section headers
        XCTAssertTrue(content.contains("CalSync1on1 Configuration"))
        XCTAssertTrue(content.contains("CALENDAR PAIR CONFIGURATION"))
        XCTAssertTrue(content.contains("SYNC WINDOW CONFIGURATION"))
        XCTAssertTrue(content.contains("EVENT FILTERING RULES"))
        XCTAssertTrue(content.contains("LOGGING CONFIGURATION"))
        XCTAssertTrue(content.contains("TROUBLESHOOTING GUIDE"))

        // Verify helpful content and explanations
        XCTAssertTrue(content.contains("EXACT name of your work calendar"))
        XCTAssertTrue(content.contains("CRITICAL FOR ACCURATE 1:1 DETECTION"))
        XCTAssertTrue(content.contains("Run \"calsync1on1 --verbose --dry-run\""))
        XCTAssertTrue(content.contains("{{otherPerson}}"))
        XCTAssertTrue(content.contains("Use {{otherPerson}} as placeholder"))

        // Verify troubleshooting content
        XCTAssertTrue(content.contains("ALWAYS start with: calsync1on1 --verbose --dry-run"))
        XCTAssertTrue(content.contains("Check owner_email matches your email"))
        XCTAssertTrue(content.contains("Calendar names must match EXACTLY"))
        XCTAssertTrue(content.contains("No 1:1 meetings found"))
        XCTAssertTrue(content.contains("Could not find calendar named"))
        XCTAssertTrue(content.contains("Calendar access denied"))

        // Verify examples in comments
        XCTAssertTrue(
            content.contains("Examples: \"1:1 with {{otherPerson}}\", \"Meeting: {{otherPerson}}\"")
        )
        XCTAssertTrue(content.contains("2 = current week + next week"))
        XCTAssertTrue(content.contains("Use -1 to include last week"))
        XCTAssertTrue(content.contains("case-insensitive"))
    }

    func testGeneratedConfigHasCorrectYAMLStructure() {
        let content = Configuration.generateDefaultConfigContent()

        // Verify essential YAML structure elements
        XCTAssertTrue(content.contains("version: \"1.0\""))
        XCTAssertTrue(content.contains("calendar_pair:"))
        XCTAssertTrue(content.contains("  source:"))
        XCTAssertTrue(content.contains("  destination:"))
        XCTAssertTrue(content.contains("  title_template:"))
        XCTAssertTrue(content.contains("  owner_email:"))
        XCTAssertTrue(content.contains("sync_window:"))
        XCTAssertTrue(content.contains("  weeks:"))
        XCTAssertTrue(content.contains("  start_offset:"))
        XCTAssertTrue(content.contains("filters:"))
        XCTAssertTrue(content.contains("  exclude_all_day:"))
        XCTAssertTrue(content.contains("  exclude_keywords:"))
        XCTAssertTrue(content.contains("logging:"))
        XCTAssertTrue(content.contains("  level:"))
        XCTAssertTrue(content.contains("  colored_output:"))

        // Verify default exclude keywords are present
        XCTAssertTrue(content.contains("- \"standup\""))
        XCTAssertTrue(content.contains("- \"all-hands\""))
        XCTAssertTrue(content.contains("- \"team meeting\""))
    }

}
