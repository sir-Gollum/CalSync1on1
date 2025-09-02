import EventKit
import Foundation
import XCTest

@testable import CalSync1on1

final class MeetingAnalyzerTests: XCTestCase {

    // MARK: - Properties

    private var analyzer: MeetingAnalyzer!

    // MARK: - Overridden Functions

    override func setUp() {
        super.setUp()
        analyzer = MeetingAnalyzer()
    }

    override func tearDown() {
        analyzer = nil
        super.tearDown()
    }

    // MARK: - Functions

    // MARK: - Email Extraction and Name Formatting Tests

    func testExtractNameFromEmail() {
        let testCases: [(input: String, expected: String, description: String)] = [
            ("jane.doe@company.com", "Jane Doe", "with dots"),
            ("jane_doe@company.com", "Jane Doe", "with underscores"),
            ("jane.doe2@company.com", "Jane Doe2", "with numbers"),
            ("jane_m_doe@company.com", "Jane M Doe", "with complex format"),
            ("jane@company.com", "Jane", "with single name"),
            ("jane.doe", "Jane Doe", "without at symbol"),
            ("", "", "with empty string"),
            ("12345@company.com", "12345", "with only numbers"),
            ("JANE.DOE@company.com", "Jane Doe", "with mixed case"),
            ("first.middle.last@company.com", "First Middle Last", "with multiple dots"),
            ("jane-doe@company.com", "Jane-Doe", "with special characters"),
        ]

        for testCase in testCases {
            let name = analyzer.extractNameFromEmail(testCase.input)
            XCTAssertEqual(
                name, testCase.expected,
                "Failed for email \(testCase.description): '\(testCase.input)'"
            )
        }
    }

    // MARK: - Participant Label Mapping Tests

    func testParticipantTypeLabelMapping() {
        XCTAssertEqual(analyzer.getParticipantTypeLabel(participantType: 1), "Person")
        XCTAssertEqual(analyzer.getParticipantTypeLabel(participantType: 2), "Room")
        XCTAssertEqual(analyzer.getParticipantTypeLabel(participantType: 0), "Group")
        XCTAssertEqual(analyzer.getParticipantTypeLabel(participantType: 99), "Group")
        XCTAssertEqual(analyzer.getParticipantTypeLabel(participantType: -1), "Group")
    }

    func testParticipantRoleLabelMapping() {
        XCTAssertEqual(analyzer.getParticipantRoleLabel(participantRole: 1), "Chair")
        XCTAssertEqual(analyzer.getParticipantRoleLabel(participantRole: 2), "Required")
        XCTAssertEqual(analyzer.getParticipantRoleLabel(participantRole: 0), "Optional")
        XCTAssertEqual(analyzer.getParticipantRoleLabel(participantRole: 99), "Optional")
        XCTAssertEqual(analyzer.getParticipantRoleLabel(participantRole: -1), "Optional")
    }

    func testParticipantStatusLabelMapping() {
        XCTAssertEqual(analyzer.getParticipantStatusLabel(participantStatus: 1), "Unknown")
        XCTAssertEqual(analyzer.getParticipantStatusLabel(participantStatus: 2), "Pending")
        XCTAssertEqual(analyzer.getParticipantStatusLabel(participantStatus: 3), "Accepted")
        XCTAssertEqual(analyzer.getParticipantStatusLabel(participantStatus: 4), "Declines")
        XCTAssertEqual(analyzer.getParticipantStatusLabel(participantStatus: 0), "Tentative")
        XCTAssertEqual(analyzer.getParticipantStatusLabel(participantStatus: 99), "Tentative")
        XCTAssertEqual(analyzer.getParticipantStatusLabel(participantStatus: -1), "Tentative")
    }

    // MARK: - Edge Cases and Robustness Tests

    func testExtractNameFromEmailWithVeryLongEmail() {
        let longEmail = "very.long.email.address.with.many.parts@company.com"
        let name = analyzer.extractNameFromEmail(longEmail)
        XCTAssertEqual(name, "Very Long Email Address With Many Parts")
    }

    // MARK: - Core isOneOnOneMeeting Logic Tests

