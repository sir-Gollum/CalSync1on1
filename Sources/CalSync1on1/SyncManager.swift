import EventKit
import Foundation

class SyncManager {

    // MARK: - Nested Types

    struct SyncResult {
        var created: Int
        var updated: Int
        var deleted: Int
        var skipped: Int
        var errors: [String]
    }

    private enum SyncAction {
        case created
        case updated
        case skipped
        case error(String)
    }

    // MARK: - Properties

    private let calendarManager = CalendarManager()
    private let configuration: Configuration
    private let dryRun: Bool

    // MARK: - Computed Properties

    private var calendarPair: Configuration.CalendarPair {
        configuration.calendarPair
    }

    // MARK: - Lifecycle

    init(configuration: Configuration, dryRun: Bool = false) {
        self.configuration = configuration
        self.dryRun = dryRun
    }

    // MARK: - Functions

    func syncEvents(
        _ sourceEvents: [EKEvent],
        from sourceCalendar: EKCalendar,
        to destCalendar: EKCalendar,
        analyzer: MeetingAnalyzer,
        calendarOwner: String
    )
        -> SyncResult {
        var result = SyncResult(created: 0, updated: 0, deleted: 0, skipped: 0, errors: [])

        Logger.info(dryRun ? "🔍 DRY RUN MODE - No changes will be made" : "🔄 Starting sync...")

        // Progress tracking
        let totalEvents = sourceEvents.count
        var processedEvents = 0

        for event in sourceEvents {
            processedEvents += 1

            // Show progress for large operations
            if totalEvents > 10,
               processedEvents % max(1, totalEvents / 10) == 0 || processedEvents == totalEvents {
                let percentage = (processedEvents * 100) / totalEvents
                Logger.info(
                    "📊 Progress: \(processedEvents)/\(totalEvents) events processed (\(percentage)%)"
                )
            }
            if analyzer.isOneOnOneMeeting(event, calendarOwner: calendarOwner) {
                let otherPersonName = analyzer.getOtherPersonName(
                    from: event, calendarOwner: calendarOwner
                )

                switch syncEvent(
                    event,
                    to: destCalendar,
                    sourceCalendar: sourceCalendar,
                    otherPersonName: otherPersonName
                ) {
                case .created:
                    result.created += 1
                case .updated:
                    result.updated += 1
                case .skipped:
                    result.skipped += 1
                case let .error(message):
                    result.errors.append(message)
                }
            } else {
                // Count non-1:1 events (including all-day events) as skipped
                result.skipped += 1
            }
        }

        // Clean up orphaned events (events that were synced but source no longer exists or is not 1:1)
        let cleanupResult = cleanupOrphanedEvents(
            in: destCalendar,
            validSourceEvents: sourceEvents,
            analyzer: analyzer,
            sourceCalendar: sourceCalendar,
            calendarOwner: calendarOwner
        )
        result.deleted += cleanupResult

        return result
    }

    // Print detailed sync summary
    func printSummary(_ result: SyncResult) {
        Logger.info("\n\t" + "=" * 50)
        Logger.info(dryRun ? "🔍 DRY RUN SUMMARY" : "📊 SYNC SUMMARY")
        Logger.info("=" * 50)

        if dryRun {
            Logger.info("📋 Changes that would be made:")
        } else {
            Logger.info("📋 Changes made:")
        }

        Logger.info("  ➕ Created: \(result.created)")
        Logger.info("  📝 Updated: \(result.updated)")
        Logger.info("  🗑️  Deleted: \(result.deleted)")
        Logger.info("  ⏭️  Skipped: \(result.skipped)")

        if !result.errors.isEmpty {
            Logger.error("  ❌ Errors: \(result.errors.count)")
            for error in result.errors {
                Logger.error("     • \(error)")
            }
        }

        let totalProcessed = result.created + result.updated + result.deleted + result.skipped
        Logger.info("\n\t📈 Total events processed: \(totalProcessed)")

        Logger.info("=" * 50)
    }

