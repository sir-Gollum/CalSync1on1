import EventKit
import Foundation

struct SyncMetadata: Codable {
    let sourceEventId: String
}

class EventMetadata {
    private static let metadataKey = "[CalSync1on1-Metadata]"

    // Add sync metadata to an event's notes
    static func addSyncMetadata(_ event: EKEvent, SourceEventId: String) {
        let metadata = SyncMetadata(sourceEventId: SourceEventId)

        guard let jsonData = try? JSONEncoder().encode(metadata),
              let jsonString = String(data: jsonData, encoding: .utf8)
        else {
            Logger.error("Failed to encode sync metadata for event \(event)")
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
              let range = notes.range(of: metadataKey)
        else {
            return nil
        }

        let metadataStart = notes.index(range.upperBound, offsetBy: 1)
        let metadataText = String(notes[metadataStart...])

        let jsonString = metadataText.trimmingCharacters(
            in: .whitespacesAndNewlines)

        guard let jsonData = jsonString.data(using: .utf8),
              let metadata = try? JSONDecoder().decode(SyncMetadata.self, from: jsonData)
        else {
            Logger.error("Failed to decode sync metadata for event \(event)")
            return nil
        }

        return metadata
    }

    // Find a synced event by source ID in a calendar
    static func findSyncedEvent(sourceID: String, in calendar: EKCalendar, eventStore: EKEventStore)
        -> EKEvent?
    {
        // Get events from the past week to next month to ensure we find the event
        let startDate =
            Calendar.current.date(byAdding: .weekOfYear, value: -1, to: Date()) ?? Date()
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
              let range = notes.range(of: metadataKey)
        else {
            return
        }

        // Find the start of the metadata
        let metadataStart = range.lowerBound

        // Remove the metadata section
        let beforeMetadata = String(notes[..<metadataStart])

        let cleanedNotes = beforeMetadata.trimmingCharacters(
            in: .whitespacesAndNewlines)
        event.notes = cleanedNotes.isEmpty ? nil : cleanedNotes
    }

    // Check if an event was synced by this tool
    static func isSyncedEvent(_ event: EKEvent) -> Bool {
        getSyncMetadata(event) != nil
    }
}
