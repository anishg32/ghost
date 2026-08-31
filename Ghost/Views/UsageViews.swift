import SwiftUI
import SwiftData

// MARK: - Usage Dashboard

struct UsageDashboardView: View {
    @Query private var allSessions: [AppUsageSession]
    @AppStorage("ghost_showInsights") private var showInsights = true
    
    // Default to today
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            let todaySessions = allSessions.filter { Calendar.current.isDateInToday($0.startTime) }
            let totalDuration = todaySessions.reduce(0) { $0 + $1.duration }
            
            // Total Active Time
            HStack(alignment: .lastTextBaseline, spacing: 6) {
                Text(formattedDurationLong(totalDuration))
                    .font(.system(size: 28, weight: .bold))
                Text("active app usage today")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 24)
            
            // Top Apps Bar Chart
            let topApps = calculateTopApps(from: todaySessions, limit: 5)
            if !topApps.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("APP USAGE")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 24)
                    
                    VStack(spacing: 8) {
                        ForEach(topApps, id: \.appName) { appData in
                            AppUsageBarRow(appData: appData, maxDuration: topApps.first?.duration ?? 1)
                        }
                    }
                    .padding(.horizontal, 24)
                }
            }
            
            // Insights
            if showInsights {
                GhostInsightsView(sessions: todaySessions, topApps: topApps)
                    .padding(.horizontal, 24)
            }
        }
        .padding(.vertical, 16)
    }
    
    private func calculateTopApps(from sessions: [AppUsageSession], limit: Int) -> [(appName: String, duration: TimeInterval)] {
        var dict: [String: TimeInterval] = [:]
        for session in sessions {
            dict[session.appName, default: 0] += session.duration
        }
        return dict.map { (appName: $0.key, duration: $0.value) }
            .sorted { $0.duration > $1.duration }
            .prefix(limit)
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
}

struct AppUsageBarRow: View {
    let appData: (appName: String, duration: TimeInterval)
    let maxDuration: TimeInterval
    
    @State private var isHovered = false
    @State private var showDetails = false
    
    var body: some View {
        Button(action: { showDetails = true }) {
            HStack(spacing: 12) {
                // We'd use a real app icon here, but NSWorkspace.shared.icon(forFile:) is expensive to run on the main thread for all apps.
                // We'll use a generic icon for now or an async loader in a real app.
                Image(systemName: "app.fill")
                    .foregroundColor(.indigo.opacity(0.8))
                    .frame(width: 20)
                
                Text(appData.appName)
                    .font(.subheadline)
                    .frame(width: 100, alignment: .leading)
                
                Text(formattedDuration(appData.duration))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 50, alignment: .leading)
                
                // Bar
                GeometryReader { geo in
                    let ratio = maxDuration > 0 ? (appData.duration / maxDuration) : 0
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.indigo.opacity(0.2))
                        .frame(width: max(geo.size.width * CGFloat(ratio), 4))
                }
                .frame(height: 8)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(isHovered ? Color.secondary.opacity(0.08) : Color.clear)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(GhostUI.quickSpring) {
                isHovered = hovering
            }
        }
        .sheet(isPresented: $showDetails) {
            AppUsageDetailView(appName: appData.appName)
        }
    }
    
    private func formattedDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - Ghost Insights

struct GhostInsightsView: View {
    let sessions: [AppUsageSession]
    let topApps: [(appName: String, duration: TimeInterval)]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.yellow)
                Text("GHOST INSIGHTS")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                if let top = topApps.first {
                    Text("You used **\(top.appName)** most today. \(formattedDuration(top.duration)) total.")
                }
                
                if let mostActivePeriod = calculateMostActivePeriod() {
                    Text("Your most active period was **\(mostActivePeriod)**.")
                }
                
                if let scatteredApp = calculateMostScatteredApp() {
                    Text("You opened **\(scatteredApp.appName)** across \(scatteredApp.sessions) separate sessions today.")
                }
            }
            .font(.subheadline)
            .padding(16)
            .ghostCardStyle()
        }
    }
    
    private func formattedDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }
    
    private func calculateMostActivePeriod() -> String? {
        // Simple binning into hours
        var hourlyBins: [Int: TimeInterval] = [:]
        for session in sessions {
            let hour = Calendar.current.component(.hour, from: session.startTime)
            hourlyBins[hour, default: 0] += session.duration
        }
        
        guard let topHour = hourlyBins.max(by: { $0.value < $1.value })?.key else { return nil }
        
        let startFormat = topHour > 12 ? "\(topHour - 12) PM" : (topHour == 12 ? "12 PM" : "\(topHour == 0 ? 12 : topHour) AM")
        let endHour = (topHour + 1) % 24
        let endFormat = endHour > 12 ? "\(endHour - 12) PM" : (endHour == 12 ? "12 PM" : "\(endHour == 0 ? 12 : endHour) AM")
        
        return "\(startFormat) – \(endFormat)"
    }
    
    private func calculateMostScatteredApp() -> (appName: String, sessions: Int)? {
        var counts: [String: Int] = [:]
        for session in sessions {
            counts[session.appName, default: 0] += 1
        }
        if let top = counts.filter({ $0.value > 3 }).max(by: { $0.value < $1.value }) {
            return (top.key, top.value)
        }
        return nil
    }
}

