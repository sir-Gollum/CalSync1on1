import EventKit
import Foundation

enum EventFilter {
    static func applyFilters(
        _ events: [EKEvent],
        configuration: Configuration,
        logger: Logger
    ) -> [EKEvent] {
        events.filter { event in
            let (passes, reasons) = checkFilters(event, configuration: configuration)

            if !passes {
                logger.debug(
                    "   ⏭️ Skipping '\(event.title ?? "Untitled")': \(reasons.joined(separator: ", "))"
                )
            }

            return passes
        }
    }

    static func checkFilters(
        _ event: EKEvent,
        configuration: Configuration
    ) -> (passes: Bool, reasons: [String]) {
        var reasons: [String] = []

        // All-day filter
        if configuration.filters.excludeAllDay, event.isAllDay {
            reasons.append("All-day event excluded")
        }

        // Keyword filters
        if let title = event.title?.lowercased() {
            for keyword in configuration.filters.excludeKeywords
                where title.contains(keyword.lowercased())
            {
                reasons.append("Contains excluded keyword '\(keyword)'")
            }
        }

        return (passes: reasons.isEmpty, reasons: reasons)
    }
}