    private func syncEvent(
        _ sourceEvent: EKEvent,
        to destCalendar: EKCalendar,
        sourceCalendar: EKCalendar,
        otherPersonName: String
    )
        -> SyncAction {
        let titleTemplate = calendarPair.titleTemplate
        let syncedTitle = titleTemplate.replacingOccurrences(
            of: "{{otherPerson}}",
            with: otherPersonName
        )

        // Handle recurring events
        if sourceEvent.hasRecurrenceRules {
            return syncRecurringEvent(
                sourceEvent,
                to: destCalendar,
                sourceCalendar: sourceCalendar,
                otherPersonName: otherPersonName,
                syncedTitle: syncedTitle
            )
        }

        // Handle single events
        return syncSingleEvent(
            sourceEvent,
            to: destCalendar,
            sourceCalendar: sourceCalendar,
            otherPersonName: otherPersonName,
            syncedTitle: syncedTitle
        )
    }

    private func syncSingleEvent(
        _ sourceEvent: EKEvent,
        to destCalendar: EKCalendar,
        sourceCalendar: EKCalendar,
        otherPersonName: String,
        syncedTitle: String
    )
        -> SyncAction {
        // Check if event has an identifier (required for sync tracking)
        guard let sourceEventId = sourceEvent.eventIdentifier else {
            Logger.info(
                "Event '\(sourceEvent.title ?? "Untitled")' has no identifier, creating new synced event"
            )
            return createNewSyncedEvent(
                from: sourceEvent,
                title: syncedTitle,
                in: destCalendar,
                otherPersonName: otherPersonName,
                sourceCalendar: sourceCalendar
            ) ? .created : .error("Failed to create synced event")
        }

        // Check if this event already has a synced counterpart
        if let existingEvent = EventMetadata.findSyncedEvent(
            sourceID: sourceEventId,
            in: destCalendar,
            eventStore: calendarManager.eventStore
        ) {
            // Check if the existing event needs updating
            if eventNeedsUpdate(
                existingEvent,
                sourceEvent: sourceEvent,
                expectedTitle: syncedTitle
            ) {
                if dryRun {
                    Logger.info(
                        "📝 Would update: '\(syncedTitle)' at \(DateHelper.formatDate(sourceEvent.startDate))"
                    )
                    return .updated
                } else {
                    if updateExistingEvent(
                        existingEvent,
                        from: sourceEvent,
                        title: syncedTitle,
                        otherPersonName: otherPersonName,
                        sourceCalendar: sourceCalendar
                    ) {
                        Logger.info(
                            "📝 Updated: '\(syncedTitle)' at \(DateHelper.formatDate(sourceEvent.startDate))"
                        )
                        return .updated
                    } else {
                        return .error("Failed to update event: \(syncedTitle)")
                    }
                }
            } else {
                if configuration.logging.level == "debug" {
                    Logger.info("⏭️  Skipped: '\(syncedTitle)' (up to date)")
                }
                return .skipped
            }
        } else {
            // Create new synced event
            if dryRun {
                Logger.info(
                    "➕ Would create: '\(syncedTitle)' at \(DateHelper.formatDate(sourceEvent.startDate))"
                )
                return .created
            } else {
                if createNewSyncedEvent(
                    from: sourceEvent,
                    title: syncedTitle,
                    in: destCalendar,
                    otherPersonName: otherPersonName,
                    sourceCalendar: sourceCalendar
                ) {
                    Logger.info(
                        "✅ Created: '\(syncedTitle)' at \(DateHelper.formatDate(sourceEvent.startDate))"
                    )
                    return .created
                } else {
                    return .error("Failed to create event: \(syncedTitle)")
                }
            }
        }
    }

