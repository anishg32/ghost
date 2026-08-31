import SwiftUI
import SwiftData

struct TimelineView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ActivityEvent.timestamp, order: .reverse) private var events: [ActivityEvent]
    
    @State private var appearState: Int = 0 // 0: hidden, 1: greeting, 2: stats, 3: graph, 4: list
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Header Area
                VStack(alignment: .leading, spacing: 12) {
                    Text(greeting)
                        .font(.title2)
                        .fontWeight(.bold)
                        .opacity(appearState > 0 || reduceMotion ? 1 : 0)
                        .offset(y: appearState > 0 || reduceMotion ? 0 : 10)
                    
                    let stats = calculateStats()
                    
                    HStack(spacing: 4) {
                        Text("Your Mac remembered")
                        AnimatedNumberView(value: stats.todayCount)
                        Text("actions today.")
                    }
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .opacity(appearState > 1 || reduceMotion ? 1 : 0)
                    .offset(y: appearState > 1 || reduceMotion ? 0 : 10)
                    
                    if stats.yesterdayCount > 0 {
                        let diff = stats.todayCount - stats.yesterdayCount
                        let percent = Int(abs(Double(diff) / Double(stats.yesterdayCount)) * 100)
                        
                        HStack(spacing: 4) {
                            Image(systemName: diff >= 0 ? "arrow.up" : "arrow.down")
                            Text("\(percent)% from yesterday")
                        }
                        .font(.subheadline)
                        .foregroundColor(diff >= 0 ? .green : .secondary)
                        .opacity(appearState > 1 || reduceMotion ? 1 : 0)
                        .offset(y: appearState > 1 || reduceMotion ? 0 : 10)
                    }
                }
                .padding(.horizontal, 30)
                .padding(.top, 30)
                
                // Graph
                ActivityPulseGraph(events: events)
                    .padding(.horizontal, 30)
                    .padding(.vertical, 20)
                    .opacity(appearState > 2 || reduceMotion ? 1 : 0)
                    .offset(y: appearState > 2 || reduceMotion ? 0 : 10)
                
                // Event List
                VStack(alignment: .leading, spacing: 0) {
                    Text("TODAY")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 30)
                        .padding(.bottom, 16)
                        .opacity(appearState > 3 || reduceMotion ? 1 : 0)
                    
                    if events.isEmpty {
                        TimelineEmptyStateView()
                            .opacity(appearState > 3 || reduceMotion ? 1 : 0)
                    } else {
                        LazyVStack(spacing: 16) {
                            ForEach(Array(groupedEvents.enumerated()), id: \.element.id) { index, group in
                                Group {
                                    if group.events.count == 1 {
                                        EventRowView(event: group.events.first!)
                                            .padding(.horizontal, 30)
                                    } else {
                                        ExpandableGroupRowView(group: group)
                                            .padding(.horizontal, 30)
                                    }
                                }
                                .opacity(appearState > 3 || reduceMotion ? 1 : 0)
                                .offset(y: appearState > 3 || reduceMotion ? 0 : 20)
                                .animation(
                                    GhostUI.motionAnimation(GhostUI.gentleSpring.delay(Double(index) * 0.05)),
                                    value: appearState
                                )
                                .transition(.move(edge: .top).combined(with: .opacity))
                            }
                        }
                    }
                }
                
                Spacer(minLength: 40)
            }
        }
        .navigationTitle("Timeline")
        .navigationDocument(URL(fileURLWithPath: "/")) // dummy to keep native title bar look
        .onAppear {
            if !reduceMotion {
                orchestrateEntrance()
            }
        }
        .animation(GhostUI.gentleSpring, value: events.count) // Smooth list updates when new events arrive
    }
    
    private func orchestrateEntrance() {
        // Staggered entrance animation
        withAnimation(GhostUI.gentleSpring) { appearState = 1 }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(GhostUI.gentleSpring) { appearState = 2 }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(GhostUI.gentleSpring) { appearState = 3 }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(GhostUI.gentleSpring) { appearState = 4 }
        }
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
                break
            }
        }
        
        return (t, y)
    }
}

struct TimelineEmptyStateView: View {
    @State private var isFloating = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "moon.stars")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
                .offset(y: isFloating && !reduceMotion ? -5 : 5)
                .animation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true), value: isFloating)
                .onAppear {
                    isFloating = true
                }
            
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
        .ghostCardStyle(backgroundColor: event.isRecovery ? Color.blue.opacity(0.1) : Color(NSColor.controlBackgroundColor))
        .hoverScaleEffect()
    }
}

struct ExpandableGroupRowView: View {
    let group: EventGroup
    @State private var isExpanded = false
    
    var body: some View {
        VStack(spacing: 0) {
            Button(action: {
                GhostUI.withMotion(GhostUI.gentleSpring) {
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
                    
                    Image(systemName: "chevron.right")
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                .padding()
            }
            .buttonStyle(.plain)
            
            if isExpanded {
                VStack(spacing: 8) {
                    ForEach(Array(group.events.enumerated()), id: \.element.id) { index, event in
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
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                .padding(.bottom, 12)
            }
        }
        .ghostCardStyle()
        .hoverScaleEffect()
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

