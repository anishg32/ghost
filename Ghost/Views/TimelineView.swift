import SwiftUI
import SwiftData

struct TimelineView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ActivityEvent.timestamp, order: .reverse) private var events: [ActivityEvent]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Header Area
                VStack(alignment: .leading, spacing: 12) {
                    Text(greeting)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    let stats = calculateStats()
                    
                    Text("Your Mac remembered \(stats.todayCount) actions today.")
                        .font(.title3)
                        .foregroundColor(.secondary)
                    
                    if stats.yesterdayCount > 0 {
                        let diff = stats.todayCount - stats.yesterdayCount
                        let percent = Int(abs(Double(diff) / Double(stats.yesterdayCount)) * 100)
                        
                        HStack(spacing: 4) {
                            Image(systemName: diff >= 0 ? "arrow.up" : "arrow.down")
                            Text("\(percent)% from yesterday")
                        }
                        .font(.subheadline)
                        .foregroundColor(diff >= 0 ? .green : .secondary)
                    }
                }
                .padding(.horizontal, 30)
                .padding(.top, 30)
                
                // Graph
                ActivityPulseGraph(events: events)
                    .padding(.horizontal, 30)
                    .padding(.vertical, 20)
                
                // Event List
                VStack(alignment: .leading, spacing: 0) {
                    Text("TODAY")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 30)
                        .padding(.bottom, 16)
                    
                    if events.isEmpty {
                        TimelineEmptyStateView()
                    } else {
                        LazyVStack(spacing: 16) {
                            ForEach(groupedEvents) { group in
                                if group.events.count == 1 {
                                    EventRowView(event: group.events.first!)
                                        .padding(.horizontal, 30)
                                } else {
                                    ExpandableGroupRowView(group: group)
                                        .padding(.horizontal, 30)
                                }
                            }
                        }
                    }
                }
                
                Spacer(minLength: 40)
            }
        }
        .navigationTitle("Timeline")
        .navigationDocument(URL(fileURLWithPath: "/")) // dummy to keep native title bar look
    }
    
    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12: return "Good morning 👻"
        case 12..<17: return "Good afternoon 👻"
        default: return "Good evening 👻"
        }
    }
    
    private func calculateStats() -> (todayCount: Int, yesterdayCount: Int) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        
        var t = 0
        var y = 0
        
        for event in events {
            if event.timestamp >= today {
                t += 1
            } else if event.timestamp >= yesterday && event.timestamp < today {
                y += 1
            } else if event.timestamp < yesterday {
                // Since they are reverse sorted, we can stop early to optimize
                break
            }
        }
        
        return (t, y)
    }
}

struct TimelineEmptyStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "moon.stars")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            
            Text("Nothing remembered yet.")
                .font(.headline)
            
            Text("Ghost is quietly watching your selected folders.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }
}

struct EventRowView: View {
    let event: ActivityEvent
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: event.eventType.icon)
                .font(.title3)
                .foregroundColor(event.isRecovery ? .blue : event.eventType.color)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(event.title)
                        .font(.body)
                        .fontWeight(event.isRecovery ? .semibold : .regular)
                    
                    if event.confidence != .high {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.yellow)
                            .font(.caption)
                            .help("Medium or Low Confidence")
                    }
                }
                
                if let details = event.details {
                    Text(details)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            
            Spacer()
            
            Text(event.timestamp, format: Date.FormatStyle(time: .shortened))
                .font(.caption)
                .foregroundColor(Color(NSColor.tertiaryLabelColor))
        }
        .padding()
        .background(event.isRecovery ? Color.blue.opacity(0.1) : Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
}

struct ExpandableGroupRowView: View {
    let group: EventGroup
    @State private var isExpanded = false
    
    var body: some View {
        VStack(spacing: 0) {
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isExpanded.toggle()
                }
            }) {
                HStack(alignment: .top, spacing: 16) {
                    Image(systemName: group.eventType.icon)
                        .font(.title3)
                        .foregroundColor(group.eventType.color)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(group.title)
                            .font(.body)
                            .fontWeight(.medium)
                        
                        Text(previewText)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    if let firstEvent = group.events.first {
                        Text(firstEvent.timestamp, format: Date.FormatStyle(time: .shortened))
                            .font(.caption)
                            .foregroundColor(Color(NSColor.tertiaryLabelColor))
                    }
                }
                .padding()
            }
            .buttonStyle(.plain)
            
            if isExpanded {
                VStack(spacing: 8) {
                    ForEach(group.events) { event in
                        HStack {
                            Rectangle()
                                .fill(Color.secondary.opacity(0.2))
                                .frame(width: 2)
                                .padding(.leading, 26)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(event.title)
                                    .font(.subheadline)
                                if let details = event.details {
                                    Text(details)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                            }
                            .padding(.leading, 8)
                            
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding(.bottom, 12)
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    private var previewText: String {
        let names = group.events.compactMap { $0.newPath ?? $0.oldPath }.map { URL(fileURLWithPath: $0).lastPathComponent }
        if names.isEmpty { return "" }
        if names.count <= 2 {
            return names.joined(separator: ", ")
        } else {
            return "\(names[0]), \(names[1]) +\(names.count - 2) more"
        }
    }
}

struct EventGroup: Identifiable {
    let id = UUID()
    let eventType: EventType
    let events: [ActivityEvent]
    
    var title: String {
        switch eventType {
        case .fileRenamed: return "Renamed \(events.count) files"
        case .fileMoved: return "Moved \(events.count) files"
        default: return "\(events.count) events"
        }
    }
}

extension TimelineView {
    var groupedEvents: [EventGroup] {
        var groups: [EventGroup] = []
        var currentGroupEvents: [ActivityEvent] = []
        
        for event in events {
            if let last = currentGroupEvents.last {
                // Group if same eventType, within 10 seconds, and NEITHER is a recovery event
                if last.eventType == event.eventType && 
                   !last.isRecovery && 
                   !event.isRecovery &&
                   abs(last.timestamp.timeIntervalSince(event.timestamp)) < 10 {
                    currentGroupEvents.append(event)
                } else {
                    if !currentGroupEvents.isEmpty {
                        groups.append(EventGroup(eventType: currentGroupEvents.first!.eventType, events: currentGroupEvents))
                    }
                    currentGroupEvents = [event]
                }
            } else {
                currentGroupEvents.append(event)
            }
        }
        if !currentGroupEvents.isEmpty {
            groups.append(EventGroup(eventType: currentGroupEvents.first!.eventType, events: currentGroupEvents))
        }
        
        return groups
    }
}
