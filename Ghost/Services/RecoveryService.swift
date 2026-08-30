import Foundation
import SwiftData

class RecoveryService {
    let repository: ActivityEventRepository
    
    init(repository: ActivityEventRepository) {
        self.repository = repository
    }
    
    func validate(event: RecallResult) -> RecoveryOperation {
        guard event.confidence == .high, let newPath = event.newPath, let oldPath = event.oldPath else {
            return RecoveryOperation(event: event, state: .unsupported, targetPath: "", destinationPath: "")
        }
        
        let fileManager = FileManager.default
        let currentExists = fileManager.fileExists(atPath: newPath)
        
        if !currentExists {
            return RecoveryOperation(event: event, state: .fileMissing, targetPath: newPath, destinationPath: oldPath)
        }
        
        let oldURL = URL(fileURLWithPath: oldPath)
        let destinationDir = oldURL.deletingLastPathComponent().path
        let dirExists = fileManager.fileExists(atPath: destinationDir)
        
        if !dirExists {
            return RecoveryOperation(event: event, state: .destinationMissing, targetPath: newPath, destinationPath: oldPath)
        }
        
        let oldExists = fileManager.fileExists(atPath: oldPath)
        if oldExists {
            return RecoveryOperation(event: event, state: .conflict(existingFileName: oldURL.lastPathComponent), targetPath: newPath, destinationPath: oldPath)
        }
        
        return RecoveryOperation(event: event, state: .ready, targetPath: newPath, destinationPath: oldPath)
    }
    
    enum ConflictResolution {
        case cancel
        case replace
        case renameRecovered
    }
    
    func execute(operation: RecoveryOperation, resolution: ConflictResolution = .cancel) async -> Bool {
        if resolution == .cancel && operation.state != .ready {
            return false
        }
        
        let targetPath = operation.targetPath
        let destPath = operation.destinationPath
        let operationState = operation.state
        
        // Ensure blocking file ops run off the main actor explicitly
        let finalDestURL = await Task.detached(priority: .userInitiated) { () -> URL? in
            let fileManager = FileManager.default
            let sourceURL = URL(fileURLWithPath: targetPath)
            var destURL = URL(fileURLWithPath: destPath)
            
            if case .conflict = operationState {
                if resolution == .replace {
                    do {
                        try fileManager.removeItem(at: destURL)
                    } catch {
                        print("Failed to replace file: \(error)")
                        return nil
                    }
                } else if resolution == .renameRecovered {
                    let baseName = destURL.deletingPathExtension().lastPathComponent
                    let ext = destURL.pathExtension
                    let dir = destURL.deletingLastPathComponent()
                    
                    var counter = 2
                    var newURL = dir.appendingPathComponent("\(baseName) (Recovered).\(ext)")
                    
                    // Collision loop
                    while fileManager.fileExists(atPath: newURL.path) {
                        newURL = dir.appendingPathComponent("\(baseName) (Recovered \(counter)).\(ext)")
                        counter += 1
                    }
                    destURL = newURL
                }
            }
            
            // Suppress the FSEvent that this move will generate
            ActivityTrackingService.shared.fileProcessor?.suppressNextEvent(for: destURL.path)
            
            do {
                try fileManager.moveItem(at: sourceURL, to: destURL)
                return destURL
            } catch {
                print("Failed recovery move: \(error)")
                return nil
            }
        }.value
        
        if let destURL = finalDestURL {
            let sourceURL = URL(fileURLWithPath: operation.targetPath)
            
            // Log explicitly
            let isRename = sourceURL.deletingLastPathComponent() == destURL.deletingLastPathComponent()
            let title = isRename ? "↶ Restored previous file name" : "↶ Moved file back"
            let type: EventType = isRename ? .fileRenamed : .fileMoved
            
            await repository.insertEvent(
                eventType: type,
                title: title,
                details: "\(sourceURL.lastPathComponent)\n→\n\(destURL.lastPathComponent)",
                appName: "Ghost Recovery",
                oldPath: sourceURL.path,
                newPath: destURL.path,
                confidence: .high,
                isRecovery: true,
                isUserInitiated: true
            )
            return true
        }
        
        return false
    }
}
