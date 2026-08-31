import SwiftUI
import SwiftData

struct ActivityPulseGraph: View {
    var events: [ActivityEvent]
    
    // Config
    let bucketCount: Int = 24
    let height: CGFloat = 60
    
    @State private var drawPercentage: CGFloat = 0.0
    @State private var hoveredIndex: Int? = nil
    @State private var pulseScale: CGFloat = 1.0
    
    var body: some View {
        let buckets = calculateBuckets()
        let maxCount = max(buckets.max() ?? 1, 1)
        
        GeometryReader { geometry in
            let width = geometry.size.width
            let step = width / CGFloat(max(1, bucketCount - 1))
            
            ZStack(alignment: .topLeading) {
                if buckets.isEmpty || buckets.allSatisfy({ $0 == 0 }) {
                    // Empty state graph
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: height - 5))
                        path.addLine(to: CGPoint(x: width, y: height - 5))
                    }
                    .stroke(Color.secondary.opacity(0.2), style: StrokeStyle(lineWidth: 2, dash: [5, 5]))
                    .frame(height: height)
                } else {
                    // Gradient Fill
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: height))
                        
                        for (index, count) in buckets.enumerated() {
                            let x = CGFloat(index) * step
                            let normalizedY = CGFloat(count) / CGFloat(maxCount)
                            let y = height - (normalizedY * (height - 10))
                            
                            if index == 0 {
                                path.addLine(to: CGPoint(x: x, y: y))
                            } else {
                                let prevX = CGFloat(index - 1) * step
                                let prevCount = buckets[index - 1]
                                let prevNormalizedY = CGFloat(prevCount) / CGFloat(maxCount)
                                let prevY = height - (prevNormalizedY * (height - 10))
                                
                                let controlX = (prevX + x) / 2
                                path.addCurve(
                                    to: CGPoint(x: x, y: y),
                                    control1: CGPoint(x: controlX, y: prevY),
                                    control2: CGPoint(x: controlX, y: y)
                                )
                            }
                        }
                        
                        path.addLine(to: CGPoint(x: width, y: height))
                        path.closeSubpath()
                    }
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.indigo.opacity(0.4), Color.indigo.opacity(0.01)]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .opacity(Double(drawPercentage))
                    
                    // Stroke Line
                    Path { path in
                        for (index, count) in buckets.enumerated() {
                            let x = CGFloat(index) * step
                            let normalizedY = CGFloat(count) / CGFloat(maxCount)
                            let y = height - (normalizedY * (height - 10))
                            
                            if index == 0 {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                let prevX = CGFloat(index - 1) * step
                                let prevCount = buckets[index - 1]
                                let prevNormalizedY = CGFloat(prevCount) / CGFloat(maxCount)
                                let prevY = height - (prevNormalizedY * (height - 10))
                                
                                let controlX = (prevX + x) / 2
                                path.addCurve(
                                    to: CGPoint(x: x, y: y),
                                    control1: CGPoint(x: controlX, y: prevY),
                                    control2: CGPoint(x: controlX, y: y)
                                )
                            }
                        }
                    }
                    .trim(from: 0, to: drawPercentage)
                    .stroke(Color.indigo, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    
                    // Hover interactions
                    Color.clear
                        .contentShape(Rectangle())
                        .onContinuousHover { phase in
                            switch phase {
                            case .active(let location):
                                let index = Int(round(location.x / step))
                                if index >= 0 && index < bucketCount {
                                    withAnimation(GhostUI.quickSpring) {
                                        hoveredIndex = index
                                    }
                                }
                            case .ended:
                                withAnimation(GhostUI.quickSpring) {
                                    hoveredIndex = nil
                                }
                            }
                        }
                    
                    // Tooltip & Highlight
                    if let hoveredIndex = hoveredIndex {
                        let x = CGFloat(hoveredIndex) * step
                        let count = buckets[hoveredIndex]
                        let normalizedY = CGFloat(count) / CGFloat(maxCount)
                        let y = height - (normalizedY * (height - 10))
                        
                        // Vertical indicator line
                        Path { path in
                            path.move(to: CGPoint(x: x, y: height))
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                        .stroke(Color.primary.opacity(0.2), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        
                        // Dot
                        Circle()
                            .fill(Color.indigo)
                            .frame(width: 8, height: 8)
                            .position(x: x, y: y)
                            .shadow(color: .indigo.opacity(0.5), radius: 3)
                        
                        // Tooltip text
                        VStack(alignment: .center, spacing: 2) {
                            Text("\(count) actions")
                                .font(.caption)
                                .fontWeight(.bold)
                            Text(timeForBucket(index: hoveredIndex))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding(6)
                        .background(Color(NSColor.windowBackgroundColor).opacity(0.9))
                        .cornerRadius(6)
                        .shadow(radius: 2)
                        .position(x: x, y: max(y - 30, 10)) // Keep tooltip above
                        .offset(x: hoveredIndex == 0 ? 30 : (hoveredIndex == bucketCount - 1 ? -30 : 0)) // Avoid edge cutoff
                    }
                    
                    // Live Pulse on current hour
                    let currentHourBucket = currentBucketIndex()
                    if !buckets.isEmpty && currentHourBucket < bucketCount {
                        let x = CGFloat(currentHourBucket) * step
                        let count = buckets[currentHourBucket]
                        let normalizedY = CGFloat(count) / CGFloat(maxCount)
                        let y = height - (normalizedY * (height - 10))
                        
                        Circle()
                            .fill(Color.indigo.opacity(0.6))
                            .frame(width: 6, height: 6)
                            .scaleEffect(pulseScale)
                            .opacity(2.0 - pulseScale)
                            .position(x: x, y: y)
                            .onAppear {
                                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false)) {
                                    pulseScale = 2.0
                                }
                            }
                    }
                }
            }
        }
        .frame(height: height)
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                drawPercentage = 1.0
            }
        }
        // Smoothly animate changes to buckets (e.g., when a new event happens)
        .animation(GhostUI.gentleSpring, value: buckets)
    }
    
    private func calculateBuckets() -> [Int] {
        var buckets = Array(repeating: 0, count: bucketCount)
        let calendar = Calendar.current
        let now = Date()
        
        let startOfDay = calendar.startOfDay(for: now)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        let totalSeconds = endOfDay.timeIntervalSince(startOfDay)
        let bucketDuration = totalSeconds / Double(bucketCount)
        
        for event in events {
            if event.timestamp >= startOfDay && event.timestamp < endOfDay {
                let secondsSinceStart = event.timestamp.timeIntervalSince(startOfDay)
                let bucketIndex = Int(secondsSinceStart / bucketDuration)
                if bucketIndex >= 0 && bucketIndex < bucketCount {
                    buckets[bucketIndex] += 1
                }
            }
        }
        return buckets
    }
    
    private func currentBucketIndex() -> Int {
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        let secondsSinceStart = now.timeIntervalSince(startOfDay)
        let totalSeconds = 24.0 * 60.0 * 60.0
        let bucketDuration = totalSeconds / Double(bucketCount)
        return Int(secondsSinceStart / bucketDuration)
    }
    
    private func timeForBucket(index: Int) -> String {
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        let totalSeconds = 24.0 * 60.0 * 60.0
        let bucketDuration = totalSeconds / Double(bucketCount)
        
        let bucketTime = startOfDay.addingTimeInterval(Double(index) * bucketDuration)
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: bucketTime)
    }
}