// MARK: - App Usage Detail View

struct AppUsageDetailView: View {
    let appName: String
    @Environment(\.dismiss) private var dismiss
    @Query private var allSessions: [AppUsageSession]
    @Query private var allEvents: [ActivityEvent]
    
    init(appName: String) {
        self.appName = appName
        // We'll filter in memory for simplicity in this demo, though a predicate is better
    }
    
    var body: some View {
        let sessions = allSessions.filter { $0.appName == appName && Calendar.current.isDateInToday($0.startTime) }.sorted(by: { $0.startTime > $1.startTime })
        let totalDuration = sessions.reduce(0) { $0 + $1.duration }
        let relatedEvents = allEvents.filter { event in
            Calendar.current.isDateInToday(event.timestamp) &&
            sessions.contains { session in
                event.timestamp >= session.startTime && event.timestamp <= session.endTime
            }
        }.sorted(by: { $0.timestamp > $1.timestamp })
        
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "app.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.indigo)
                        
                        Text(appName)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        HStack(spacing: 16) {
                            VStack {
                                Text("Today")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(formattedDurationLong(totalDuration))
                                    .fontWeight(.medium)
                            }
                            Divider().frame(height: 30)
                            VStack {
                                Text("Sessions")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("\(sessions.count)")
                                    .fontWeight(.medium)
                            }
                        }
                        .padding(.top, 8)
                    }
                    .padding(.top, 30)
                    
                    // Sessions List
                    VStack(alignment: .leading, spacing: 12) {
                        Text("SESSIONS TODAY")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 4)
                        
                        ForEach(sessions) { session in
                            HStack {
                                Text(session.startTime, format: .dateTime.hour().minute())
                                    .font(.subheadline)
                                    .frame(width: 70, alignment: .leading)
                                
                                Text(formattedDuration(session.duration))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .ghostCardStyle()
                        }
                    }
                    .padding(.horizontal, 30)
                    
                    // Related Memories
                    if !relatedEvents.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("RELATED MEMORY")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 4)
                            
                            ForEach(relatedEvents) { event in
                                HStack(spacing: 12) {
                                    Text(event.timestamp, format: .dateTime.hour().minute())
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .frame(width: 50, alignment: .leading)
                                    
                                    Image(systemName: event.eventType.icon)
                                        .foregroundColor(event.eventType.color)
                                    
                                    Text(event.title)
                                        .font(.subheadline)
                                    
                                    Spacer()
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .background(Color.secondary.opacity(0.05))
                                .cornerRadius(8)
                            }
                        }
                        .padding(.horizontal, 30)
                        .padding(.top, 10)
                    }
                    
                    Spacer(minLength: 30)
                }
                .frame(maxWidth: .infinity)
            }
            .navigationTitle("\(appName) Usage")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .frame(width: 450, height: 550)
    }
    
    private func formattedDurationLong(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }
    
    private func formattedDuration(_ duration: TimeInterval) -> String {
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60
        if duration >= 3600 {
            let hours = Int(duration) / 3600
            return "\(hours)h \(minutes)m"
        }
        if minutes > 0 { return "\(minutes)m \(seconds)s" }
        return "\(seconds)s"
    }
}

// MARK: - Customize Settings View

struct CustomizeGhostView: View {
    @Environment(\.dismiss) private var dismiss
    
    @AppStorage("ghost_showActivityGraph") private var showActivityGraph = true
    @AppStorage("ghost_showAppUsage") private var showAppUsage = true
    @AppStorage("ghost_showInsights") private var showInsights = true
    @AppStorage("ghost_showMemoryStream") private var showMemoryStream = true
    
    @AppStorage("ghost_menuStatus") private var menuStatus = true
    @AppStorage("ghost_menuLatestMemory") private var menuLatestMemory = true
    @AppStorage("ghost_menuTopApps") private var menuTopApps = true
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Activity Pulse Graph", isOn: $showActivityGraph)
                    Toggle("App Usage Dashboard", isOn: $showAppUsage)
                    Toggle("Ghost Insights", isOn: $showInsights)
                    Toggle("Memory Stream", isOn: $showMemoryStream)
                } header: {
                    Text("Timeline")
                        .font(.headline)
                }
                
                Section {
                    Toggle("Status & Total Time", isOn: $menuStatus)
                    Toggle("Latest Memory", isOn: $menuLatestMemory)
                    Toggle("Top Apps", isOn: $menuTopApps)
                } header: {
                    Text("Menu Bar")
                        .font(.headline)
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Customize Ghost")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .frame(width: 350, height: 400)
    }
}
