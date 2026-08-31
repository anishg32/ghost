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
                                        .transition(.move(edge: .top).combined(with: .opacity))
                                    }
                                } label: {
                                    RecallGroupedEventRowView(group: group)
                                }
                            }
                        }
                        // Stagger the appearance of list items
                        .animation(GhostUI.motionAnimation(GhostUI.gentleSpring.delay(Double(index) * 0.05)), value: viewModel.results.count)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .listStyle(.plain)
                .transition(.opacity)
            }
        }
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
    }
}

struct SearchingStateView: View {
    @State private var isPulsing = false
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "brain")
                .font(.system(size: 40))
                .foregroundColor(.indigo)
                .scaleEffect(isPulsing ? 1.1 : 0.9)
                .opacity(isPulsing ? 1.0 : 0.5)
                .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isPulsing)
                .onAppear { isPulsing = true }
            
            Text("Searching memory...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

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
                
                // Staggered suggestion labels
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

struct RecallEventRowView: View {
    let event: RecallResult
    let onSelect: (RecallResult) -> Void
    @State private var isHovered = false
    
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
                    Button(action: {
                        onSelect(event)
                    }) {
                        Text("History")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(isHovered ? Color.indigo.opacity(0.1) : Color.clear)
                            .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.indigo)
                    .onHover { hovering in
                        withAnimation(GhostUI.quickSpring) {
                            isHovered = hovering
                        }
                    }
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

