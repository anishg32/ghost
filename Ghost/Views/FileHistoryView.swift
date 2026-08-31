import SwiftUI
import SwiftData

struct FileHistoryView: View {
    let path: String
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var events: [RecallResult] = []
    @State private var isLoading = true
    
    var body: some View {
        NavigationStack {
            VStack {
                if isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Tracing history...")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(.opacity)
                } else if events.isEmpty {
                    ContentUnavailableView("No History", systemImage: "clock.arrow.circlepath", description: Text("Ghost couldn't find any history for this file."))
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    List {
                        ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                            FileHistoryRow(event: event)
                                .animation(GhostUI.motionAnimation(GhostUI.gentleSpring.delay(Double(index) * 0.05)), value: events.count)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                    .listStyle(.plain)
                    .transition(.opacity)
                }
            }
            .animation(GhostUI.gentleSpring, value: isLoading)
            .animation(GhostUI.gentleSpring, value: events.isEmpty)
            .navigationTitle(URL(fileURLWithPath: path).lastPathComponent)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button("Reveal in Finder") {
                        NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "")
                    }
                }
            }
            .task {
                await loadHistory()
            }
        }
        .frame(width: 500, height: 400)
    }
    
    private func loadHistory() async {
        let container = modelContext.container
        let targetPath = path
        
        let service = RecallSearchService(modelContainer: container)
        // This now correctly uses the path-chaining algorithm inside RecallSearchService
        let history = await service.fileHistory(for: targetPath)
        
        // Add a slight delay so the loading animation is visible and feels intentional
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        await MainActor.run {
            self.events = history
            self.isLoading = false
        }
    }
}

struct FileHistoryRow: View {
    let event: RecallResult
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: event.eventType.icon)
                .font(.title3)
                .foregroundColor(event.eventType.color)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.headline)
                
                if let details = event.details {
                    Text(details)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            Text(event.timestamp, format: Date.FormatStyle(date: .abbreviated, time: .shortened))
                .font(.caption2)
                .foregroundColor(Color(NSColor.tertiaryLabelColor))
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .ghostCardStyle()
        .hoverScaleEffect()
        .padding(.vertical, 4)
    }
}