    private func syncRecurringEvent(
        _ sourceEvent: EKEvent,
        to destCalendar: EKCalendar,
        sourceCalendar: EKCalendar,
        otherPersonName: String,
        syncedTitle: String
    )
        -> SyncAction {
        // Check if event has an identifier (required for sync tracking)
        guard let sourceEventId = sourceEvent.eventIdentifier else {
            Logger.info(
                "Recurring event '\(sourceEvent.title ?? "Untitled")' has no identifier, creating new synced event"
            )
            return createNewRecurringEvent(
                from: sourceEvent,
                title: syncedTitle,
                in: destCalendar,
                otherPersonName: otherPersonName,
                sourceCalendar: sourceCalendar
            ) ? .created : .error("Failed to create recurring synced event")
        }

        // For recurring events, we sync the entire series
        if let existingEvent = EventMetadata.findSyncedEvent(
            sourceID: sourceEventId,
            in: destCalendar,
            eventStore: calendarManager.eventStore
        ) {
            // Check if the recurring series needs updating
            if eventNeedsUpdate(
                existingEvent,
                sourceEvent: sourceEvent,
                expectedTitle: syncedTitle
            ) {
                if dryRun {
                    Logger.info(
                        "📝 Would update recurring series: '\(syncedTitle)' "
                            + "starting \(DateHelper.formatDate(sourceEvent.startDate))"
                    )
                    return .updated
                } else {
                    if updateRecurringEvent(
                        existingEvent,
                        from: sourceEvent,
                        title: syncedTitle,
                        otherPersonName: otherPersonName,
                        sourceCalendar: sourceCalendar
                    ) {
                        Logger.info(
                            "📝 Updated recurring series: '\(syncedTitle)' "
                                + "starting \(DateHelper.formatDate(sourceEvent.startDate))"
                        )
                        return .updated
                    } else {
                        return .error("Failed to update recurring series: \(syncedTitle)")
                    }
                }
            } else {
                if configuration.logging.level == "debug" {
                    Logger.info("⏭️  Skipped recurring series: '\(syncedTitle)' (up to date)")
                }
                return .skipped
            }
        } else {
            // Create new recurring synced event
            if dryRun {
                Logger.info(
                    "➕ Would create recurring series: '\(syncedTitle)' "
                        + "starting \(DateHelper.formatDate(sourceEvent.startDate))"
                )
                return .created
            } else {
                if createNewRecurringEvent(
                    from: sourceEvent,
                    title: syncedTitle,
                    in: destCalendar,
                    otherPersonName: otherPersonName,
                    sourceCalendar: sourceCalendar
                ) {
                    Logger.info(
                        "✅ Created recurring series: '\(syncedTitle)' "
                            + "starting \(DateHelper.formatDate(sourceEvent.startDate))"
                    )
                    return .created
                } else {
                    return .error("Failed to create recurring series: \(syncedTitle)")
                }
            }
        }
    }

    private func eventNeedsUpdate(
        _ existingEvent: EKEvent,
        sourceEvent: EKEvent,
        expectedTitle: String
    )
        -> Bool {
        // Check if title matches expected format
        if existingEvent.title != expectedTitle {
            return true
        }

        // Check if times have changed
        if existingEvent.startDate != sourceEvent.startDate
            || existingEvent.endDate != sourceEvent.endDate {
            return true
        }

        return false
    }

    private func createNewSyncedEvent(
        from sourceEvent: EKEvent,
        title: String,
        in calendar: EKCalendar,
        otherPersonName _: String,
        sourceCalendar _: EKCalendar
    )
        -> Bool {
        let event = EKEvent(eventStore: calendarManager.eventStore)
        event.title = title
        event.startDate = sourceEvent.startDate
        event.endDate = sourceEvent.endDate
        event.calendar = calendar

        // Add sync metadata
        if let sourceEventId = sourceEvent.eventIdentifier {
            EventMetadata.addSyncMetadata(
                event,
                SourceEventId: sourceEventId
            )
        }

        do {
            try calendarManager.eventStore.save(event, span: .thisEvent)
            return true
        } catch {
            Logger.error("Error creating event: \(error.localizedDescription)")
            return false
        }
    }

    private func createNewRecurringEvent(
        from sourceEvent: EKEvent,
        title: String,
        in calendar: EKCalendar,
        otherPersonName _: String,
        sourceCalendar _: EKCalendar
    )
        -> Bool {
        let event = EKEvent(eventStore: calendarManager.eventStore)
        event.title = title
        event.startDate = sourceEvent.startDate
        event.endDate = sourceEvent.endDate
        event.calendar = calendar

        // Copy recurrence rules from source event
        if let recurrenceRules = sourceEvent.recurrenceRules {
            event.recurrenceRules = recurrenceRules
        }

        // Add sync metadata
        if let sourceEventId = sourceEvent.eventIdentifier {
            EventMetadata.addSyncMetadata(
                event,
                SourceEventId: sourceEventId
            )
        }

        do {
            try calendarManager.eventStore.save(event, span: .futureEvents)
            return true
        } catch {
            Logger.error("Error creating recurring event: \(error.localizedDescription)")
            return false
        }
    }

