import SwiftUI
import SwiftData

struct MenuBarView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ActivityEvent.timestamp, order: .reverse) private var events: [ActivityEvent]
    @Query(sort: \AppUsageSession.startTime, order: .reverse) private var sessions: [AppUsageSession]
    
    @State private var isTracking: Bool = ActivityTrackingService.shared.isTrackingEnabled
    
    @AppStorage("ghost_menuStatus") private var menuStatus = true
    @AppStorage("ghost_menuLatestMemory") private var menuLatestMemory = true
    @AppStorage("ghost_menuTopApps") private var menuTopApps = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    GhostPulse(state: ghostState)
                    Text("Ghost")
                        .font(.headline)
                }
                Spacer()
                Text(isTracking ? "Watching" : "Paused")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .contentTransition(.interpolate)
            }
            .padding()
            
            if menuStatus {
                // Today Summary
                VStack(alignment: .leading, spacing: 8) {
                    Text("Today")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                    
                    let todaySessions = sessions.filter { Calendar.current.isDateInToday($0.startTime) }
                    let totalDuration = todaySessions.reduce(0) { $0 + $1.duration }
                    
                    Text("\(formattedDurationLong(totalDuration)) active")
                        .font(.system(size: 20, weight: .bold))
                    
                    let todayCount = events.filter { Calendar.current.isDateInToday($0.timestamp) }.count
                    HStack(spacing: 4) {
                        AnimatedNumberView(value: todayCount)
                        Text("actions remembered")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.bottom, 12)
                
                Divider()
            }
            
            if menuLatestMemory {
                // Latest memory text
                if let latest = events.first {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("LATEST MEMORY")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.secondary)
                        
                        Text(latest.title)
                            .font(.subheadline)
                            .lineLimit(1)
                        
                        Text(latest.timestamp, format: .relative(presentation: .numeric))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                    
                    Divider()
                }
            }
            
            if menuTopApps {
                let topApps = calculateTopApps()
                if !topApps.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("TOP APPS")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                            .padding(.vertical, 10)
                        
                        ForEach(topApps, id: \.appName) { appData in
                            HStack {
                                Image(systemName: "app.fill")
                                    .foregroundColor(.indigo)
                                    .frame(width: 16)
                                Text(appData.appName)
                                    .font(.subheadline)
                                Spacer()
                                Text(formattedDurationShort(appData.duration))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 6)
                        }
                    }
                    .padding(.bottom, 8)
                    
                    Divider()
                }
            }
            
            // Footer Actions
            HStack {
                Button(action: {
                    withAnimation(GhostUI.gentleSpring) {
                        isTracking.toggle()
                        ActivityTrackingService.shared.isTrackingEnabled = isTracking
                    }
                }) {
                    Text(isTracking ? "Silence" : "Resume")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .contentTransition(.interpolate)
                }
                .buttonStyle(.plain)
                .foregroundColor(isTracking ? .secondary : .green)
                .hoverScaleEffect()
                
                Spacer()
                
                Button(action: openAppToRecall) {
                    HStack(spacing: 4) {
                        Image(systemName: "magnifyingglass")
                        Text("Search")
                    }
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
                .hoverScaleEffect()
                
                Spacer()
                
                Button(action: openAppToTimeline) {
                    Text("Open Ghost")
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.indigo.opacity(0.1))
                        .foregroundColor(.indigo)
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .hoverScaleEffect()
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
            
            // Shortcut hints
            HStack(spacing: 12) {
                Spacer()
                HStack(spacing: 4) {
                    Text("Recovery")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    GhostShortcutHint(keys: "⌘⇧R")
                }
                HStack(spacing: 4) {
                    Text("Recall")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    GhostShortcutHint(keys: "⌘⇧F")
                }
                Spacer()
            }
            .padding(.bottom, 8)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(width: 280)
        .onAppear {
            isTracking = ActivityTrackingService.shared.isTrackingEnabled
        }
    }
    
    @Environment(\.openWindow) private var openWindow

    private func openAppToTimeline() {
        activateApp()
    }
    
    private func openAppToRecall() {
        activateApp()
        // Allow time for app to open before posting notification
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NotificationCenter.default.post(name: .ghostNavigateToRecall, object: nil)
        }
    }
    
    private func activateApp() {
        NSApp.activate(ignoringOtherApps: true)
        openWindow(id: "mainWindow")
    }
    
    private var ghostState: GhostPresenceState {
        if !isTracking { return .idle }
        
        if let latest = events.first {
            // If the latest event was within the last 10 seconds, consider it "captured"
            if Date().timeIntervalSince(latest.timestamp) < 10 {
                return .captured
            }
        }
        
        return .watching
    }
    
    private func calculateTopApps() -> [(appName: String, duration: TimeInterval)] {
        let todaySessions = sessions.filter { Calendar.current.isDateInToday($0.startTime) }
        var dict: [String: TimeInterval] = [:]
        for session in todaySessions {
            dict[session.appName, default: 0] += session.duration
        }
        return dict.map { (appName: $0.key, duration: $0.value) }
            .sorted { $0.duration > $1.duration }
            .prefix(3)
            .map { $0 }
    }
    
    private func formattedDurationLong(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    private func formattedDurationShort(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }
}
