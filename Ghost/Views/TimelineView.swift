import SwiftUI
import SwiftData

struct GhostTimelineView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ActivityEvent.timestamp, order: .reverse) private var events: [ActivityEvent]
    
    let recoveryService: RecoveryService
    
    @State private var appearState: Int = 0
    @State private var highlightedTimeRange: ClosedRange<Date>? = nil
    @State private var selectedHistoryPath: String? = nil
    @State private var operationToConfirm: RecoveryOperation? = nil
    @State private var successMessage: String? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Header Area
                    headerSection
                    
                    // Graph
                    ActivityPulseGraph(events: events) { range in
                        withAnimation(GhostUI.quickSpring) {
                            highlightedTimeRange = range
                        }
                    }
                    .padding(.horizontal, 30)
                    .padding(.vertical, 20)
                    .opacity(appearState > 2 || reduceMotion ? 1 : 0)
                    .offset(y: appearState > 2 || reduceMotion ? 0 : 10)
                    
                    // Memory Stream
                    memoryStreamSection
                    
                    Spacer(minLength: 40)
                }
            }
            .blur(radius: successMessage == nil ? 0 : 10)
            .opacity(successMessage == nil ? 1 : 0.5)
            
            if let msg = successMessage {
                RecoverySuccessView(message: msg)
                    .zIndex(1)
            }
        }
        .animation(GhostUI.gentleSpring, value: successMessage)
        .navigationTitle("Timeline")
        .onAppear {
            if !reduceMotion {
                orchestrateEntrance()
            } else {
                appearState = 4
            }
        }
        .animation(GhostUI.gentleSpring, value: events.count)
        .sheet(item: $selectedHistoryPath) { path in
            FileHistoryView(path: path)
        }
        .sheet(item: $operationToConfirm) { operation in
            RecoveryConfirmationSheet(operation: operation, service: recoveryService) { success in
                operationToConfirm = nil
                if success {
                    let oldName = URL(fileURLWithPath: operation.targetPath).lastPathComponent
                    let newName = URL(fileURLWithPath: operation.destinationPath).lastPathComponent
                    successMessage = "\(oldName) → \(newName)"
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                        withAnimation(GhostUI.smoothFade) {
                            successMessage = nil
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
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
    }
    
    // MARK: - Memory Stream
    
    private var memoryStreamSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            if events.isEmpty {
                GhostEmptyState(
                    icon: "moon.stars",
                    title: "Nothing remembered yet.",
                    subtitle: "Ghost is quietly watching your selected folders."
                )
                .opacity(appearState > 3 || reduceMotion ? 1 : 0)
            } else {
                let sections = groupEventsByDay()
                
                ForEach(Array(sections.enumerated()), id: \.element.title) { sectionIndex, section in
                    // Section Header
                    HStack(spacing: 10) {
                        GhostTimelineDot(size: 8, color: .indigo)
                        Text(section.title)
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 30)
                    .padding(.top, sectionIndex == 0 ? 0 : 24)
                    .padding(.bottom, 12)
                    .opacity(appearState > 3 || reduceMotion ? 1 : 0)
                    
                    // Events with connectors
                    ForEach(Array(section.events.enumerated()), id: \.element.id) { index, event in
                        VStack(spacing: 0) {
                            MemoryStreamEventRow(
                                event: event,
                                isHighlighted: isEventHighlighted(event),
                                isDimmed: isDimmedByGraphHover(event),
                                recoveryService: recoveryService,
                                onRecover: { recoverEvent(event) },
                                onViewHistory: { viewHistory(for: event) }
                            )
                            .padding(.horizontal, 30)
                            
                            // Connector to next event
                            if index < section.events.count - 1 {
                                HStack(spacing: 0) {
                                    Spacer()
                                        .frame(width: 41) // Align with the dot column
                                    GhostTimelineConnector(
                                        height: 16,
                                        opacity: connectorOpacity(for: index, total: section.events.count)
                                    )
                                    Spacer()
                                }
                            }
                        }
                        .opacity(appearState > 3 || reduceMotion ? 1 : 0)
                        .offset(y: appearState > 3 || reduceMotion ? 0 : 15)
                        .animation(
                            GhostUI.motionAnimation(GhostUI.memoryAppear.delay(Double(index) * 0.04)),
                            value: appearState
                        )
                    }
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    private func isEventHighlighted(_ event: ActivityEvent) -> Bool {
        event.isRecovery
    }
    
    private func isDimmedByGraphHover(_ event: ActivityEvent) -> Bool {
        guard let range = highlightedTimeRange else { return false }
        return !(event.timestamp >= range.lowerBound && event.timestamp <= range.upperBound)
    }
    
    private func connectorOpacity(for index: Int, total: Int) -> Double {
        // Slightly fade connectors as events get older
        let progress = Double(index) / Double(max(total - 1, 1))
        return 0.2 - (progress * 0.08) // 0.20 → 0.12
    }
    
    private func recoverEvent(_ event: ActivityEvent) {
        let result = RecallResult(from: event)
        let operation = recoveryService.validate(event: result)
        if operation.state == .unsupported || operation.state == .fileMissing || operation.state == .destinationMissing {
            // Can't recover — do nothing (or optionally show an alert)
            return
        }
        operationToConfirm = operation
    }
    
    private func viewHistory(for event: ActivityEvent) {
        if let path = event.newPath ?? event.oldPath {
            selectedHistoryPath = path
        }
    }
    
    private func orchestrateEntrance() {
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
    
    // MARK: - Day grouping
    
    struct DaySection: Identifiable {
        var id: String { title }
        let title: String
        let events: [ActivityEvent]
    }
    
    private func groupEventsByDay() -> [DaySection] {
        let calendar = Calendar.current
        var sections: [DaySection] = []
        var currentDayEvents: [ActivityEvent] = []
        var currentDayTitle: String? = nil
        
        for event in events {
            let dayTitle = dayLabel(for: event.timestamp, calendar: calendar)
            
            if dayTitle == currentDayTitle {
                currentDayEvents.append(event)
            } else {
                if let title = currentDayTitle, !currentDayEvents.isEmpty {
                    sections.append(DaySection(title: title, events: currentDayEvents))
                }
                currentDayTitle = dayTitle
                currentDayEvents = [event]
            }
        }
        
        if let title = currentDayTitle, !currentDayEvents.isEmpty {
            sections.append(DaySection(title: title, events: currentDayEvents))
        }
        
        return sections
    }
    
    private func dayLabel(for date: Date, calendar: Calendar) -> String {
        if calendar.isDateInToday(date) { return "TODAY" }
        if calendar.isDateInYesterday(date) { return "YESTERDAY" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date).uppercased()
    }
}

// MARK: - Memory Stream Event Row

struct MemoryStreamEventRow: View {
    let event: ActivityEvent
    let isHighlighted: Bool
    let isDimmed: Bool
    let recoveryService: RecoveryService
    let onRecover: () -> Void
    let onViewHistory: () -> Void
    
    @State private var isHovered = false
    
    private var isRecoverable: Bool {
        (event.eventType == .fileRenamed || event.eventType == .fileMoved) &&
        event.confidence == .high &&
        event.oldPath != nil && event.newPath != nil &&
        !event.isRecovery
    }
    
    private var hasHistory: Bool {
        event.newPath != nil || event.oldPath != nil
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Timeline dot
            GhostTimelineDot(
                size: GhostUI.connectorDotSize,
                color: event.isRecovery ? .blue : event.eventType.color,
                isCurrent: false
            )
            .frame(width: 20)
            .padding(.top, 6)
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: event.eventType.icon)
                        .font(.subheadline)
                        .foregroundColor(event.isRecovery ? .blue : event.eventType.color)
                    
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
                
                // Hover actions
                if isHovered {
                    HStack(spacing: 8) {
                        if hasHistory {
                            Button(action: onViewHistory) {
                                HStack(spacing: 3) {
                                    Image(systemName: "clock.arrow.circlepath")
                                        .font(.caption2)
                                    Text("History")
                                        .font(.caption)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.secondary.opacity(0.08))
                                .cornerRadius(5)
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(.secondary)
                        }
                        
                        if isRecoverable {
                            GhostRecoveryBadge(label: "Recover", action: onRecover)
                        }
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            
            Spacer()
            
            Text(event.timestamp, format: Date.FormatStyle(time: .shortened))
                .font(.caption)
                .foregroundColor(Color(NSColor.tertiaryLabelColor))
                .padding(.top, 4)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .ghostCardStyle(
            backgroundColor: event.isRecovery ? Color.blue.opacity(0.06) : Color(NSColor.controlBackgroundColor),
            isHighlighted: isHighlighted
        )
        .opacity(isDimmed ? 0.4 : 1.0)
        .scaleEffect(isHovered ? 1.005 : 1.0)
        .animation(GhostUI.quickSpring, value: isHovered)
        .animation(GhostUI.quickSpring, value: isDimmed)
        .onHover { hovering in
            withAnimation(GhostUI.quickSpring) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Make String Identifiable for sheet

extension String: @retroactive Identifiable {
    public var id: String { self }
}
