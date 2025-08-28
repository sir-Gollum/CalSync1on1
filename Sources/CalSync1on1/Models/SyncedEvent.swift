import EventKit
import Foundation

protocol EventProtocol {
    var eventIdentifier: String! { get }
    var startDate: Date! { get }
    var endDate: Date! { get }
}

extension EKEvent: EventProtocol {}

struct SyncedEvent {

    // MARK: - Properties

    let sourceEventId: String
    let destinationEventId: String?
    let title: String
    let startDate: Date
    let endDate: Date
    let otherPersonName: String
    let lastSyncDate: Date

    // MARK: - Lifecycle

    init(sourceEvent: EKEvent, otherPersonName: String) {
        sourceEventId = sourceEvent.eventIdentifier
        destinationEventId = nil
        title = "1:1 with \(otherPersonName)"
        startDate = sourceEvent.startDate
        endDate = sourceEvent.endDate
        self.otherPersonName = otherPersonName
        lastSyncDate = Date()
    }

    init(sourceEvent: some EventProtocol, otherPersonName: String) {
        sourceEventId = sourceEvent.eventIdentifier
        destinationEventId = nil
        title = "1:1 with \(otherPersonName)"
        startDate = sourceEvent.startDate
        endDate = sourceEvent.endDate
        self.otherPersonName = otherPersonName
        lastSyncDate = Date()
    }

    // Memberwise initializer for testing
    init(
        sourceEventId: String,
        destinationEventId: String?,
        title: String,
        startDate: Date,
        endDate: Date,
        otherPersonName: String,
        lastSyncDate: Date
    ) {
        self.sourceEventId = sourceEventId
        self.destinationEventId = destinationEventId
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.otherPersonName = otherPersonName
        self.lastSyncDate = lastSyncDate
    }
}
