import Foundation
import EventKit

protocol EventProtocol {
    var eventIdentifier: String! { get }
    var startDate: Date! { get }
    var endDate: Date! { get }
}

extension EKEvent: EventProtocol {}

struct SyncedEvent {
    let sourceEventId: String
    let destinationEventId: String?
    let title: String
    let startDate: Date
    let endDate: Date
    let otherPersonName: String
    let lastSyncDate: Date

    init(sourceEvent: EKEvent, otherPersonName: String) {
        self.sourceEventId = sourceEvent.eventIdentifier
        self.destinationEventId = nil
        self.title = "1:1 with \(otherPersonName)"
        self.startDate = sourceEvent.startDate
        self.endDate = sourceEvent.endDate
        self.otherPersonName = otherPersonName
        self.lastSyncDate = Date()
    }

    init<T: EventProtocol>(sourceEvent: T, otherPersonName: String) {
        self.sourceEventId = sourceEvent.eventIdentifier
        self.destinationEventId = nil
        self.title = "1:1 with \(otherPersonName)"
        self.startDate = sourceEvent.startDate
        self.endDate = sourceEvent.endDate
        self.otherPersonName = otherPersonName
        self.lastSyncDate = Date()
    }

    // Memberwise initializer for testing
    init(sourceEventId: String, destinationEventId: String?, title: String, startDate: Date, endDate: Date, otherPersonName: String, lastSyncDate: Date) {
        self.sourceEventId = sourceEventId
        self.destinationEventId = destinationEventId
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.otherPersonName = otherPersonName
        self.lastSyncDate = lastSyncDate
    }
}
