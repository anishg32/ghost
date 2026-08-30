import SwiftUI
import SwiftData

@main
struct GhostApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            ActivityEvent.self,
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
        
        MenuBarExtra("Ghost", systemImage: "ghost") {
            MenuBarView()
                .modelContainer(sharedModelContainer)
        }
        .menuBarExtraStyle(.window) // Allows for a custom view layout in the menu bar
    }
}
