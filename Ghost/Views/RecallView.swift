import SwiftUI
import SwiftData

struct RecallView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel: RecallViewModel
    @State private var selectedEvent: RecallResult?
    
    init(modelContainer: ModelContainer) {
        _viewModel = StateObject(wrappedValue: RecallViewModel(modelContainer: modelContainer))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if viewModel.searchText.isEmpty {
                RecallEmptyStateView()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else if viewModel.isSearching {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(.opacity)
            } else if viewModel.results.isEmpty {
                ContentUnavailableView("No Results", systemImage: "magnifyingglass", description: Text("Ghost couldn't find any memory of that."))
                    .transition(.opacity)
            } else {
                List {
                    ForEach(viewModel.results) { group in
                        if group.events.count == 1 {
                            RecallEventRowView(event: group.events.first!) { event in
                                selectedEvent = event
                            }
                        } else {
                            DisclosureGroup {
                                ForEach(group.events) { event in
                                    RecallEventRowView(event: event) { e in
                                        selectedEvent = e
                                    }
                                    .padding(.leading)
                                }
                            } label: {
                                RecallGroupedEventRowView(group: group)
                            }
                        }
                    }
                }
                .transition(.opacity)
            }
        }
        .navigationTitle("Recall")
        .searchable(text: $viewModel.searchText, prompt: "Search your Mac's memory...")
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.searchText.isEmpty)
        .animation(.easeInOut(duration: 0.2), value: viewModel.isSearching)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.results.isEmpty)
        .sheet(item: $selectedEvent) { event in
            if let path = event.newPath ?? event.oldPath {
                FileHistoryView(path: path)
            } else {
                Text("No file history available")
                    .padding()
            }
        }
    }
}

struct RecallEmptyStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 60))
                .foregroundColor(.indigo)
                .padding(.bottom, 8)
            
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
                
                SuggestionLabel(text: "What did I do yesterday?")
                SuggestionLabel(text: "What did I rename this morning?")
                SuggestionLabel(text: "Where did project.mov go?")
                SuggestionLabel(text: "Around 3 PM")
            }
            .padding(.top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct SuggestionLabel: View {
    let text: String
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            Text(text)
                .foregroundColor(.primary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}

struct RecallEventRowView: View {
    let event: RecallResult
    let onSelect: (RecallResult) -> Void
    
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
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(event.timestamp, format: Date.FormatStyle(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if event.newPath != nil || event.oldPath != nil {
                    Button("History") {
                        onSelect(event)
                    }
                    .buttonStyle(.link)
                    .font(.caption)
                }
            }
        }
        .padding(.vertical, 4)
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
