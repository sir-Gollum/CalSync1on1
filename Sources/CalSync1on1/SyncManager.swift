import EventKit
import Foundation

class SyncManager {
    private let calendarManager = CalendarManager()
    private let configuration: Configuration
    private let dryRun: Bool

    init(configuration: Configuration, dryRun: Bool = false) {
        self.configuration = configuration
        self.dryRun = dryRun
    }

    private var calendarPair: Configuration.CalendarPair {
        configuration.calendarPair
    }

    private enum SyncAction {
        case created
        case updated
        case skipped
        case error(String)
    }

    struct SyncResult {
        var created: Int
        var updated: Int
        var deleted: Int
        var skipped: Int
        var errors: [String]
    }

    func syncEvents(
        _ sourceEvents: [EKEvent],
        from sourceCalendar: EKCalendar,
        to destCalendar: EKCalendar,
        analyzer: MeetingAnalyzer,
        calendarOwner: String
    ) -> SyncResult {
        var result = SyncResult(created: 0, updated: 0, deleted: 0, skipped: 0, errors: [])

        print(dryRun ? "🔍 DRY RUN MODE - No changes will be made" : "🔄 Starting sync...")

        // Progress tracking
        let totalEvents = sourceEvents.count
        var processedEvents = 0

        for event in sourceEvents {
            processedEvents += 1

            // Show progress for large operations
            if totalEvents > 10,
               processedEvents % max(1, totalEvents / 10) == 0 || processedEvents == totalEvents
            {
                let percentage = (processedEvents * 100) / totalEvents
                print(
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

    private func syncEvent(
        _ sourceEvent: EKEvent,
        to destCalendar: EKCalendar,
        sourceCalendar: EKCalendar,
        otherPersonName: String
    ) -> SyncAction {
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
    ) -> SyncAction {
        // Check if this event already has a synced counterpart
        if let existingEvent = EventMetadata.findSyncedEvent(
            sourceID: sourceEvent.eventIdentifier,
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
                    print(
                        "📝 Would update: '\(syncedTitle)' at \(DateHelper.formatDate(sourceEvent.startDate))")
                    return .updated
                } else {
                    if updateExistingEvent(
                        existingEvent,
                        from: sourceEvent,
                        title: syncedTitle,
                        otherPersonName: otherPersonName,
                        sourceCalendar: sourceCalendar
                    ) {
                        print("📝 Updated: '\(syncedTitle)' at \(DateHelper.formatDate(sourceEvent.startDate))")
                        return .updated
                    } else {
                        return .error("Failed to update event: \(syncedTitle)")
                    }
                }
            } else {
                if configuration.logging.level == "debug" {
                    print("⏭️  Skipped: '\(syncedTitle)' (up to date)")
                }
                return .skipped
            }
        } else {
            // Create new synced event
            if dryRun {
                print("➕ Would create: '\(syncedTitle)' at \(DateHelper.formatDate(sourceEvent.startDate))")
                return .created
            } else {
                if createNewSyncedEvent(
                    from: sourceEvent,
                    title: syncedTitle,
                    in: destCalendar,
                    otherPersonName: otherPersonName,
                    sourceCalendar: sourceCalendar
                ) {
                    print("✅ Created: '\(syncedTitle)' at \(DateHelper.formatDate(sourceEvent.startDate))")
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
    ) -> SyncAction {
        // For recurring events, we sync the entire series
        if let existingEvent = EventMetadata.findSyncedEvent(
            sourceID: sourceEvent.eventIdentifier,
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
                    print(
                        "📝 Would update recurring series: '\(syncedTitle)' "
                            + "starting \(DateHelper.formatDate(sourceEvent.startDate))")
                    return .updated
                } else {
                    if updateRecurringEvent(
                        existingEvent,
                        from: sourceEvent,
                        title: syncedTitle,
                        otherPersonName: otherPersonName,
                        sourceCalendar: sourceCalendar
                    ) {
                        print(
                            "📝 Updated recurring series: '\(syncedTitle)' "
                                + "starting \(DateHelper.formatDate(sourceEvent.startDate))")
                        return .updated
                    } else {
                        return .error("Failed to update recurring series: \(syncedTitle)")
                    }
                }
            } else {
                if configuration.logging.level == "debug" {
                    print("⏭️  Skipped recurring series: '\(syncedTitle)' (up to date)")
                }
                return .skipped
            }
        } else {
            // Create new recurring synced event
            if dryRun {
                print(
                    "➕ Would create recurring series: '\(syncedTitle)' "
                        + "starting \(DateHelper.formatDate(sourceEvent.startDate))")
                return .created
            } else {
                if createNewRecurringEvent(
                    from: sourceEvent,
                    title: syncedTitle,
                    in: destCalendar,
                    otherPersonName: otherPersonName,
                    sourceCalendar: sourceCalendar
                ) {
                    print(
                        "✅ Created recurring series: '\(syncedTitle)' "
                            + "starting \(DateHelper.formatDate(sourceEvent.startDate))")
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
    ) -> Bool {
        // Check if title matches expected format
        if existingEvent.title != expectedTitle {
            return true
        }

        // Check if times have changed
        if existingEvent.startDate != sourceEvent.startDate
            || existingEvent.endDate != sourceEvent.endDate
        {
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
    ) -> Bool {
        let event = EKEvent(eventStore: calendarManager.eventStore)
        event.title = title
        event.startDate = sourceEvent.startDate
        event.endDate = sourceEvent.endDate
        event.calendar = calendar

        // Add sync metadata
        EventMetadata.addSyncMetadata(
            event,
            SourceEventId: sourceEvent.eventIdentifier
        )

        do {
            try calendarManager.eventStore.save(event, span: .thisEvent)
            return true
        } catch {
            print("Error creating event: \(error.localizedDescription)")
            return false
        }
    }

    private func createNewRecurringEvent(
        from sourceEvent: EKEvent,
        title: String,
        in calendar: EKCalendar,
        otherPersonName _: String,
        sourceCalendar _: EKCalendar
    ) -> Bool {
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
        EventMetadata.addSyncMetadata(
            event,
            SourceEventId: sourceEvent.eventIdentifier
        )

        do {
            try calendarManager.eventStore.save(event, span: .futureEvents)
            return true
        } catch {
            print("Error creating recurring event: \(error.localizedDescription)")
            return false
        }
    }

    private func updateRecurringEvent(
        _ existingEvent: EKEvent,
        from sourceEvent: EKEvent,
        title: String,
        otherPersonName _: String,
        sourceCalendar _: EKCalendar
    ) -> Bool {
        existingEvent.title = title
        existingEvent.startDate = sourceEvent.startDate
        existingEvent.endDate = sourceEvent.endDate

        // Update recurrence rules
        if let recurrenceRules = sourceEvent.recurrenceRules {
            existingEvent.recurrenceRules = recurrenceRules
        }

        // Update sync metadata
        EventMetadata.addSyncMetadata(
            existingEvent,
            SourceEventId: sourceEvent.eventIdentifier
        )

        do {
            try calendarManager.eventStore.save(existingEvent, span: .futureEvents)
            return true
        } catch {
            print("Error updating recurring event: \(error.localizedDescription)")
            return false
        }
    }

    private func updateExistingEvent(
        _ existingEvent: EKEvent,
        from sourceEvent: EKEvent,
        title: String,
        otherPersonName _: String,
        sourceCalendar _: EKCalendar
    ) -> Bool {
        existingEvent.title = title
        existingEvent.startDate = sourceEvent.startDate
        existingEvent.endDate = sourceEvent.endDate

        // Update sync metadata
        EventMetadata.addSyncMetadata(
            existingEvent,
            SourceEventId: sourceEvent.eventIdentifier
        )

        do {
            try calendarManager.eventStore.save(existingEvent, span: .thisEvent)
            return true
        } catch {
            print("Error updating event: \(error.localizedDescription)")
            return false
        }
    }

    private func cleanupOrphanedEvents(
        in calendar: EKCalendar,
        validSourceEvents: [EKEvent],
        analyzer: MeetingAnalyzer,
        sourceCalendar _: EKCalendar,
        calendarOwner: String
    ) -> Int {
        let validSourceEventIds = Set(
            validSourceEvents.compactMap { event in
                analyzer.isOneOnOneMeeting(event, calendarOwner: calendarOwner)
                    ? event.eventIdentifier : nil
            })

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
                    print("🗑️  Would delete orphaned: '\(syncedEvent.title ?? "Untitled")'")
                } else {
                    do {
                        try calendarManager.eventStore.remove(syncedEvent, span: .thisEvent)
                        print("🗑️  Deleted orphaned: '\(syncedEvent.title ?? "Untitled")'")
                        deletedCount += 1
                    } catch {
                        print("Error deleting orphaned event: \(error.localizedDescription)")
                    }
                }
            }
        }

        return deletedCount
    }

    // Print detailed sync summary
    func printSummary(_ result: SyncResult) {
        print("\n" + "=" * 50)
        print(dryRun ? "🔍 DRY RUN SUMMARY" : "📊 SYNC SUMMARY")
        print("=" * 50)

        if dryRun {
            print("📋 Changes that would be made:")
        } else {
            print("📋 Changes made:")
        }

        print("  ➕ Created: \(result.created)")
        print("  📝 Updated: \(result.updated)")
        print("  🗑️  Deleted: \(result.deleted)")
        print("  ⏭️  Skipped: \(result.skipped)")

        if !result.errors.isEmpty {
            print("  ❌ Errors: \(result.errors.count)")
            for error in result.errors {
                print("     • \(error)")
            }
        }

        let totalProcessed = result.created + result.updated + result.deleted + result.skipped
        print("\n📈 Total events processed: \(totalProcessed)")

        if dryRun {
            print("\n💡 Run without --dry-run to apply these changes")
        }

        print("=" * 50)
    }
}

// Helper extension for string repetition
extension String {
    static func * (left: String, right: Int) -> String {
        String(repeating: left, count: right)
    }
}
