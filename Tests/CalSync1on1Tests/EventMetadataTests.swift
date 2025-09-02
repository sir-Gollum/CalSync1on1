import EventKit
import Foundation
import XCTest

@testable import CalSync1on1

final class EventMetadataTests: XCTestCase {

    // MARK: - Properties

    private var eventStore: EKEventStore!
    private var testEvent: EKEvent!

    // MARK: - Overridden Functions

    // MARK: - Setup & Teardown

    override func setUp() {
        super.setUp()
        eventStore = EKEventStore()
        testEvent = EKEvent(eventStore: eventStore)
        testEvent.title = "Test Meeting"
        testEvent.startDate = Date()
        testEvent.endDate = Date().addingTimeInterval(3600)
    }

    override func tearDown() {
        testEvent = nil
        eventStore = nil
        super.tearDown()
    }

    // MARK: - Functions

    // MARK: - Basic Functionality Tests

    func testSyncedEventDetection() {
        XCTAssertFalse(
            EventMetadata.isSyncedEvent(testEvent),
            "Fresh event should not be detected as synced"
        )

        EventMetadata.addSyncMetadata(testEvent, SourceEventId: "detection-test")

        XCTAssertTrue(
            EventMetadata.isSyncedEvent(testEvent),
            "Event with metadata should be detected as synced"
        )
    }

    func testMetadataWithExistingNotes() {
        let existingNotes = "These are existing notes."
        let sourceEventId = "notes-test-456"

        testEvent.notes = existingNotes
        EventMetadata.addSyncMetadata(testEvent, SourceEventId: sourceEventId)

        // Check that existing notes are preserved
        XCTAssertTrue(
            testEvent.notes?.contains(existingNotes) == true,
            "Existing notes should be preserved"
        )

        // Check that metadata is retrievable
        let metadata = EventMetadata.getSyncMetadata(testEvent)
        XCTAssertNotNil(metadata, "Metadata should be present")
        XCTAssertEqual(metadata?.sourceEventId, sourceEventId, "Source ID should match")
    }

    func testDuplicateMetadataPrevention() {
        let sourceEventId = "duplicate-test"

        // Add metadata twice
        EventMetadata.addSyncMetadata(testEvent, SourceEventId: sourceEventId)
        let notesAfterFirst = testEvent.notes

        EventMetadata.addSyncMetadata(testEvent, SourceEventId: sourceEventId)
        let notesAfterSecond = testEvent.notes

        XCTAssertEqual(
            notesAfterFirst,
            notesAfterSecond,
            "Adding metadata twice should not duplicate it"
        )

        // Verify metadata is still correct
        let metadata = EventMetadata.getSyncMetadata(testEvent)
        XCTAssertEqual(metadata?.sourceEventId, sourceEventId, "Metadata should remain correct")
    }

    func testMetadataRemoval() {
        let sourceEventId = "removal-test"

        // Add metadata
        EventMetadata.addSyncMetadata(testEvent, SourceEventId: sourceEventId)
        XCTAssertTrue(EventMetadata.isSyncedEvent(testEvent), "Event should be synced")

        // Remove metadata
        EventMetadata.removeSyncMetadata(testEvent)

        // Verify removal
        XCTAssertFalse(
            EventMetadata.isSyncedEvent(testEvent),
            "Event should not be synced after removal"
        )
        XCTAssertNil(
            EventMetadata.getSyncMetadata(testEvent),
            "Metadata should be nil after removal"
        )
    }

    func testNotesPreservationAfterMetadataOperations() {
        let originalNotes = "Important meeting notes."
        let sourceEventId = "preservation-test"

        testEvent.notes = originalNotes
        EventMetadata.addSyncMetadata(testEvent, SourceEventId: sourceEventId)
        EventMetadata.removeSyncMetadata(testEvent)

        XCTAssertEqual(
            testEvent.notes?.trimmingCharacters(in: .whitespacesAndNewlines),
            originalNotes,
            "Original notes should be preserved after metadata removal"
        )
    }

    func testEmptyNotesHandling() {
        testEvent.notes = nil
        XCTAssertNil(
            EventMetadata.getSyncMetadata(testEvent),
            "Should return nil for nil notes"
        )

        testEvent.notes = ""
        XCTAssertNil(
            EventMetadata.getSyncMetadata(testEvent),
            "Should return nil for empty notes"
        )
    }

