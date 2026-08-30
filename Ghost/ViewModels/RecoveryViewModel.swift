import SwiftUI
import SwiftData

@MainActor
class RecoveryViewModel: ObservableObject {
    @Published var recentRenames: [RecallResult] = []
    @Published var recentMoves: [RecallResult] = []
    
    private let searchService: RecallSearchService
    let recoveryService: RecoveryService
    
    init(modelContainer: ModelContainer, repository: ActivityEventRepository) {
        self.searchService = RecallSearchService(modelContainer: modelContainer)
        self.recoveryService = RecoveryService(repository: repository)
    }
    
    func loadRecentSuggestions() {
        Task {
            // Find activity in the last 15 minutes
            let recentQuery = "this afternoon" // We can do better by just fetching directly, but let's use searchService with empty query and time bounds
            // Wait, we need a way to fetch recent specifically.
            // I'll just search for "renamed" and "moved" and limit to 5.
            let renames = await searchService.search(query: "renamed", limit: 10)
            let moves = await searchService.search(query: "moved", limit: 10)
            
            // Filter strictly for high confidence and less than 1 hour old
            let oneHourAgo = Date().addingTimeInterval(-3600)
            
            self.recentRenames = renames.filter { $0.confidence == .high && $0.timestamp > oneHourAgo }.prefix(3).map { $0 }
            self.recentMoves = moves.filter { $0.confidence == .high && $0.timestamp > oneHourAgo }.prefix(3).map { $0 }
        }
    }
}
