import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selection: SidebarItem? = .timeline

    enum SidebarItem: Hashable {
        case timeline
        case recall
        case recovery
        case silence
        case settings
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                // Refined Header
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Image(systemName: "ghost.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.indigo)
                        Text("Ghost")
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                    .padding(.vertical, 8)
                }
                .listRowBackground(Color.clear)
                
                Section {
                    NavigationLink(value: SidebarItem.timeline) {
                        Label("Timeline", systemImage: "clock")
                    }
                    NavigationLink(value: SidebarItem.recall) {
                        Label("Recall", systemImage: "magnifyingglass")
                    }
                    NavigationLink(value: SidebarItem.recovery) {
                        HStack {
                            Label("Recovery", systemImage: "arrow.uturn.backward")
                            Spacer()
                            GhostShortcutHint(keys: "⌘⇧R")
                        }
                    }
                    NavigationLink(value: SidebarItem.silence) {
                        Label("Silence", systemImage: "bell.slash")
                    }
                }
                
                Section {
                    NavigationLink(value: SidebarItem.settings) {
                        Label("Settings", systemImage: "gear")
                    }
                }
            }
            .navigationTitle("") // Hide default title since we have a custom header
            .listStyle(.sidebar)
            .animation(GhostUI.gentleSpring, value: selection)
        } detail: {
            let repository = ActivityEventRepository(modelContainer: modelContext.container)
            let recoveryService = RecoveryService(repository: repository)
            
            switch selection {
            case .timeline:
                GhostTimelineView(recoveryService: recoveryService)
            case .recall:
                RecallView(modelContainer: modelContext.container, recoveryService: recoveryService)
            case .recovery:
                RecoveryView(modelContainer: modelContext.container, repository: repository)
            case .silence:
                SilenceView()
            case .settings:
                SettingsView()
            case .none:
                Text("Select an item")
            }
        }
        .frame(minWidth: 800, minHeight: 600)
        .onReceive(NotificationCenter.default.publisher(for: .ghostNavigateToRecovery)) { _ in
            withAnimation(GhostUI.gentleSpring) {
                selection = .recovery
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .ghostNavigateToRecall)) { _ in
            withAnimation(GhostUI.gentleSpring) {
                selection = .recall
            }
        }
    }
}

#Preview {
    ContentView()
}