    func testMissingMetadataKey() {
        testEvent.notes = "Some regular notes without metadata"

        let metadata = EventMetadata.getSyncMetadata(testEvent)
        XCTAssertNil(metadata, "Should return nil when metadata key is missing")
    }

    func testMetadataWithVariousIds() {
        let testIds = [
            "simple-id",
            "complex.id_with-special@chars",
            "unicode-åäö",
            "123-numeric-start",
            "",
        ]

        for sourceEventId in testIds {
            let event = EKEvent(eventStore: eventStore)
            event.title = "Test Event"

            EventMetadata.addSyncMetadata(event, SourceEventId: sourceEventId)
            let retrievedMetadata = EventMetadata.getSyncMetadata(event)

            XCTAssertNotNil(
                retrievedMetadata,
                "Metadata should be retrievable for ID: '\(sourceEventId)'"
            )
            XCTAssertEqual(
                retrievedMetadata?.sourceEventId,
                sourceEventId,
                "Source ID should match for: '\(sourceEventId)'"
            )
            XCTAssertTrue(
                EventMetadata.isSyncedEvent(event),
                "Should detect as synced for ID: '\(sourceEventId)'"
            )
        }
    }

    func testFindSyncedEventWithMultiple() {
        let targetId = "target-event"
        let events = createTestEvents(count: 3)

        // Add different metadata to events
        EventMetadata.addSyncMetadata(events[0], SourceEventId: "event-1")
        EventMetadata.addSyncMetadata(events[2], SourceEventId: targetId)

        let foundEvent = events.first { event in
            guard let metadata = EventMetadata.getSyncMetadata(event) else { return false }
            return metadata.sourceEventId == targetId
        }

        XCTAssertNotNil(foundEvent, "Should find correct event among multiple synced events")
        XCTAssertEqual(foundEvent?.title, events[2].title, "Should find event with matching ID")
    }

    // MARK: - Helper Methods

    private func createTestEvents(count: Int) -> [EKEvent] {
        var events: [EKEvent] = []

        for i in 0 ..< count {
            let event = EKEvent(eventStore: eventStore)
            event.title = "Test Event \(i + 1)"
            event.startDate = Date().addingTimeInterval(TimeInterval(i * 3600))
            event.endDate = event.startDate.addingTimeInterval(1800)
            events.append(event)
        }

        return events
    }
}

// MARK: - SyncMetadata Tests

final class SyncMetadataTests: XCTestCase {

    func testSyncMetadataCodableCompliance() {
        let sourceEventId = "codable-test"
        let originalMetadata = SyncMetadata(sourceEventId: sourceEventId)

        // Test encoding
        guard let encodedData = try? JSONEncoder().encode(originalMetadata),
              let jsonString = String(data: encodedData, encoding: .utf8)
        else {
            XCTFail("Should encode SyncMetadata")
            return
        }

        XCTAssertTrue(jsonString.contains("sourceEventId"), "JSON should contain key")
        XCTAssertTrue(jsonString.contains(sourceEventId), "JSON should contain value")

        // Test decoding
        guard
            let decodedMetadata = try? JSONDecoder().decode(
                SyncMetadata.self, from: encodedData
            )
        else {
            XCTFail("Should decode SyncMetadata")
            return
        }

        XCTAssertEqual(
            decodedMetadata.sourceEventId,
            originalMetadata.sourceEventId,
            "Decoded metadata should match original"
        )
    }

    func testSyncMetadataWithSpecialCharacters() {
        let specialIds = [
            "special@chars#test",
            "unicode-åäö",
            "quotes\"test",
            "spaces test",
        ]

        for specialId in specialIds {
            let metadata = SyncMetadata(sourceEventId: specialId)

            guard let encodedData = try? JSONEncoder().encode(metadata),
                  let decodedMetadata = try? JSONDecoder().decode(
                      SyncMetadata.self, from: encodedData
                  )
            else {
                XCTFail("Should handle special characters: '\(specialId)'")
                continue
            }

            XCTAssertEqual(
                decodedMetadata.sourceEventId,
                specialId,
                "Should preserve special characters: '\(specialId)'"
            )
        }
    }
}