    func testIsOneOnOneMeetingLogicComponents() {
        // Comprehensive test combining owner email generation, matching logic, and edge cases
        let testCases:
            [(owner: String, attendeeEmail: String, shouldMatch: Bool, description: String)] = [
                // Direct matches
                ("john.doe@company.com", "john.doe@company.com", true, "exact email match"),
                ("john.doe@company.com", "john.doe", true, "local part match"),
                ("john.doe", "john.doe@company.com", true, "owner local part to full email"),
                ("JOHN.DOE@COMPANY.COM", "john.doe@company.com", true, "case insensitive match"),
                ("john@gmail.com", "john@company.com", true, "same local part different domain"),

                // Non-matches
                (
                    "john.smith@company.com", "jane.doe@company.com", false,
                    "different person - no match"
                ),
                ("alice", "bob@company.com", false, "completely different names"),

                // Edge cases
                ("", "john@company.com", false, "empty owner email"),
            ]

        for testCase in testCases {
            let ownerEmails = analyzer.getOwnerEmails(calendarOwner: testCase.owner)

            let matches = ownerEmails.contains { ownerEmail in
                let emailLower = testCase.attendeeEmail.lowercased()
                let ownerEmailLower = ownerEmail.lowercased()

                // Direct match
                if emailLower == ownerEmailLower {
                    return true
                }

                // Contains match
                if ownerEmailLower.contains(emailLower) || emailLower.contains(ownerEmailLower) {
                    return true
                }

                // Local part match
                let emailLocal = emailLower.components(separatedBy: "@").first ?? emailLower
                let ownerLocal =
                    ownerEmailLower.components(separatedBy: "@").first ?? ownerEmailLower

                return emailLocal == ownerLocal
            }

            XCTAssertEqual(
                matches, testCase.shouldMatch,
                "Owner '\(testCase.owner)' should \(testCase.shouldMatch ? "" : "not ")match attendee '\(testCase.attendeeEmail)': \(testCase.description)"
            )
        }
    }

    func testOwnerEmailGenerationAndConsistency() {
        // Test getOwnerEmails function that's crucial for 1:1 detection
        let testCases: [(input: String, expected: [String], description: String)] = [
            (
                "john.doe@company.com", ["john.doe@company.com", "john.doe"],
                "full email with local part"
            ),
            ("john.doe", ["john.doe"], "local part only"),
            ("", [], "empty string"),
        ]

        for testCase in testCases {
            let result1 = analyzer.getOwnerEmails(calendarOwner: testCase.input)
            let result2 = analyzer.getOwnerEmails(calendarOwner: testCase.input)

            // Test expected results
            XCTAssertEqual(result1, testCase.expected, "Failed for: \(testCase.description)")

            // Test consistency
            XCTAssertEqual(
                result1, result2, "Results should be consistent for: \(testCase.description)"
            )
        }
    }

    func testNameExtractionAndConsistency() {
        // Test name extraction logic with various formats and consistency
        let nameExtractionCases: [(email: String, expectedName: String)] = [
            ("john.doe@company.com", "John Doe"),
            ("alice_smith@company.com", "Alice Smith"),
            ("bob@company.com", "Bob"),
            ("complex.name.here@company.com", "Complex Name Here"),
            ("first-last@company.com", "First-Last"),
            ("user123@company.com", "User123"),
            (
                "very.long.email.address.with.many.parts@company.com",
                "Very Long Email Address With Many Parts"
            ),
        ]

        for testCase in nameExtractionCases {
            let extractedName1 = analyzer.extractNameFromEmail(testCase.email)
            let extractedName2 = analyzer.extractNameFromEmail(testCase.email)

            // Test expected extraction
            XCTAssertEqual(
                extractedName1, testCase.expectedName,
                "Name extraction failed for email: \(testCase.email)"
            )

            // Test consistency
            XCTAssertEqual(extractedName1, extractedName2, "Name extraction should be consistent")

            // Test that extracted name doesn't contain @
            XCTAssertFalse(extractedName1.contains("@"), "Extracted name should not contain @")
            XCTAssertFalse(
                extractedName1.isEmpty, "Should extract some name from '\(testCase.email)'"
            )
        }
    }

    func testDebugEventDetailsGeneration() {
        // Test that the debug helper exists and can be called
        // We create a minimal event just to test the debug functionality exists
        let eventStore = EKEventStore()
        let event = EKEvent(eventStore: eventStore)
        event.title = "Debug Test Event"
        event.startDate = Date()
        event.endDate = Date().addingTimeInterval(3600)

        let debugOutput = analyzer.debugEventDetails(event, calendarOwner: "test@company.com")

        XCTAssertTrue(debugOutput.contains("Event Debug Details"), "Should contain debug header")
        XCTAssertTrue(debugOutput.contains("Debug Test Event"), "Should contain event title")
        XCTAssertTrue(debugOutput.contains("test@company.com"), "Should contain owner email")
    }

}
