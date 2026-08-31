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
    
    @State private var isBreathing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                if activeDuration != nil {
                    Circle()
                        .fill(GhostUI.quietZone)
                        .frame(width: 150, height: 150)
                        .scaleEffect(isBreathing && !reduceMotion ? 1.2 : 1.0)
                        .opacity(isBreathing && !reduceMotion ? 0.7 : 1.0)
                        .animation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true), value: isBreathing)
                }
                
                Image(systemName: activeDuration != nil ? "bell.slash.fill" : "bell.slash")
                    .font(.system(size: 60))
                    .foregroundColor(activeDuration != nil ? .secondary : .indigo)
                    .contentTransition(.symbolEffect(.replace))
            }
            .frame(height: 150)
            
            Text(activeDuration != nil ? "Silence active" : "Silence")
                .font(.largeTitle)
                .fontWeight(.bold)
                .contentTransition(.interpolate)
            
            if activeDuration != nil {
                VStack(spacing: 8) {
                    Text("Ghost is taking a break.")
                        .font(.title3)
                        .foregroundColor(.secondary)
                    
                    Text(formattedTime(remainingTime))
                        .font(.system(size: 40, weight: .bold, design: .monospaced))
                        .foregroundColor(.primary)
                        .contentTransition(.numericText())
                }
                .transition(.scale(scale: 0.9).combined(with: .opacity))
                
                Button(action: {
                    withAnimation(GhostUI.gentleSpring) {
                        activeDuration = nil
                        remainingTime = 0
                        isBreathing = false
                        ActivityTrackingService.shared.isTrackingEnabled = true
                    }
                }) {
                    Text("End Silence")
                        .font(.headline)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.secondary.opacity(0.15))
                        .foregroundColor(.primary)
                        .cornerRadius(12)
                }
                .buttonStyle(.plain)
                .hoverScaleEffect()
                .padding(.top, 20)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                Text("Temporarily disappear from distractions.")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .transition(.move(edge: .top).combined(with: .opacity))
                
                VStack(spacing: 16) {
                    Text("For how long?")
                        .font(.headline)
                    
                    HStack(spacing: 12) {
                        ForEach(durations, id: \.name) { duration in
                            Button(action: {
                                startSilence(duration.value)
                            }) {
                                Text(duration.name)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(Color(NSColor.controlBackgroundColor))
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color(NSColor.separatorColor).opacity(0.2), lineWidth: 0.5)
                                    )
                            }
                            .buttonStyle(.plain)
                            .hoverScaleEffect()
                        }
                    }
                }
                .padding(.top, 20)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(GhostUI.gentleSpring, value: activeDuration)
        .onReceive(timer) { _ in
            if activeDuration != nil {
                if remainingTime > 0 {
                    withAnimation(GhostUI.smoothFade) {
                        remainingTime -= 1
                    }
                } else {
                    withAnimation(GhostUI.gentleSpring) {
                        activeDuration = nil
                        isBreathing = false
                        ActivityTrackingService.shared.isTrackingEnabled = true
                    }
                }
            }
        }
    }
    
    private func startSilence(_ duration: TimeInterval) {
        withAnimation(GhostUI.gentleSpring) {
            activeDuration = duration
            remainingTime = duration
            ActivityTrackingService.shared.isTrackingEnabled = false
            isBreathing = true
        }
    }
    
    private func formattedTime(_ time: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
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
