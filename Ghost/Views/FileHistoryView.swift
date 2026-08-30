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
                    ProgressView()
                } else if events.isEmpty {
                    ContentUnavailableView("No History", systemImage: "clock.arrow.circlepath", description: Text("Ghost couldn't find any history for this file."))
                } else {
                    List(events) { event in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: event.eventType.icon)
                                .foregroundColor(event.eventType.color)
                                .frame(width: 24)
                            
                            VStack(alignment: .leading) {
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
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
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
        
        await MainActor.run {
            self.events = history
            self.isLoading = false
        }
    }
}
