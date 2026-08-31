import Foundation
import SwiftData

@ModelActor
actor ActivityEventRepository {
    func insertEvent(eventType: EventType, title: String, details: String? = nil, appName: String? = nil, oldPath: String? = nil, newPath: String? = nil, confidence: ConfidenceLevel = .high, isRecovery: Bool = false, isUserInitiated: Bool = true) {
        let event = ActivityEvent(
            eventType: eventType,
            title: title,
            details: details,
            appName: appName,
            oldPath: oldPath,
            newPath: newPath,
            confidence: confidence,
            isRecovery: isRecovery,
            isUserInitiated: isUserInitiated
        )
        modelContext.insert(event)
        try? modelContext.save()
    }
    
    func insertAppUsageSession(appName: String, bundleId: String?, startTime: Date, endTime: Date) {
        let session = AppUsageSession(
            appName: appName,
            bundleId: bundleId,
            startTime: startTime,
            endTime: endTime
        )
        modelContext.insert(session)
        try? modelContext.save()
    }
}
