import Foundation
import XCTest

@testable import CalSync1on1

final class CommandLineArgsTests: XCTestCase {

    func testParseEmptyArguments() {
        // Test with just the program name
        let args = CommandLineArgs.parse(from: ["calsync1on1"])

        XCTAssertNil(args.configPath)
        XCTAssertFalse(args.dryRun)
        XCTAssertFalse(args.verbose)
        XCTAssertFalse(args.help)
        XCTAssertFalse(args.version)
        XCTAssertFalse(args.setup)
    }

    func testParseSetupFlag() {
        let args = CommandLineArgs.parse(from: ["calsync1on1", "--setup"])

        XCTAssertTrue(args.setup)
        XCTAssertFalse(args.dryRun)
        XCTAssertFalse(args.verbose)
        XCTAssertFalse(args.help)
        XCTAssertFalse(args.version)
    }

    func testParseSetupFlagWithOtherFlags() {
        let args = CommandLineArgs.parse(from: ["calsync1on1", "--setup", "--verbose"])

        XCTAssertTrue(args.setup)
        XCTAssertTrue(args.verbose)
        XCTAssertFalse(args.dryRun)
        XCTAssertFalse(args.help)
        XCTAssertFalse(args.version)
    }

    func testParseDryRunFlag() {
        let args = CommandLineArgs.parse(from: ["calsync1on1", "--dry-run"])

        XCTAssertTrue(args.dryRun)
        XCTAssertFalse(args.setup)
        XCTAssertFalse(args.verbose)
        XCTAssertFalse(args.help)
        XCTAssertFalse(args.version)
    }

    func testParseVerboseFlag() {
        let args = CommandLineArgs.parse(from: ["calsync1on1", "--verbose"])

        XCTAssertTrue(args.verbose)
        XCTAssertFalse(args.setup)
        XCTAssertFalse(args.dryRun)
        XCTAssertFalse(args.help)
        XCTAssertFalse(args.version)
    }

    func testParseHelpFlag() {
        let args = CommandLineArgs.parse(from: ["calsync1on1", "--help"])

        XCTAssertTrue(args.help)
        XCTAssertFalse(args.setup)
        XCTAssertFalse(args.dryRun)
        XCTAssertFalse(args.verbose)
        XCTAssertFalse(args.version)
    }

    func testParseHelpShortFlag() {
        let args = CommandLineArgs.parse(from: ["calsync1on1", "-h"])

        XCTAssertTrue(args.help)
        XCTAssertFalse(args.setup)
        XCTAssertFalse(args.dryRun)
        XCTAssertFalse(args.verbose)
        XCTAssertFalse(args.version)
    }

    func testParseVersionFlag() {
        let args = CommandLineArgs.parse(from: ["calsync1on1", "--version"])

        XCTAssertTrue(args.version)
        XCTAssertFalse(args.setup)
        XCTAssertFalse(args.dryRun)
        XCTAssertFalse(args.verbose)
        XCTAssertFalse(args.help)
    }

    func testParseConfigPathFlag() {
        let testConfigPath = "/path/to/test-config.yaml"
        let args = CommandLineArgs.parse(from: ["calsync1on1", "--config", testConfigPath])

        XCTAssertEqual(args.configPath, testConfigPath)
        XCTAssertFalse(args.setup)
        XCTAssertFalse(args.dryRun)
        XCTAssertFalse(args.verbose)
        XCTAssertFalse(args.help)
        XCTAssertFalse(args.version)
    }

    func testParseMultipleFlags() {
        let testConfigPath = "/custom/config.yaml"
        let args = CommandLineArgs.parse(from: [
            "calsync1on1",
            "--config", testConfigPath,
            "--dry-run",
            "--verbose",
            "--setup",
        ])

        XCTAssertEqual(args.configPath, testConfigPath)
        XCTAssertTrue(args.dryRun)
        XCTAssertTrue(args.verbose)
        XCTAssertTrue(args.setup)
        XCTAssertFalse(args.help)
        XCTAssertFalse(args.version)
    }

    func testParseConfigFlagWithoutValue() {
        let args = CommandLineArgs.parse(from: ["calsync1on1", "--config"])

        XCTAssertNil(args.configPath)
        XCTAssertFalse(args.setup)
        XCTAssertFalse(args.dryRun)
        XCTAssertFalse(args.verbose)
        XCTAssertFalse(args.help)
        XCTAssertFalse(args.version)
    }

    func testParseConfigFlagAsLastArgument() {
        let args = CommandLineArgs.parse(from: ["calsync1on1", "--verbose", "--config"])

        XCTAssertNil(args.configPath)
        XCTAssertTrue(args.verbose)
        XCTAssertFalse(args.setup)
    }

    func testParseMixedOrderFlags() {
        let testConfigPath = "/test/mixed-order.yaml"
        let args = CommandLineArgs.parse(from: [
            "calsync1on1",
            "--verbose",
            "--config", testConfigPath,
            "--setup",
            "--dry-run",
        ])

        XCTAssertEqual(args.configPath, testConfigPath)
        XCTAssertTrue(args.verbose)
        XCTAssertTrue(args.setup)
        XCTAssertTrue(args.dryRun)
        XCTAssertFalse(args.help)
        XCTAssertFalse(args.version)
    }

    func testParseIgnoresUnknownFlags() {
        let args = CommandLineArgs.parse(from: [
            "calsync1on1",
            "--unknown-flag",
            "--setup",
            "--another-unknown",
            "value",
        ])

        XCTAssertTrue(args.setup)
        XCTAssertNil(args.configPath)
        XCTAssertFalse(args.dryRun)
        XCTAssertFalse(args.verbose)
        XCTAssertFalse(args.help)
        XCTAssertFalse(args.version)
    }

    func testParseAllFlagsAtOnce() {
        let testConfigPath = "/all/flags/config.yaml"
        let args = CommandLineArgs.parse(from: [
            "calsync1on1",
            "--config", testConfigPath,
            "--dry-run",
            "--verbose",
            "--setup",
            "--help",
            "--version",
        ])

        XCTAssertEqual(args.configPath, testConfigPath)
        XCTAssertTrue(args.dryRun)
        XCTAssertTrue(args.verbose)
        XCTAssertTrue(args.setup)
        XCTAssertTrue(args.help)
        XCTAssertTrue(args.version)
    }

    func testParseConfigWithSpacesInPath() {
        let testConfigPath = "/path with spaces/my config.yaml"
        let args = CommandLineArgs.parse(from: ["calsync1on1", "--config", testConfigPath])

        XCTAssertEqual(args.configPath, testConfigPath)
    }

    func testParseConfigWithEmptyPath() {
        let args = CommandLineArgs.parse(from: ["calsync1on1", "--config", ""])

        XCTAssertEqual(args.configPath, "")
    }
}
