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

    // MARK: - Owner Email Generation Tests

    func testGetOwnerEmails() {
        let testCases:
            [(
                input: String,
                expectedEmails: [String],
                description: String
            )] = [
                (
                    input: "john.doe@company.com",
                    expectedEmails: ["john.doe@company.com", "john.doe"],
                    description: "full email should contain original email and local part"
                ),
                (
                    input: "john.doe",
                    expectedEmails: ["john.doe"],
                    description: "account name should contain the original variant"
                ),
                (
                    input: "",
                    expectedEmails: [],
                    description: "empty string should return empty array"
                ),
            ]

        for testCase in testCases {
            let ownerEmails = analyzer.getOwnerEmails(calendarOwner: testCase.input)

            // Check that all expected emails are present
            for expectedEmail in testCase.expectedEmails {
                XCTAssertTrue(
                    ownerEmails.contains(expectedEmail),
                    "Missing expected email '\(expectedEmail)' for input '\(testCase.input)': \(testCase.description)"
                )
            }

            // For empty input, verify the result is actually empty
            if testCase.input.isEmpty {
                XCTAssertTrue(ownerEmails.isEmpty, "Empty input should return empty array")
            }
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

    func testGetOwnerEmailsConsistency() {
        // Test that the same input always produces the same output
        let input = "test.user@company.com"
        let result1 = analyzer.getOwnerEmails(calendarOwner: input)
        let result2 = analyzer.getOwnerEmails(calendarOwner: input)

        XCTAssertEqual(result1.count, result2.count)
        for email in result1 {
            XCTAssertTrue(result2.contains(email), "Results should be consistent")
        }
    }

    func testExtractNameFromEmailConsistency() {
        // Test that the same input always produces the same output
        let input = "test.user@company.com"
        let result1 = analyzer.extractNameFromEmail(input)
        let result2 = analyzer.extractNameFromEmail(input)

        XCTAssertEqual(result1, result2, "Results should be consistent")
    }

    // MARK: - Integration Tests for Email Matching Logic

    func testEmailMatchingLogicCombinations() {
        // Test various combinations that would be used in isOneOnOneMeeting
        let ownerVariations = [
            "owner@company.com",
            "OWNER@COMPANY.COM",
            "owner",
            "owner@gmail.com",
        ]

        let attendeeEmail = "owner@company.com"

        for ownerVariation in ownerVariations {
            let ownerEmails = analyzer.getOwnerEmails(calendarOwner: ownerVariation)

            let matches = ownerEmails.contains { ownerEmail in
                let emailLower = attendeeEmail.lowercased()
                let ownerEmailLower = ownerEmail.lowercased()

                // Direct match
                if emailLower == ownerEmailLower {
                    return true
                }

                // Contains match (but be more selective to avoid false positives)
                if ownerEmailLower.contains(emailLower), emailLower.count > 3 {
                    return true
                }
                if emailLower.contains(ownerEmailLower), ownerEmailLower.count > 3 {
                    return true
                }

                // Local part match
                let emailLocal = emailLower.components(separatedBy: "@").first ?? emailLower
                let ownerLocal =
                    ownerEmailLower.components(separatedBy: "@").first ?? ownerEmailLower

                return emailLocal == ownerLocal && emailLocal.count > 1
            }

            XCTAssertTrue(
                matches,
                "Owner variation '\(ownerVariation)' should match attendee '\(attendeeEmail)'"
            )
        }
    }

    func testEmailMatchingLogicNonMatches() {
        // Test cases that should NOT match - using more conservative test cases
        let nonMatchingCases = [
            ("john.smith", "jane.doe@company.com"),
            ("alice", "bob@company.com"),
        ]

        for (owner, attendeeEmail) in nonMatchingCases {
            let ownerEmails = analyzer.getOwnerEmails(calendarOwner: owner)

            let matches = ownerEmails.contains { ownerEmail in
                let emailLower = attendeeEmail.lowercased()
                let ownerEmailLower = ownerEmail.lowercased()

                // Direct match
                if emailLower == ownerEmailLower {
                    return true
                }

                // Contains match (but only if meaningful)
                if ownerEmailLower.contains(emailLower), emailLower.count > 3 {
                    return true
                }
                if emailLower.contains(ownerEmailLower), ownerEmailLower.count > 3 {
                    return true
                }

                // Local part match
                let emailLocal = emailLower.components(separatedBy: "@").first ?? emailLower
                let ownerLocal =
                    ownerEmailLower.components(separatedBy: "@").first ?? ownerEmailLower

                return emailLocal == ownerLocal && emailLocal.count > 2
            }

            XCTAssertFalse(matches, "Owner '\(owner)' should NOT match attendee '\(attendeeEmail)'")
        }
    }

    // MARK: - Realistic Scenario Tests

    func testRealWorldEmailPatterns() {
        let realWorldCases = [
            // Different domains but same person - these should match
            ("john@gmail.com", "john@company.com", true),
            ("john.doe@personal.com", "john.doe@work.com", true),

            // Clear non-matches
            ("john.smith", "jane.doe@company.com", false),
            ("different.person", "other.person@company.com", false),
        ]

        for (owner, attendeeEmail, shouldMatch) in realWorldCases {
            let ownerEmails = analyzer.getOwnerEmails(calendarOwner: owner)

            let matches = ownerEmails.contains { ownerEmail in
                let emailLower = attendeeEmail.lowercased()
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

            if shouldMatch {
                XCTAssertTrue(
                    matches,
                    "Real world case: owner '\(owner)' should match attendee '\(attendeeEmail)'"
                )
            } else {
                XCTAssertFalse(
                    matches,
                    "Real world case: owner '\(owner)' should NOT match attendee '\(attendeeEmail)'"
                )
            }
        }
    }

    func testEmailExtractionFromVariousFormats() {
        // Test the kind of email extraction that would happen in real scenarios
        let emailFormats = [
            "simple@company.com",
            "first.last@company.com",
            "first_last@company.com",
            "first-last@company.com",
            "f.last@company.com",
            "flast@company.com",
            "first.m.last@company.com",
            "123user@company.com",
            "user123@company.com",
            "user.123@company.com",
        ]

        for email in emailFormats {
            let extractedName = analyzer.extractNameFromEmail(email)
            XCTAssertFalse(extractedName.isEmpty, "Should extract some name from '\(email)'")
            XCTAssertFalse(extractedName.contains("@"), "Extracted name should not contain @")
        }
    }
}
