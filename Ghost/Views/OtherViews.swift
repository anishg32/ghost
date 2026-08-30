import SwiftUI



struct SilenceView: View {
    @State private var activeDuration: TimeInterval?
    @State private var remainingTime: TimeInterval = 0
    let durations: [(name: String, value: TimeInterval)] = [
        ("10 min", 10 * 60),
        ("30 min", 30 * 60),
        ("1 hour", 60 * 60),
        ("2 hours", 120 * 60)
    ]
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: activeDuration != nil ? "bell.slash.fill" : "bell.slash")
                .font(.system(size: 60))
                .foregroundColor(activeDuration != nil ? .red : .indigo)
            
            Text(activeDuration != nil ? "Silence active" : "Silence")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            if activeDuration != nil {
                Text("Ends in \(formattedTime(remainingTime))")
                    .font(.title2)
                    .foregroundColor(.secondary)
                    .monospacedDigit()
                
                Button("End Silence") {
                    withAnimation {
                        activeDuration = nil
                        remainingTime = 0
                        ActivityTrackingService.shared.isTrackingEnabled = true
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(.red)
                .padding(.top, 20)
            } else {
                Text("Temporarily disappear from distractions.")
                    .font(.title3)
                    .foregroundColor(.secondary)
                
                VStack(spacing: 16) {
                    Text("For how long?")
                        .font(.headline)
                    
                    HStack(spacing: 12) {
                        ForEach(durations, id: \.name) { duration in
                            Button(duration.name) {
                                startSilence(duration.value)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
                .padding(.top, 20)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onReceive(timer) { _ in
            if activeDuration != nil {
                if remainingTime > 0 {
                    remainingTime -= 1
                } else {
                    withAnimation {
                        activeDuration = nil
                        ActivityTrackingService.shared.isTrackingEnabled = true
                    }
                }
            }
        }
    }
    
    private func startSilence(_ duration: TimeInterval) {
        withAnimation {
            activeDuration = duration
            remainingTime = duration
            ActivityTrackingService.shared.isTrackingEnabled = false
        }
    }
    
    private func formattedTime(_ time: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: time) ?? ""
    }
}

struct SettingsView: View {
    @State private var trackActivity = true
    @State private var retentionDays = 30
    
    var body: some View {
        Form {
            Section {
                Toggle("Track activity", isOn: $trackActivity)
                    .onChange(of: trackActivity) { newValue in
                        ActivityTrackingService.shared.isTrackingEnabled = newValue
                    }
                
                LabeledContent("Monitored folders") {
                    HStack {
                        Text("Desktop, Documents, Downloads")
                            .foregroundColor(.secondary)
                        Button("Edit") { }
                    }
                }
            } header: {
                Text("Tracking")
                    .font(.headline)
            }
            
            Section {
                Picker("Keep activity for", selection: $retentionDays) {
                    Text("24 hours").tag(1)
                    Text("7 days").tag(7)
                    Text("30 days").tag(30)
                    Text("90 days").tag(90)
                }
            } header: {
                Text("Privacy")
                    .font(.headline)
            }
            
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Activity history is stored entirely locally.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button("Delete All History...", role: .destructive) {
                        // In reality, this should present a confirmation dialog
                    }
                }
            } header: {
                Text("Data")
                    .font(.headline)
            }
        }
        .formStyle(.grouped)
        .padding()
        .navigationTitle("Settings")
        .frame(minWidth: 400, minHeight: 400)
    }
}
