import Foundation
import CoreServices

class FileChangeProcessor {
    private let repository: ActivityEventRepository
    private var eventBuffer: [FSEvent] = []
    private var bufferTimer: Timer?
    private var suppressedPaths: [String: Date] = [:]
    private let queue = DispatchQueue(label: "com.ghost.FileChangeProcessor")
    
    init(repository: ActivityEventRepository) {
        self.repository = repository
    }
    
    func suppressNextEvent(for path: String) {
        queue.async {
            self.suppressedPaths[path] = Date().addingTimeInterval(2.0)
        }
    }
    
    func process(event: FSEvent) {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            let now = Date()
            
            // Clean up expired entries
            let expiredKeys = self.suppressedPaths.filter { $0.value < now }.map { $0.key }
            for key in expiredKeys {
                self.suppressedPaths.removeValue(forKey: key)
            }
            
            let fileName = (event.path as NSString).lastPathComponent
            if fileName.hasPrefix(".") || fileName.hasSuffix(".tmp") {
                return
            }
            
            if let expiration = self.suppressedPaths[event.path], expiration >= now {
                // We expected this event because Ghost performed a recovery.
                // We discard it and remove it from the suppression list.
                self.suppressedPaths.removeValue(forKey: event.path)
                return
            }
            
            self.eventBuffer.append(event)
            self.scheduleBufferProcessing()
        }
    }
    
    private func scheduleBufferProcessing() {
        bufferTimer?.invalidate()
        DispatchQueue.main.async { [weak self] in
            self?.bufferTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: false) { _ in
                self?.queue.async {
                    self?.processBuffer()
                }
            }
        }
    }
    
    private func processBuffer() {
        let events = eventBuffer.sorted { $0.id < $1.id }
        eventBuffer.removeAll()
        
        let renames = events.filter { ($0.flags & UInt32(kFSEventStreamEventFlagItemRenamed)) != 0 }
        
        var processedIds: Set<FSEventStreamEventId> = []
        
        for i in 0..<renames.count {
            let event = renames[i]
            if processedIds.contains(event.id) { continue }
            
            // Look for adjacent ID (usually +1)
            if i + 1 < renames.count, renames[i+1].id == event.id + 1 {
                let event2 = renames[i+1]
                processedIds.insert(event.id)
                processedIds.insert(event2.id)
                
                // Which one is old, which is new? FSEvents usually orders Old then New.
                // We verify by checking which file exists.
                let path1Exists = FileManager.default.fileExists(atPath: event.path)
                let path2Exists = FileManager.default.fileExists(atPath: event2.path)
                
                var oldPath: String?
                var newPath: String?
                
                if path2Exists && !path1Exists {
                    oldPath = event.path
                    newPath = event2.path
                } else if path1Exists && !path2Exists {
                    oldPath = event2.path
                    newPath = event.path
                } else {
                    // Fallback to order if both or neither exist
                    oldPath = event.path
                    newPath = event2.path
                }
                
                if let old = oldPath, let new = newPath {
                    let oldURL = URL(fileURLWithPath: old)
                    let newURL = URL(fileURLWithPath: new)
                    
                    let isSameDir = oldURL.deletingLastPathComponent() == newURL.deletingLastPathComponent()
                    let isTrash = newURL.pathComponents.contains(".Trash")
                    
                    if isTrash {
                        insertEvent(
                            eventType: .movedToTrash,
                            title: "Moved \(oldURL.lastPathComponent) to Trash",
                            appName: "Finder",
                            oldPath: old,
                            newPath: new,
                            confidence: .high
                        )
                    } else {
                        let title = isSameDir ? "Renamed \(newURL.lastPathComponent)" : "Moved \(newURL.lastPathComponent)"
                        let eventType: EventType = isSameDir ? .fileRenamed : .fileMoved
                        let details = isSameDir ?
                            "Old: \(oldURL.lastPathComponent)\nNew: \(newURL.lastPathComponent)" :
                            "\(oldURL.deletingLastPathComponent().lastPathComponent)\n→\n\(newURL.deletingLastPathComponent().lastPathComponent)"
                        
                        insertEvent(
                            eventType: eventType,
                            title: title,
                            details: details,
                            appName: "Finder",
                            oldPath: old,
                            newPath: new,
                            confidence: .high
                        )
                    }
                }
            } else {
                // Unpaired rename event (e.g. moved outside tracked folder)
                processedIds.insert(event.id)
                let exists = FileManager.default.fileExists(atPath: event.path)
                let url = URL(fileURLWithPath: event.path)
                
                if exists {
                    insertEvent(
                        eventType: .appeared,
                        title: "Appeared \(url.lastPathComponent)",
                        appName: "Finder",
                        newPath: event.path,
                        confidence: .medium
                    )
                } else {
                    insertEvent(
                        eventType: .disappeared,
                        title: "Disappeared \(url.lastPathComponent)",
                        appName: "Finder",
                        oldPath: event.path,
                        confidence: .medium
                    )
                }
            }
        }
    }
    
    private func insertEvent(eventType: EventType, title: String, details: String? = nil, appName: String? = nil, oldPath: String? = nil, newPath: String? = nil, confidence: ConfidenceLevel) {
        Task {
            await repository.insertEvent(
                eventType: eventType,
                title: title,
                details: details,
                appName: appName,
                oldPath: oldPath,
                newPath: newPath,
                confidence: confidence
            )
        }
    }
}
