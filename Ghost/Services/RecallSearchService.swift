import Foundation
import SwiftData

@ModelActor
actor RecallSearchService {
    func search(query: String, limit: Int = 100) -> [RecallResult] {
        if Task.isCancelled { return [] }
        let parsed = RecallQueryParser.parse(query)
        
        var descriptor = FetchDescriptor<ActivityEvent>(sortBy: [SortDescriptor(\.timestamp, order: .reverse)])
        
        // Time bounds
        if let timeRange = parsed.timeRange {
            let start = timeRange.lowerBound
            let end = timeRange.upperBound
            descriptor.predicate = #Predicate<ActivityEvent> { event in
                event.timestamp >= start && event.timestamp <= end
            }
        }
        
        do {
            if Task.isCancelled { return [] }
            let initialResults = try modelContext.fetch(descriptor)
            
            var filtered = initialResults.filter { event in
                if !parsed.eventTypes.isEmpty {
                    guard parsed.eventTypes.contains(event.eventType) else { return false }
                }
                
                if let keyword = parsed.keyword, !keyword.isEmpty {
                    let kw = keyword.lowercased()
                    let matchesTitle = event.title.lowercased().contains(kw)
                    let matchesDetails = event.details?.lowercased().contains(kw) ?? false
                    let matchesApp = event.appName?.lowercased().contains(kw) ?? false
                    let matchesOld = event.oldPath?.lowercased().contains(kw) ?? false
                    let matchesNew = event.newPath?.lowercased().contains(kw) ?? false
                    
                    if !(matchesTitle || matchesDetails || matchesApp || matchesOld || matchesNew) {
                        return false
                    }
                }
                return true
            }
            
            if Task.isCancelled { return [] }
            
            filtered = Array(filtered.prefix(limit))
            return filtered.map { RecallResult(from: $0) }
            
        } catch {
            print("Failed to fetch Recall results: \(error)")
            return []
        }
    }
    
    /// Recursively chains backward in time to find the true chronological history of a file
    func fileHistory(for startingPath: String) -> [RecallResult] {
        var descriptor = FetchDescriptor<ActivityEvent>(sortBy: [SortDescriptor(\.timestamp, order: .reverse)])
        
        do {
            let allEvents = try modelContext.fetch(descriptor)
            var history: [ActivityEvent] = []
            var currentActivePath = startingPath
            
            // Because allEvents is reverse-chronological, we iterate from newest to oldest
            for event in allEvents {
                if event.newPath == currentActivePath || event.oldPath == currentActivePath {
                    history.append(event)
                    
                    // If this event was a rename/move, the file used to be known as oldPath before this moment.
                    // We update the active path we are tracking backward.
                    if let old = event.oldPath, event.eventType == .fileMoved || event.eventType == .fileRenamed {
                        currentActivePath = old
                    }
                }
            }
            
            return history.map { RecallResult(from: $0) }
        } catch {
            return []
        }
    }
}
