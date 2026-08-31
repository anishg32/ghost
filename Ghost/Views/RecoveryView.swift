import SwiftUI
import SwiftData

struct RecoveryView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel: RecoveryViewModel
    
    @State private var operationToConfirm: RecoveryOperation?
    @State private var isShowingSearch = false
    @State private var successMessage: String?
    
    init(modelContainer: ModelContainer, repository: ActivityEventRepository) {
        _viewModel = StateObject(wrappedValue: RecoveryViewModel(modelContainer: modelContainer, repository: repository))
    }
    
    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 30) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "arrow.uturn.backward.circle")
                            .font(.system(size: 50))
                            .foregroundColor(.blue)
                        
                        Text("Recovery")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Did something go wrong?")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 40)
                    
                    // Main Actions
                    VStack(spacing: 12) {
                        Button(action: {
                            isShowingSearch = true
                        }) {
                            HStack {
                                Image(systemName: "magnifyingglass")
                                    .frame(width: 30)
                                Text("I can't find something")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .ghostCardStyle()
                            .hoverScaleEffect()
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 40)
                    
                    // Suggestions
                    if viewModel.recentRenames.isEmpty && viewModel.recentMoves.isEmpty {
                        VStack(spacing: 16) {
                            Text("🎉")
                                .font(.system(size: 40))
                            Text("Nothing needs recovering right now.")
                                .font(.headline)
                            Text("Recent supported changes will appear here.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 30)
                    } else {
                        if !viewModel.recentRenames.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("RECENT CHANGES")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 40)
                                
                                ForEach(viewModel.recentRenames) { event in
                                    RecoverySuggestionCard(event: event) {
                                        validateAndConfirm(event: event)
                                    }
                                }
                            }
                        }
                        
                        if !viewModel.recentMoves.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                if viewModel.recentRenames.isEmpty {
                                    Text("RECENT CHANGES")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal, 40)
                                }
                                
                                ForEach(viewModel.recentMoves) { event in
                                    RecoverySuggestionCard(event: event) {
                                        validateAndConfirm(event: event)
                                    }
                                }
                            }
                        }
                    }
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }
            .blur(radius: successMessage == nil ? 0 : 10)
            .opacity(successMessage == nil ? 1 : 0.5)
            
            if let msg = successMessage {
                RecoverySuccessView(message: msg)
                    .zIndex(1)
            }
        }
        .animation(GhostUI.gentleSpring, value: successMessage)
        .onAppear {
            viewModel.loadRecentSuggestions()
        }
        .sheet(item: $operationToConfirm) { operation in
            RecoveryConfirmationSheet(operation: operation, service: viewModel.recoveryService) { success in
                operationToConfirm = nil
                if success {
                    let oldName = URL(fileURLWithPath: operation.targetPath).lastPathComponent
                    let newName = URL(fileURLWithPath: operation.destinationPath).lastPathComponent
                    successMessage = "\(oldName) → \(newName)"
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                        withAnimation(GhostUI.smoothFade) {
                            successMessage = nil
                            viewModel.loadRecentSuggestions()
                        }
                    }
                } else {
                    viewModel.loadRecentSuggestions()
                }
            }
        }
        .sheet(isPresented: $isShowingSearch) {
            NavigationStack {
                RecallView(modelContainer: modelContext.container)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") { isShowingSearch = false }
                        }
                    }
            }
            .frame(width: 600, height: 500)
        }
    }
    
    private func validateAndConfirm(event: RecallResult) {
        let operation = viewModel.recoveryService.validate(event: event)
        self.operationToConfirm = operation
    }
}

struct RecoverySuccessView: View {
    let message: String
    
    @State private var phase = 0 // 0: initial, 1: show text, 2: show checkmark
    
    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Image(systemName: "ghost.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.indigo)
                    .opacity(phase == 0 ? 1 : 0)
                    .scaleEffect(phase == 0 ? 1 : 0.8)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.green)
                    .opacity(phase == 2 ? 1 : 0)
                    .scaleEffect(phase == 2 ? 1 : 0.5)
            }
            .frame(height: 60)
            
            Text("Restored successfully")
                .font(.title2)
                .fontWeight(.bold)
                .opacity(phase >= 1 ? 1 : 0)
                .offset(y: phase >= 1 ? 0 : 10)
            
            if let target = message.components(separatedBy: "→").first, let dest = message.components(separatedBy: "→").last {
                VStack(spacing: 8) {
                    Text(target.trimmingCharacters(in: .whitespacesAndNewlines))
                        .foregroundColor(.secondary)
                    Image(systemName: "arrow.down")
                    Text(dest.trimmingCharacters(in: .whitespacesAndNewlines))
                        .fontWeight(.bold)
                }
                .padding()
                .ghostCardStyle()
                .opacity(phase >= 1 ? 1 : 0)
                .offset(y: phase >= 1 ? 0 : 10)
            }
        }
        .padding(40)
        .background(Material.regular)
        .cornerRadius(20)
        .shadow(radius: 20)
        .onAppear {
            withAnimation(GhostUI.gentleSpring.delay(0.2)) {
                phase = 1
            }
            withAnimation(GhostUI.gentleSpring.delay(1.0)) {
                phase = 2
            }
        }
    }
}

