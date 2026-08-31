import SwiftUI
import SwiftData

struct MenuBarView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ActivityEvent.timestamp, order: .reverse) private var events: [ActivityEvent]
    
    @State private var isTracking: Bool = ActivityTrackingService.shared.isTrackingEnabled
    @State private var pulseIndicator = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("👻 Ghost")
                    .font(.headline)
                Spacer()
                HStack(spacing: 6) {
                    Circle()
                        .fill(isTracking ? Color.green : Color.orange)
                        .frame(width: 8, height: 8)
                        .scaleEffect(isTracking && pulseIndicator ? 1.2 : 1.0)
                        .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: pulseIndicator)
                        .onAppear {
                            pulseIndicator = true
                        }
                    Text(isTracking ? "Tracking" : "Paused")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .contentTransition(.interpolate)
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
                HStack(spacing: 4) {
                    AnimatedNumberView(value: todayCount)
                    Text("actions remembered today")
                }
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
                        MenuBarEventRow(event: event)
                    }
                }
            }
            
            Divider().padding(.top, 4)
            
            // Footer Actions
            HStack {
                Button(action: {
                    withAnimation(GhostUI.gentleSpring) {
                        isTracking.toggle()
                        ActivityTrackingService.shared.isTrackingEnabled = isTracking
                    }
                }) {
                    Text(isTracking ? "Pause" : "Resume")
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

struct MenuBarEventRow: View {
    let event: ActivityEvent
    @State private var isHovered = false
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: event.eventType.icon)
                .foregroundColor(event.eventType.color)
                .frame(width: 20)
                .scaleEffect(isHovered ? 1.1 : 1.0)
            
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
        .background(isHovered ? Color.primary.opacity(0.05) : Color.clear)
        .onHover { hovering in
            withAnimation(GhostUI.quickSpring) {
                isHovered = hovering
            }
        }
    }
}

