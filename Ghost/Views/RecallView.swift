import SwiftUI
import SwiftData

struct RecallView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel: RecallViewModel
    @State private var selectedEvent: RecallResult?
    @State private var operationToConfirm: RecoveryOperation?
    @State private var successMessage: String?
    
    private let recoveryService: RecoveryService
    
    init(modelContainer: ModelContainer, recoveryService: RecoveryService) {
        _viewModel = StateObject(wrappedValue: RecallViewModel(modelContainer: modelContainer))
        self.recoveryService = recoveryService
    }
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                if viewModel.searchText.isEmpty {
                    RecallEmptyStateView()
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                } else if viewModel.isSearching {
                    SearchingStateView()
                        .transition(.opacity)
                } else if viewModel.results.isEmpty {
                    ContentUnavailableView("No Results", systemImage: "magnifyingglass", description: Text("Ghost couldn't find any memory of that."))
                        .transition(.opacity)
                } else {
                    List {
                        ForEach(Array(viewModel.results.enumerated()), id: \.element.id) { index, group in
                            Group {
                                if group.events.count == 1 {
                                    RecallEventRowView(event: group.events.first!, recoveryService: recoveryService) { event in
                                        selectedEvent = event
                                    } onRecover: { event in
                                        recoverEvent(event)
                                    }
                                } else {
                                    DisclosureGroup {
                                        ForEach(group.events) { event in
                                            RecallEventRowView(event: event, recoveryService: recoveryService) { e in
                                                selectedEvent = e
                                            } onRecover: { event in
                                                recoverEvent(event)
                                            }
                                            .padding(.leading)
                                            .transition(.move(edge: .top).combined(with: .opacity))
                                        }
                                    } label: {
                                        RecallGroupedEventRowView(group: group)
                                    }
                                }
                            }
                            .animation(GhostUI.motionAnimation(GhostUI.memoryAppear.delay(Double(index) * 0.05)), value: viewModel.results.count)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                    .listStyle(.plain)
                    .transition(.opacity)
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
        .navigationTitle("Recall")
        .searchable(text: $viewModel.searchText, prompt: "Search your Mac's memory...")
        .animation(GhostUI.gentleSpring, value: viewModel.searchText.isEmpty)
        .animation(.easeInOut(duration: 0.3), value: viewModel.isSearching)
        .animation(GhostUI.gentleSpring, value: viewModel.results.isEmpty)
        .sheet(item: $selectedEvent) { event in
            if let path = event.newPath ?? event.oldPath {
                FileHistoryView(path: path)
            } else {
                Text("No file history available")
                    .padding()
            }
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
    
    private func recoverEvent(_ event: RecallResult) {
        let operation = recoveryService.validate(event: event)
        if operation.state == .unsupported || operation.state == .fileMissing || operation.state == .destinationMissing {
            return
        }
        operationToConfirm = operation
    }
}

// MARK: - Searching State

struct SearchingStateView: View {
    @State private var isPulsing = false
    @State private var dotPhase = 0
    
    let dotTimer = Timer.publish(every: 0.4, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "brain")
                .font(.system(size: 40))
                .foregroundColor(.indigo)
                .scaleEffect(isPulsing ? 1.08 : 0.92)
                .opacity(isPulsing ? 1.0 : 0.6)
                .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isPulsing)
                .onAppear { isPulsing = true }
            
            Text("Searching memory...")
                .font(.headline)
                .foregroundColor(.secondary)
            
            // Animated dots
            HStack(spacing: 12) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(Color.indigo.opacity(dotPhase == i ? 0.8 : 0.2))
                        .frame(width: 6, height: 6)
                        .scaleEffect(dotPhase == i ? 1.3 : 1.0)
                        .animation(.easeInOut(duration: 0.3), value: dotPhase)
                }
            }
            .onReceive(dotTimer) { _ in
                dotPhase = (dotPhase + 1) % 3
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Recall Empty State

struct RecallEmptyStateView: View {
    @State private var isFloating = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 60))
                .foregroundColor(.indigo)
                .padding(.bottom, 8)
                .offset(y: isFloating && !reduceMotion ? -5 : 5)
                .animation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true), value: isFloating)
                .onAppear { isFloating = true }
            
            Text("Search your Mac's memory.")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Ghost uses its local memory to find exactly what you're looking for.")
                .font(.title3)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Try searching for:")
                    .font(.headline)
                    .padding(.top)
                
                SuggestionLabel(text: "What did I do yesterday?", delay: 0.1)
                SuggestionLabel(text: "What did I rename this morning?", delay: 0.15)
                SuggestionLabel(text: "Where did project.mov go?", delay: 0.2)
                SuggestionLabel(text: "Around 3 PM", delay: 0.25)
            }
            .padding(.top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct SuggestionLabel: View {
    let text: String
    let delay: Double
    @State private var appear = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            Text(text)
                .foregroundColor(.primary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .ghostCardStyle()
        .hoverScaleEffect()
        .opacity(appear || reduceMotion ? 1 : 0)
        .offset(y: appear || reduceMotion ? 0 : 10)
        .onAppear {
            if !reduceMotion {
                withAnimation(GhostUI.gentleSpring.delay(delay)) {
                    appear = true
                }
            }
        }
    }
}

// MARK: - Recall Event Row

struct RecallEventRowView: View {
    let event: RecallResult
    let recoveryService: RecoveryService
    let onSelect: (RecallResult) -> Void
    let onRecover: (RecallResult) -> Void
    @State private var isHovered = false
    
    private var isRecoverable: Bool {
        (event.eventType == .fileRenamed || event.eventType == .fileMoved) &&
        event.confidence == .high &&
        event.oldPath != nil && event.newPath != nil &&
        !event.isRecovery
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: event.eventType.icon)
                .font(.title2)
                .foregroundColor(event.eventType.color)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.headline)
                
                if let details = event.details {
                    Text(details)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 6) {
                Text(event.timestamp, format: Date.FormatStyle(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 6) {
                    if event.newPath != nil || event.oldPath != nil {
                        Button(action: { onSelect(event) }) {
                            HStack(spacing: 3) {
                                Image(systemName: "clock.arrow.circlepath")
                                    .font(.caption2)
                                Text("History")
                                    .font(.caption)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(isHovered ? Color.secondary.opacity(0.08) : Color.clear)
                            .cornerRadius(5)
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.secondary)
                    }
                    
                    if isRecoverable {
                        GhostRecoveryBadge(label: "Recover") {
                            onRecover(event)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .onHover { hovering in
            withAnimation(GhostUI.quickSpring) {
                isHovered = hovering
            }
        }
    }
}

struct RecallGroupedEventRowView: View {
    let group: RecallResultGroup
    
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: group.eventType.icon)
                .font(.title3)
                .foregroundColor(group.eventType.color)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("\(group.events.count) Items")
                    .font(.headline)
                
                if let first = group.events.first, let last = group.events.last {
                    Text("\(last.timestamp, format: .dateTime.hour().minute()) - \(first.timestamp, format: .dateTime.hour().minute())")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
