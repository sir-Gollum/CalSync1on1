import Foundation
import XCTest

@testable import CalSync1on1

final class ConfigurationWriteTests: XCTestCase {

    // MARK: - Properties

    private var tempConfigPath: String!

    // MARK: - Overridden Functions

    // MARK: - Setup & Teardown

    override func setUp() {
        super.setUp()
        let tempDir = NSTemporaryDirectory()
        tempConfigPath = tempDir + "test-config-write-\(UUID().uuidString).yaml"
    }

    override func tearDown() {
        if FileManager.default.fileExists(atPath: tempConfigPath) {
            try? FileManager.default.removeItem(atPath: tempConfigPath)
        }
        super.tearDown()
    }

    // MARK: - Functions

    // MARK: - Tests

    func testWriteDefaultConfigurationSuccess() {
        // Test writing to new file
        let success = Configuration.writeDefaultConfiguration(
            to: tempConfigPath, skipConfirmation: true
        )

        XCTAssertTrue(success, "Should successfully write configuration")
        XCTAssertTrue(FileManager.default.fileExists(atPath: tempConfigPath), "File should exist")

        // Verify file content matches expected default
        let writtenContent = try! String(contentsOfFile: tempConfigPath, encoding: .utf8)
        let expectedContent = Configuration.generateDefaultConfigContent()
        XCTAssertEqual(
            writtenContent, expectedContent, "Written content should match generated default"
        )

        // Verify the written file can be loaded as valid YAML
        let loadedConfig = Configuration.load(from: tempConfigPath)
        XCTAssertEqual(loadedConfig.version, "1.0")
        XCTAssertEqual(loadedConfig.calendarPair.source.calendar, "Calendar")
        XCTAssertEqual(loadedConfig.calendarPair.destination.calendar, "Personal")
        XCTAssertEqual(loadedConfig.calendarPair.titleTemplate, "1:1 with {{otherPerson}}")
        XCTAssertEqual(loadedConfig.syncWindow.weeks, 2)
        XCTAssertTrue(loadedConfig.filters.excludeAllDay)
        XCTAssertEqual(
            loadedConfig.filters.excludeKeywords, ["standup", "all-hands", "team meeting"]
        )
    }

    func testWriteDefaultConfigurationOverwrite() {
        // Create existing file with different content
        let existingContent = "# Old config\nversion: \"0.5\""
        try! existingContent.write(
            to: URL(fileURLWithPath: tempConfigPath), atomically: true, encoding: .utf8
        )

        // Overwrite with default configuration
        let success = Configuration.writeDefaultConfiguration(
            to: tempConfigPath, skipConfirmation: true
        )

        XCTAssertTrue(success, "Should successfully overwrite existing file")

        // Verify content was replaced
        let newContent = try! String(contentsOfFile: tempConfigPath, encoding: .utf8)
        XCTAssertNotEqual(
            newContent, existingContent, "Content should be different after overwrite"
        )
        XCTAssertTrue(newContent.contains("version: \"1.0\""), "Should contain default version")

        // Verify essential sections are present
        XCTAssertTrue(newContent.contains("CalSync1on1 Configuration"))
        XCTAssertTrue(newContent.contains("CALENDAR PAIR CONFIGURATION"))
        XCTAssertTrue(newContent.contains("TROUBLESHOOTING GUIDE"))
    }

    func testWriteDefaultConfigurationFailure() {
        // Test with invalid path that should fail
        let invalidPath = "/root/invalid/path/config.yaml"

        let success = Configuration.writeDefaultConfiguration(
            to: invalidPath, skipConfirmation: true
        )

        XCTAssertFalse(success, "Should fail gracefully for invalid paths")
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: invalidPath),
            "File should not exist when write fails"
        )
    }
}
