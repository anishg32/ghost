import Foundation
import SwiftUI

/// A safe value type for passing SwiftData models across actor boundaries.
struct RecallResult: Identifiable, Sendable, Hashable {
    let id: UUID
    let timestamp: Date
    let eventType: EventType
    let title: String
    let details: String?
    let appName: String?
    let oldPath: String?
    let newPath: String?
    let confidence: ConfidenceLevel
    let isRecovery: Bool
    let isUserInitiated: Bool
    
    init(from event: ActivityEvent) {
        self.id = event.id
        self.timestamp = event.timestamp
        self.eventType = event.eventType
        self.title = event.title
        self.details = event.details
        self.appName = event.appName
        self.oldPath = event.oldPath
        self.newPath = event.newPath
        self.confidence = event.confidence
        self.isRecovery = event.isRecovery
        self.isUserInitiated = event.isUserInitiated
    }
}

struct RecallResultGroup: Identifiable, Hashable {
    let id = UUID()
    let eventType: EventType
    let events: [RecallResult]
}
