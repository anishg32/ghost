import SwiftUI
import SwiftData
import Combine

@MainActor
class RecallViewModel: ObservableObject {
    @Published var searchText: String = ""
    @Published var results: [RecallResultGroup] = []
    @Published var isSearching: Bool = false
    
    private var searchCancellable: AnyCancellable?
    private var activeSearchTask: Task<Void, Never>?
    private let searchService: RecallSearchService
    
    init(modelContainer: ModelContainer) {
        self.searchService = RecallSearchService(modelContainer: modelContainer)
        
        searchCancellable = $searchText
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] query in
                self?.performSearch(query: query)
            }
    }
    
    private func performSearch(query: String) {
        // Cancel any pending search task to prevent out-of-order execution
        activeSearchTask?.cancel()
        
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            self.results = []
            self.isSearching = false
            return
        }
        
        self.isSearching = true
        
        activeSearchTask = Task {
            let fetchedEvents = await searchService.search(query: query)
            
            if Task.isCancelled { return }
            
            let grouped = self.groupEvents(fetchedEvents)
            
            self.results = grouped
            self.isSearching = false
        }
    }
    
    private func groupEvents(_ events: [RecallResult]) -> [RecallResultGroup] {
        var groups: [RecallResultGroup] = []
        var currentGroupEvents: [RecallResult] = []
        
        for event in events {
            if let last = currentGroupEvents.last {
                if last.eventType == event.eventType && abs(last.timestamp.timeIntervalSince(event.timestamp)) < 10 {
                    currentGroupEvents.append(event)
                } else {
                    if !currentGroupEvents.isEmpty {
                        groups.append(RecallResultGroup(eventType: currentGroupEvents.first!.eventType, events: currentGroupEvents))
                    }
                    currentGroupEvents = [event]
                }
            } else {
                currentGroupEvents.append(event)
            }
        }
        if !currentGroupEvents.isEmpty {
            groups.append(RecallResultGroup(eventType: currentGroupEvents.first!.eventType, events: currentGroupEvents))
        }
        
        return groups
    }
}
