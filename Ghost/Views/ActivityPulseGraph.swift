import SwiftUI
import SwiftData

struct ActivityPulseGraph: View {
    var events: [ActivityEvent]
    var onHoverTimeRange: ((ClosedRange<Date>?) -> Void)? = nil
    
    // Config
    let bucketCount: Int = 24
    let height: CGFloat = 70
    
    @State private var drawPercentage: CGFloat = 0.0
    @State private var hoveredIndex: Int? = nil
    @State private var pulseScale: CGFloat = 1.0
    
    var body: some View {
        let buckets = calculateBuckets()
        let maxCount = max(buckets.max() ?? 1, 1)
        
        VStack(spacing: 4) {
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
                        .stroke(Color.secondary.opacity(0.15), style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                        .frame(height: height)
                    } else {
                        // Activity zone background tints
                        activityZoneBackground(buckets: buckets, maxCount: maxCount, width: width, step: step)
                        
                        // Gradient Fill
                        areaPath(buckets: buckets, maxCount: maxCount, width: width, step: step)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.indigo.opacity(0.35), Color.indigo.opacity(0.02)]),
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .opacity(Double(drawPercentage))
                        
                        // Stroke Line
                        linePath(buckets: buckets, maxCount: maxCount, width: width, step: step)
                            .trim(from: 0, to: drawPercentage)
                            .stroke(Color.indigo, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                        
                        // Current time indicator
                        currentTimeIndicator(width: width, step: step)
                        
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
                                        onHoverTimeRange?(timeRangeForBucket(index: index))
                                    }
                                case .ended:
                                    withAnimation(GhostUI.quickSpring) {
                                        hoveredIndex = nil
                                    }
                                    onHoverTimeRange?(nil)
                                }
                            }
                        
                        // Tooltip & Highlight
                        if let hoveredIndex = hoveredIndex {
                            hoverOverlay(index: hoveredIndex, buckets: buckets, maxCount: maxCount, step: step)
                        }
                        
                        // Live Pulse on current hour
                        livePulse(buckets: buckets, maxCount: maxCount, step: step)
                    }
                }
            }
            .frame(height: height)
            
            // Time labels
            timeLabels()
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                drawPercentage = 1.0
            }
        }
        .animation(GhostUI.gentleSpring, value: buckets)
    }
    
    // MARK: - Sub-views
    
    @ViewBuilder
    private func activityZoneBackground(buckets: [Int], maxCount: Int, width: CGFloat, step: CGFloat) -> some View {
        // Very subtle zone tinting based on activity level
        ForEach(0..<bucketCount, id: \.self) { index in
            let count = buckets[index]
            let ratio = CGFloat(count) / CGFloat(maxCount)
            let x = CGFloat(index) * step
            let zoneColor: Color = {
                if ratio < 0.33 { return GhostUI.quietZone }
                else if ratio < 0.66 { return GhostUI.normalZone }
                else { return GhostUI.activeZone }
            }()
            
            if count > 0 {
                Rectangle()
                    .fill(zoneColor)
                    .frame(width: step, height: height)
                    .position(x: x, y: height / 2)
                    .opacity(Double(drawPercentage))
            }
        }
    }
    
    private func areaPath(buckets: [Int], maxCount: Int, width: CGFloat, step: CGFloat) -> Path {
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
    }
    
    private func linePath(buckets: [Int], maxCount: Int, width: CGFloat, step: CGFloat) -> Path {
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
    }
    
    @ViewBuilder
    private func currentTimeIndicator(width: CGFloat, step: CGFloat) -> some View {
        let currentIndex = currentBucketIndex()
        if currentIndex < bucketCount {
            let x = CGFloat(currentIndex) * step
            Path { path in
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: height))
            }
            .stroke(Color.primary.opacity(0.12), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
        }
    }
    
    @ViewBuilder
    private func hoverOverlay(index: Int, buckets: [Int], maxCount: Int, step: CGFloat) -> some View {
        let x = CGFloat(index) * step
        let count = buckets[index]
        let normalizedY = CGFloat(count) / CGFloat(maxCount)
        let y = height - (normalizedY * (height - 10))
        
        // Vertical indicator line
        Path { path in
            path.move(to: CGPoint(x: x, y: height))
            path.addLine(to: CGPoint(x: x, y: y))
        }
        .stroke(Color.primary.opacity(0.15), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
        
        // Dot
        Circle()
            .fill(Color.indigo)
            .frame(width: 7, height: 7)
            .position(x: x, y: y)
            .shadow(color: .indigo.opacity(0.4), radius: 3)
        
        // Tooltip
        VStack(alignment: .center, spacing: 2) {
            Text("\(count) actions")
                .font(.caption2)
                .fontWeight(.semibold)
            Text(timeForBucket(index: index))
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(.regularMaterial)
        .cornerRadius(6)
        .shadow(color: .black.opacity(0.08), radius: 4)
        .position(x: x, y: max(y - 28, 10))
        .offset(x: index == 0 ? 30 : (index == bucketCount - 1 ? -30 : 0))
    }
    
    @ViewBuilder
    private func livePulse(buckets: [Int], maxCount: Int, step: CGFloat) -> some View {
        let currentHourBucket = currentBucketIndex()
        if !buckets.isEmpty && currentHourBucket < bucketCount {
            let x = CGFloat(currentHourBucket) * step
            let count = buckets[currentHourBucket]
            let normalizedY = CGFloat(count) / CGFloat(maxCount)
            let y = height - (normalizedY * (height - 10))
            
            Circle()
                .fill(Color.indigo.opacity(0.5))
                .frame(width: 5, height: 5)
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
    
    private func timeLabels() -> some View {
        GeometryReader { geo in
            let width = geo.size.width
            let labels: [(String, CGFloat)] = [
                ("12 AM", 0),
                ("6 AM", width * 0.25),
                ("12 PM", width * 0.5),
                ("6 PM", width * 0.75),
                ("Now", width * CGFloat(currentBucketIndex()) / CGFloat(max(1, bucketCount - 1)))
            ]
            
            ForEach(labels, id: \.0) { label, x in
                Text(label)
                    .font(.system(size: 9, weight: label == "Now" ? .semibold : .regular))
                    .foregroundColor(label == "Now" ? .indigo : .secondary.opacity(0.6))
                    .position(x: min(max(x, 18), width - 18), y: 8)
            }
        }
        .frame(height: 16)
    }
    
    // MARK: - Data
    
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
        return min(Int(secondsSinceStart / bucketDuration), bucketCount - 1)
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
    
    private func timeRangeForBucket(index: Int) -> ClosedRange<Date> {
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        let totalSeconds = 24.0 * 60.0 * 60.0
        let bucketDuration = totalSeconds / Double(bucketCount)
        
        let start = startOfDay.addingTimeInterval(Double(index) * bucketDuration)
        let end = startOfDay.addingTimeInterval(Double(index + 1) * bucketDuration)
        return start...end
    }
}
