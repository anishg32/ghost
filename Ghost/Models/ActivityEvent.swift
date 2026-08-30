import Foundation
import SwiftData
import SwiftUI

@Model
final class ActivityEvent {
    var id: UUID
    var timestamp: Date
    var eventType: EventType
    var title: String
    var details: String?
    var appName: String?
    var oldPath: String?
    var newPath: String?
    var confidence: ConfidenceLevel
    var isRecovery: Bool
    var isUserInitiated: Bool
    
    init(id: UUID = UUID(), timestamp: Date = Date(), eventType: EventType, title: String, details: String? = nil, appName: String? = nil, oldPath: String? = nil, newPath: String? = nil, confidence: ConfidenceLevel = .high, isRecovery: Bool = false, isUserInitiated: Bool = true) {
        self.id = id
        self.timestamp = timestamp
        self.eventType = eventType
        self.title = title
        self.details = details
        self.appName = appName
        self.oldPath = oldPath
        self.newPath = newPath
        self.confidence = confidence
        self.isRecovery = isRecovery
        self.isUserInitiated = isUserInitiated
    }
}

enum ConfidenceLevel: String, Codable {
    case high
    case medium
    case low
}

enum EventType: String, Codable {
    case fileOpened
    case fileMoved
    case fileRenamed
    case movedToTrash
    case permanentlyDeleted
    case disappeared
    case appeared
    case appLaunched
    case appQuit
    case other
    
    var icon: String {
        switch self {
        case .fileOpened: return "doc"
        case .fileMoved: return "arrow.right.doc.on.clipboard"
        case .fileRenamed: return "pencil"
        case .movedToTrash: return "trash"
        case .permanentlyDeleted: return "xmark.bin"
        case .disappeared: return "questionmark.folder"
        case .appeared: return "plus.rectangle.on.folder"
        case .appLaunched: return "play.fill"
        case .appQuit: return "stop.fill"
        case .other: return "star"
        }
    }
    
    var color: Color {
        switch self {
        case .fileOpened: return .blue
        case .fileMoved: return .orange
        case .fileRenamed: return .purple
        case .movedToTrash: return .red
        case .permanentlyDeleted: return .red
        case .disappeared: return .gray
        case .appeared: return .green
        case .appLaunched: return .green
        case .appQuit: return .red
        case .other: return .gray
        }
    }
}