    private func updateRecurringEvent(
        _ existingEvent: EKEvent,
        from sourceEvent: EKEvent,
        title: String,
        otherPersonName _: String,
        sourceCalendar _: EKCalendar
    )
        -> Bool {
        existingEvent.title = title
        existingEvent.startDate = sourceEvent.startDate
        existingEvent.endDate = sourceEvent.endDate

        // Update recurrence rules
        if let recurrenceRules = sourceEvent.recurrenceRules {
            existingEvent.recurrenceRules = recurrenceRules
        }

        // Update sync metadata
        if let sourceEventId = sourceEvent.eventIdentifier {
            EventMetadata.addSyncMetadata(
                existingEvent,
                SourceEventId: sourceEventId
            )
        }

        do {
            try calendarManager.eventStore.save(existingEvent, span: .futureEvents)
            return true
        } catch {
            Logger.error("Error updating recurring event: \(error.localizedDescription)")
            return false
        }
    }

    private func updateExistingEvent(
        _ existingEvent: EKEvent,
        from sourceEvent: EKEvent,
        title: String,
        otherPersonName _: String,
        sourceCalendar _: EKCalendar
    )
        -> Bool {
        existingEvent.title = title
        existingEvent.startDate = sourceEvent.startDate
        existingEvent.endDate = sourceEvent.endDate

        // Update sync metadata
        if let sourceEventId = sourceEvent.eventIdentifier {
            EventMetadata.addSyncMetadata(
                existingEvent,
                SourceEventId: sourceEventId
            )
        }

        do {
            try calendarManager.eventStore.save(existingEvent, span: .thisEvent)
            return true
        } catch {
            Logger.error("Error updating event: \(error.localizedDescription)")
            return false
        }
    }

    private func cleanupOrphanedEvents(
        in calendar: EKCalendar,
        validSourceEvents: [EKEvent],
        analyzer: MeetingAnalyzer,
        sourceCalendar _: EKCalendar,
        calendarOwner: String
    )
        -> Int {
        let validSourceEventIds = Set(
            validSourceEvents.compactMap { event in
                analyzer.isOneOnOneMeeting(event, calendarOwner: calendarOwner)
                    ? event.eventIdentifier : nil
            }
        )

        // Get all synced events in the destination calendar
        let startDate =
            Calendar.current.date(byAdding: .weekOfYear, value: -1, to: Date()) ?? Date()
        let endDate = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()

        let predicate = calendarManager.eventStore.predicateForEvents(
            withStart: startDate,
            end: endDate,
            calendars: [calendar]
        )

        let events = calendarManager.eventStore.events(matching: predicate)
        let syncedEvents = events.filter { EventMetadata.isSyncedEvent($0) }

        var deletedCount = 0

        for syncedEvent in syncedEvents {
            guard let metadata = EventMetadata.getSyncMetadata(syncedEvent) else { continue }

            if !validSourceEventIds.contains(metadata.sourceEventId) {
                if dryRun {
                    Logger.info(
                        "🗑️  Would delete orphaned: '\(syncedEvent.title ?? "Untitled")'"
                            + " starting \(DateHelper.formatDate(syncedEvent.startDate))"
                    )
                } else {
                    do {
                        let span: EKSpan =
                            syncedEvent.hasRecurrenceRules ? .futureEvents : .thisEvent
                        try calendarManager.eventStore.remove(syncedEvent, span: span)
                        Logger.info(
                            "🗑️  Deleted orphaned\(syncedEvent.hasRecurrenceRules ? " recurring series" : ""): '\(syncedEvent.title ?? "Untitled")'"
                                + " starting \(DateHelper.formatDate(syncedEvent.startDate))"
                        )
                        deletedCount += 1
                    } catch {
                        Logger.error("Error deleting orphaned event: \(error.localizedDescription)")
                    }
                }
            }
        }

        return deletedCount
    }

}

// Helper extension for string repetition
extension String {
    static func * (left: String, right: Int) -> String {
        String(repeating: left, count: right)
    }
}
