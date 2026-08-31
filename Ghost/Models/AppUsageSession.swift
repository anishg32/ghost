import Foundation
import SwiftData

@Model
final class AppUsageSession {
    var id: UUID
    var appName: String
    var bundleId: String?
    var startTime: Date
    var endTime: Date
    var duration: TimeInterval
    
    init(id: UUID = UUID(), appName: String, bundleId: String? = nil, startTime: Date, endTime: Date) {
        self.id = id
        self.appName = appName
        self.bundleId = bundleId
        self.startTime = startTime
        self.endTime = endTime
        self.duration = endTime.timeIntervalSince(startTime)
    }
}
