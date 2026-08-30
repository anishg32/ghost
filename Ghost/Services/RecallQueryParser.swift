import Foundation

struct ParsedQuery {
    var timeRange: ClosedRange<Date>?
    var eventTypes: [EventType] = []
    var keyword: String?
}

struct RecallQueryParser {
    static func parse(_ query: String) -> ParsedQuery {
        let text = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        var parsed = ParsedQuery()
        var remainingWords = text.components(separatedBy: .whitespaces)
        
        let calendar = Calendar.current
        let now = Date()
        
        // Time parsing
        if text.contains("yesterday") {
            if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
               let start = calendar.date(bySettingHour: 0, minute: 0, second: 0, of: yesterday),
               let end = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: yesterday) {
                parsed.timeRange = start...end
                remainingWords.removeAll { $0 == "yesterday" }
            }
        } else if text.contains("today") {
            if let start = calendar.date(bySettingHour: 0, minute: 0, second: 0, of: now) {
                parsed.timeRange = start...now
                remainingWords.removeAll { $0 == "today" }
            }
        } else if text.contains("this morning") {
            if let start = calendar.date(bySettingHour: 5, minute: 0, second: 0, of: now),
               let end = calendar.date(bySettingHour: 11, minute: 59, second: 59, of: now) {
                parsed.timeRange = start...end
                remainingWords.removeAll { ["this", "morning"].contains($0) }
            }
        } else if text.contains("this afternoon") {
            if let start = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: now),
               let end = calendar.date(bySettingHour: 17, minute: 59, second: 59, of: now) {
                parsed.timeRange = start...end
                remainingWords.removeAll { ["this", "afternoon"].contains($0) }
            }
        } else if let match = text.range(of: #"around (\d{1,2})(?:\s)?([ap]m)"#, options: .regularExpression) {
            // Very naive "around X PM" parsing
            let timeStr = String(text[match])
            let pm = timeStr.contains("pm")
            let components = timeStr.components(separatedBy: CharacterSet.decimalDigits.inverted)
            if let hourStr = components.first(where: { !$0.isEmpty }), let hour = Int(hourStr) {
                var actualHour = hour
                if pm && hour < 12 { actualHour += 12 }
                if !pm && hour == 12 { actualHour = 0 }
                
                if let targetDate = calendar.date(bySettingHour: actualHour, minute: 0, second: 0, of: now),
                   let start = calendar.date(byAdding: .hour, value: -1, to: targetDate),
                   let end = calendar.date(byAdding: .hour, value: 1, to: targetDate) {
                    parsed.timeRange = start...end
                    
                    let matchedWords = timeStr.components(separatedBy: .whitespaces)
                    remainingWords.removeAll { matchedWords.contains($0) }
                }
            }
        }
        
        // Event Type parsing
        let eventMap: [String: [EventType]] = [
            "renamed": [.fileRenamed],
            "name": [.fileRenamed],
            "changed": [.fileRenamed],
            "moved": [.fileMoved],
            "where": [.fileMoved],
            "deleted": [.movedToTrash, .permanentlyDeleted],
            "trash": [.movedToTrash],
            "opened": [.appLaunched, .fileOpened],
            "launched": [.appLaunched],
            "quit": [.appQuit],
            "closed": [.appQuit]
        ]
        
        for (keyword, types) in eventMap {
            if text.contains(keyword) {
                parsed.eventTypes.append(contentsOf: types)
                remainingWords.removeAll { $0 == keyword }
            }
        }
        
        // Clean up keywords (ignore common filler words)
        let filler = ["what", "did", "i", "do", "that", "file", "go", "was", "working", "on", "when", "last", "which", "files", "my"]
        remainingWords.removeAll { filler.contains($0) || $0.isEmpty }
        
        if !remainingWords.isEmpty {
            parsed.keyword = remainingWords.joined(separator: " ")
        }
        
        return parsed
    }
}
