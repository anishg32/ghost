import SwiftUI
import SwiftData

struct ActivityPulseGraph: View {
    var events: [ActivityEvent]
    
    // Config
    let bucketCount: Int = 24
    let height: CGFloat = 60
    
    var body: some View {
        let buckets = calculateBuckets()
        let maxCount = max(buckets.max() ?? 1, 1)
        
        GeometryReader { geometry in
            let width = geometry.size.width
            let step = width / CGFloat(bucketCount - 1)
            
            Path { path in
                if buckets.isEmpty { return }
                
                path.move(to: CGPoint(x: 0, y: height))
                
                for (index, count) in buckets.enumerated() {
                    let x = CGFloat(index) * step
                    let normalizedY = CGFloat(count) / CGFloat(maxCount)
                    let y = height - (normalizedY * (height - 10))
                    
                    if index == 0 {
                        path.addLine(to: CGPoint(x: x, y: y))
                    } else {
                        // Smooth cubic curve
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
            
            // Draw the line on top
            Path { path in
                if buckets.isEmpty { return }
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
            .stroke(Color.indigo, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        }
        .frame(height: height)
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
}
