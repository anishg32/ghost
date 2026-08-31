import SwiftUI
import SwiftData

@main
struct GhostApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            ActivityEvent.self,
            AppUsageSession.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    init() {
        let repository = ActivityEventRepository(modelContainer: sharedModelContainer)
        ActivityTrackingService.shared.initialize(with: repository)
    }

    var body: some Scene {
        WindowGroup(id: "mainWindow") {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
        .commands {
            CommandGroup(after: .toolbar) {
                Button("Recovery") {
                    NotificationCenter.default.post(name: .ghostNavigateToRecovery, object: nil)
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])
                
                Button("Search Memory") {
                    NotificationCenter.default.post(name: .ghostNavigateToRecall, object: nil)
                }
                .keyboardShortcut("f", modifiers: [.command, .shift])
            }
        }
        
        MenuBarExtra("Ghost", systemImage: "ghost") {
            MenuBarView()
                .modelContainer(sharedModelContainer)
        }
        .menuBarExtraStyle(.window) // Allows for a custom view layout in the menu bar
    }
}

// MARK: - Navigation Notifications

extension Notification.Name {
    static let ghostNavigateToRecovery = Notification.Name("ghostNavigateToRecovery")
    static let ghostNavigateToRecall = Notification.Name("ghostNavigateToRecall")
}
