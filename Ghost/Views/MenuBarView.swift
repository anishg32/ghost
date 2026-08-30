import SwiftUI
import SwiftData

struct MenuBarView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ActivityEvent.timestamp, order: .reverse) private var events: [ActivityEvent]
    
    // We can also bind to the tracking service state, but for UI sake, we'll use a timer or just assume Tracking.
    // If we want real state: ActivityTrackingService.shared.isTrackingEnabled
    @State private var isTracking: Bool = ActivityTrackingService.shared.isTrackingEnabled
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("👻 Ghost")
                    .font(.headline)
                Spacer()
                HStack(spacing: 4) {
                    Circle()
                        .fill(isTracking ? Color.green : Color.orange)
                        .frame(width: 8, height: 8)
                    Text(isTracking ? "Tracking" : "Paused")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            
            // Today Summary
            VStack(alignment: .leading, spacing: 8) {
                Text("Today")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                
                ActivityPulseGraph(events: events)
                    .padding(.bottom, 4)
                
                let todayCount = events.filter { Calendar.current.isDateInToday($0.timestamp) }.count
                Text("\(todayCount) actions remembered today")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            .padding(.bottom, 12)
            
            Divider()
            
            // Recent Activity
            VStack(alignment: .leading, spacing: 0) {
                Text("Recent")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                
                if events.isEmpty {
                    Text("No recent activity.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                } else {
                    ForEach(events.prefix(3)) { event in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: event.eventType.icon)
                                .foregroundColor(event.eventType.color)
                                .frame(width: 20)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(event.title)
                                    .font(.subheadline)
                                    .lineLimit(1)
                                
                                Text(event.timestamp, format: .relative(presentation: .numeric))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 6)
                        .background(Color.primary.opacity(0.001)) // make row clickable if needed
                    }
                }
            }
            
            Divider().padding(.top, 4)
            
            // Footer Actions
            HStack {
                Button(action: {
                    isTracking.toggle()
                    ActivityTrackingService.shared.isTrackingEnabled = isTracking
                }) {
                    Text(isTracking ? "Pause Tracking" : "Resume Tracking")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                
                Spacer()
                
                Button(action: openAppToRecall) {
                    HStack(spacing: 4) {
                        Image(systemName: "magnifyingglass")
                        Text("Search")
                    }
                    .font(.caption)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Button(action: openAppToTimeline) {
                    Text("Open Ghost")
                        .font(.caption)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(width: 320)
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
    }
    
    private func activateApp() {
        NSApp.activate(ignoringOtherApps: true)
        openWindow(id: "mainWindow")
    }
}
