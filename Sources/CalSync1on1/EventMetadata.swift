import Foundation
import EventKit

struct SyncMetadata: Codable {
    let sourceEventId: String
    let sourceCalendar: String
    let syncVersion: String
    var lastSyncDate: Date
    let otherPersonName: String

    static let currentVersion = "1.0"
}

class EventMetadata {
    private static let metadataKey = "[CalSync1on1-Metadata]"

    // Add sync metadata to an event's notes
    static func addSyncMetadata(_ event: EKEvent, sourceID: String, sourceCalendar: String, otherPersonName: String) {
        let metadata = SyncMetadata(
            sourceEventId: sourceID,
            sourceCalendar: sourceCalendar,
            syncVersion: SyncMetadata.currentVersion,
            lastSyncDate: Date(),
            otherPersonName: otherPersonName
        )

        guard let jsonData = try? JSONEncoder().encode(metadata),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            print("Warning: Failed to encode sync metadata")
            return
        }

        let metadataString = "\(metadataKey) \(jsonString)"

        // Append to existing notes or create new notes
        if let existingNotes = event.notes, !existingNotes.isEmpty {
            if !existingNotes.contains(metadataKey) {
                event.notes = "\(existingNotes)\n\n\(metadataString)"
            }
        } else {
            event.notes = metadataString
        }
    }

    // Get sync metadata from an event
    static func getSyncMetadata(_ event: EKEvent) -> SyncMetadata? {
        guard let notes = event.notes,
              let range = notes.range(of: metadataKey) else {
            return nil
        }

        let metadataStart = notes.index(range.upperBound, offsetBy: 1)
        let remainingText = String(notes[metadataStart...])

        // Find the end of the JSON (either end of string or double newline)
        let jsonEnd = remainingText.firstIndex { $0 == "\n" } ?? remainingText.endIndex
        let jsonString = String(remainingText[..<jsonEnd]).trimmingCharacters(in: .whitespacesAndNewlines)

        guard let jsonData = jsonString.data(using: .utf8),
              let metadata = try? JSONDecoder().decode(SyncMetadata.self, from: jsonData) else {
            return nil
        }

        return metadata
    }

    // Find a synced event by source ID in a calendar
    static func findSyncedEvent(sourceID: String, in calendar: EKCalendar, eventStore: EKEventStore) -> EKEvent? {
        // Get events from the past week to next month to ensure we find the event
        let startDate = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: Date()) ?? Date()
        let endDate = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()

        let predicate = eventStore.predicateForEvents(
            withStart: startDate,
            end: endDate,
            calendars: [calendar]
        )

        let events = eventStore.events(matching: predicate)

        return events.first { event in
            guard let metadata = getSyncMetadata(event) else { return false }
            return metadata.sourceEventId == sourceID
        }
    }

    // Remove sync metadata from an event
    static func removeSyncMetadata(_ event: EKEvent) {
        guard let notes = event.notes,
              let range = notes.range(of: metadataKey) else {
            return
        }

        // Find the start of the metadata
        let metadataStart = range.lowerBound

        // Find the end of the metadata (double newline or end of string)
        let searchStart = notes.index(range.upperBound, offsetBy: 1)
        let remainingText = String(notes[searchStart...])

        let metadataEndOffset: String.Index
        if let doubleNewlineRange = remainingText.range(of: "\n\n") {
            metadataEndOffset = notes.index(searchStart, offsetBy: remainingText.distance(from: remainingText.startIndex, to: doubleNewlineRange.upperBound))
        } else {
            metadataEndOffset = notes.endIndex
        }

        // Remove the metadata section
        let beforeMetadata = String(notes[..<metadataStart])
        let afterMetadata = String(notes[metadataEndOffset...])

        let cleanedNotes = (beforeMetadata + afterMetadata).trimmingCharacters(in: .whitespacesAndNewlines)
        event.notes = cleanedNotes.isEmpty ? nil : cleanedNotes
    }

    // Check if an event was synced by this tool
    static func isSyncedEvent(_ event: EKEvent) -> Bool {
        return getSyncMetadata(event) != nil
    }

    // Update the last sync date for an event
    static func updateLastSyncDate(_ event: EKEvent) {
        guard var metadata = getSyncMetadata(event) else { return }

        // Remove old metadata and add updated metadata
        removeSyncMetadata(event)
        metadata.lastSyncDate = Date()

        guard let jsonData = try? JSONEncoder().encode(metadata),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            print("Warning: Failed to update sync metadata")
            return
        }

        let metadataString = "\(metadataKey) \(jsonString)"

        // Append to existing notes or create new notes
        if let existingNotes = event.notes, !existingNotes.isEmpty {
            event.notes = "\(existingNotes)\n\n\(metadataString)"
        } else {
            event.notes = metadataString
        }
    }
}