struct RecoverySuggestionCard: View {
    let event: RecallResult
    let onRecover: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(event.newPath != nil ? URL(fileURLWithPath: event.newPath!).lastPathComponent : event.title)
                    .font(.headline)
                
                if let details = event.details {
                    Text(details)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text(event.timestamp, format: Date.FormatStyle(time: .shortened))
                    .font(.caption2)
                    .foregroundColor(Color(NSColor.tertiaryLabelColor))
            }
            
            Spacer()
            
            Button(action: onRecover) {
                Text(event.eventType == .fileRenamed ? "Restore Previous Name" : "Move Back")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .tint(.blue)
        }
        .padding()
        .ghostCardStyle()
        .hoverScaleEffect()
        .padding(.horizontal, 40)
    }
}

struct RecoveryConfirmationSheet: View {
    let operation: RecoveryOperation
    let service: RecoveryService
    let onDismiss: (Bool) -> Void
    
    @State private var isExecuting = false
    
    var body: some View {
        VStack(spacing: 20) {
            if isExecuting {
                VStack(spacing: 16) {
                    ProgressView()
                    Text("Recovering...")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.opacity)
            } else {
                switch operation.state {
                case .ready:
                    Text("Confirm Recovery")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    let isRename = operation.event.eventType == .fileRenamed
                    Text(isRename ? "Restore previous file name?" : "Move file back?")
                    
                    VStack(spacing: 8) {
                        Text(operation.targetPath)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                        Image(systemName: "arrow.down")
                        Text(operation.destinationPath)
                            .font(.caption)
                            .fontWeight(.bold)
                            .lineLimit(2)
                    }
                    .padding()
                    .background(Color(NSColor.windowBackgroundColor))
                    .cornerRadius(8)
                    
                    HStack {
                        Button("Cancel") { onDismiss(false) }
                            .keyboardShortcut(.escape, modifiers: [])
                        
                        Button(isRename ? "Restore" : "Move Back") {
                            execute(resolution: .cancel) // No conflict
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)
                    }
                    
                case .conflict(let existingName):
                    Text("File Conflict")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                    
                    Text("A file named **\(existingName)** already exists at the destination.")
                        .multilineTextAlignment(.center)
                    
                    VStack(spacing: 12) {
                        Button("Rename Recovered File") {
                            execute(resolution: .renameRecovered)
                        }
                        .buttonStyle(.bordered)
                        
                        Button("Replace Existing File", role: .destructive) {
                            execute(resolution: .replace)
                        }
                        .buttonStyle(.bordered)
                        
                        Button("Cancel") { onDismiss(false) }
                            .keyboardShortcut(.escape, modifiers: [])
                    }
                    
                case .fileMissing:
                    Text("File Missing")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("This file is no longer at the expected location.")
                    Button("Close") { onDismiss(false) }
                    
                case .destinationMissing:
                    Text("Destination Missing")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("The original location is no longer available.")
                    Button("Close") { onDismiss(false) }
                    
                case .unsupported:
                    Text("Unsupported Action")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Ghost cannot recover this type of event.")
                    Button("Close") { onDismiss(false) }
                }
            }
        }
        .padding(30)
        .frame(width: 450, height: 300)
        .animation(GhostUI.gentleSpring, value: isExecuting)
    }
    
    private func execute(resolution: RecoveryService.ConflictResolution) {
        isExecuting = true
        Task {
            let success = await service.execute(operation: operation, resolution: resolution)
            await MainActor.run {
                if success {
                    onDismiss(true)
                } else {
                    isExecuting = false
                    onDismiss(false)
                }
            }
        }
    }
}

extension RecoveryOperation: Identifiable {
    var id: UUID { event.id }
}
