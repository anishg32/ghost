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
                        Label("Recovery", systemImage: "arrow.uturn.backward")
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
            switch selection {
            case .timeline:
                TimelineView()
            case .recall:
                RecallView(modelContainer: modelContext.container)
            case .recovery:
                RecoveryView(modelContainer: modelContext.container, repository: ActivityEventRepository(modelContainer: modelContext.container))
            case .silence:
                SilenceView()
            case .settings:
                SettingsView()
            case .none:
                Text("Select an item")
            }
        }
        .frame(minWidth: 800, minHeight: 600)
    }
}

#Preview {
    ContentView()
}
