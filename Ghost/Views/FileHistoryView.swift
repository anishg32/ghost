import SwiftUI
import SwiftData

struct FileHistoryView: View {
    let path: String
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var events: [RecallResult] = []
    @State private var isLoading = true
    @State private var operationToConfirm: RecoveryOperation? = nil
    @State private var successMessage: String? = nil
    
    var body: some View {
        NavigationStack {
            ZStack {
                VStack {
                    if isLoading {
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.2)
                            Text("Tracing history...")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .transition(.opacity)
                    } else if events.isEmpty {
                        GhostEmptyState(
                            icon: "clock.arrow.circlepath",
                            title: "No History",
                            subtitle: "Ghost couldn't find any history for this file."
                        )
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    } else {
                        fileHistoryTimeline
                            .transition(.opacity)
                    }
                }
                .blur(radius: successMessage == nil ? 0 : 8)
                .opacity(successMessage == nil ? 1 : 0.5)
                
                if let msg = successMessage {
                    RecoverySuccessView(message: msg)
                        .zIndex(1)
                }
            }
            .animation(GhostUI.gentleSpring, value: successMessage)
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
            .sheet(item: $operationToConfirm) { operation in
                RecoveryConfirmationSheet(operation: operation, service: makeRecoveryService()) { success in
                    operationToConfirm = nil
                    if success {
                        let oldName = URL(fileURLWithPath: operation.targetPath).lastPathComponent
                        let newName = URL(fileURLWithPath: operation.destinationPath).lastPathComponent
                        successMessage = "\(oldName) → \(newName)"
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                            withAnimation(GhostUI.smoothFade) {
                                successMessage = nil
                            }
                            // Reload history after recovery
                            Task { await loadHistory() }
                        }
                    }
                }
            }
        }
        .frame(width: 520, height: 450)
    }
    
    // MARK: - Visual Timeline
    
    private var fileHistoryTimeline: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Current state header
                HStack(spacing: 10) {
                    GhostTimelineDot(size: 10, color: .indigo, isCurrent: true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("CURRENT")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.indigo)
                        Text(URL(fileURLWithPath: path).lastPathComponent)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                
                // Connector from current to first event
                if !events.isEmpty {
                    connectorLine()
                }
                
                // History entries
                ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                    VStack(spacing: 0) {
                        FileHistoryTimelineEntry(
                            event: event,
                            index: index,
                            total: events.count,
                            onRecover: { recoverFromHistory(event) }
                        )
                        
                        if index < events.count - 1 {
                            connectorLine(opacity: connectorOpacity(index: index))
                        }
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(
                        GhostUI.motionAnimation(GhostUI.memoryAppear.delay(Double(index) * 0.06)),
                        value: events.count
                    )
                }
                
                // Origin marker
                if !events.isEmpty {
                    connectorLine(opacity: 0.08)
                    HStack(spacing: 10) {
                        GhostTimelineDot(size: 8, color: .secondary.opacity(0.4))
                        Text("ORIGIN")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.secondary.opacity(0.5))
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)
                }
            }
        }
    }
    
    private func connectorLine(opacity: Double = 0.15) -> some View {
        HStack {
            Spacer().frame(width: 28)
            GhostTimelineConnector(height: 20, opacity: opacity)
            Spacer()
        }
    }
    
    private func connectorOpacity(index: Int) -> Double {
        let progress = Double(index) / Double(max(events.count - 1, 1))
        return 0.18 - (progress * 0.10)
    }
    
    // MARK: - Recovery
    
    private func makeRecoveryService() -> RecoveryService {
        let repository = ActivityEventRepository(modelContainer: modelContext.container)
        return RecoveryService(repository: repository)
    }
    
    private func recoverFromHistory(_ event: RecallResult) {
        let service = makeRecoveryService()
        let operation = service.validate(event: event)
        if operation.state == .unsupported || operation.state == .fileMissing || operation.state == .destinationMissing {
            return
        }
        operationToConfirm = operation
    }
    
    // MARK: - Data
    
    private func loadHistory() async {
        let container = modelContext.container
        let targetPath = path
        
        let service = RecallSearchService(modelContainer: container)
        let history = await service.fileHistory(for: targetPath)
        
        try? await Task.sleep(nanoseconds: 400_000_000)
        
        await MainActor.run {
            self.events = history
            self.isLoading = false
        }
    }
}

// MARK: - File History Timeline Entry

struct FileHistoryTimelineEntry: View {
    let event: RecallResult
    let index: Int
    let total: Int
    let onRecover: () -> Void
    
    @State private var isHovered = false
    
    private var isRecoverable: Bool {
        (event.eventType == .fileRenamed || event.eventType == .fileMoved) &&
        event.confidence == .high &&
        event.oldPath != nil && event.newPath != nil &&
        !event.isRecovery
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // Timeline dot
            GhostTimelineDot(
                size: GhostUI.connectorDotSize,
                color: event.eventType.color.opacity(dotOpacity)
            )
            .padding(.top, 8)
            
            // Event card
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: event.eventType.icon)
                        .font(.caption)
                        .foregroundColor(event.eventType.color)
                    
                    Text(event.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Text(relativeTime)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                // Path details
                if let oldPath = event.oldPath, let newPath = event.newPath {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 4) {
                            Text("From:")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(URL(fileURLWithPath: oldPath).lastPathComponent)
                                .font(.caption2)
                                .fontWeight(.medium)
                        }
                        HStack(spacing: 4) {
                            Text("To:")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(URL(fileURLWithPath: newPath).lastPathComponent)
                                .font(.caption2)
                                .fontWeight(.medium)
                        }
                    }
                }
                
                // Recovery action
                if isRecoverable && isHovered {
                    GhostRecoveryBadge(label: "Recover", action: onRecover)
                        .transition(.move(edge: .leading).combined(with: .opacity))
                }
            }
            .padding(10)
            .ghostCardStyle(isHighlighted: isHovered)
        }
        .padding(.horizontal, 24)
        .onHover { hovering in
            withAnimation(GhostUI.quickSpring) {
                isHovered = hovering
            }
        }
    }
    
    private var dotOpacity: Double {
        // Fade dots as they get older
        let progress = Double(index) / Double(max(total - 1, 1))
        return 1.0 - (progress * 0.4)
    }
    
    private var relativeTime: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: event.timestamp, relativeTo: Date())
    }
}
