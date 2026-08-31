import SwiftUI

// MARK: - GhostUI Design System

struct GhostUI {
    // MARK: - Core Animations
    static var gentleSpring: Animation {
        .spring(response: 0.4, dampingFraction: 0.8)
    }
    
    static var quickSpring: Animation {
        .spring(response: 0.25, dampingFraction: 0.7)
    }
    
    static var smoothFade: Animation {
        .easeIn(duration: 0.3)
    }
    
    /// For items appearing from memory — slight upward drift + fade
    static var memoryAppear: Animation {
        .spring(response: 0.5, dampingFraction: 0.85)
    }
    
    /// For activity flowing through time
    static var flowTransition: Animation {
        .easeInOut(duration: 0.35)
    }
    
    /// For recovery state changes — slightly slower, deliberate
    static var recoverTransition: Animation {
        .spring(response: 0.55, dampingFraction: 0.8)
    }
    
    // MARK: - Metrics
    static let standardCornerRadius: CGFloat = 10
    static let standardPadding: CGFloat = 16
    static let connectorWidth: CGFloat = 1.5
    static let connectorDotSize: CGFloat = 6
    
    // MARK: - Activity Zone Colors
    static let quietZone = Color.secondary.opacity(0.08)
    static let normalZone = Color.indigo.opacity(0.06)
    static let activeZone = Color.indigo.opacity(0.12)
    
    // MARK: - Accessibility
    
    static func withMotion<Result>(_ animation: Animation, body: () throws -> Result) rethrows -> Result {
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            return try withAnimation(nil, body)
        } else {
            return try withAnimation(animation, body)
        }
    }
    
    static func motionAnimation(_ animation: Animation) -> Animation? {
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            return nil
        }
        return animation
    }
}

// MARK: - Ghost Card Modifier

struct GhostCardModifier: ViewModifier {
    let backgroundColor: Color
    var isHighlighted: Bool = false
    
    func body(content: Content) -> some View {
        content
            .background(isHighlighted ? Color.indigo.opacity(0.08) : backgroundColor)
            .cornerRadius(GhostUI.standardCornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: GhostUI.standardCornerRadius)
                    .stroke(
                        isHighlighted ? Color.indigo.opacity(0.3) : Color(NSColor.separatorColor).opacity(0.2),
                        lineWidth: isHighlighted ? 1 : 0.5
                    )
            )
            .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 2)
            .animation(GhostUI.quickSpring, value: isHighlighted)
    }
}

extension View {
    func ghostCardStyle(backgroundColor: Color = Color(NSColor.controlBackgroundColor), isHighlighted: Bool = false) -> some View {
        self.modifier(GhostCardModifier(backgroundColor: backgroundColor, isHighlighted: isHighlighted))
    }
}

// MARK: - Hover Scale Modifier

struct HoverScaleModifier: ViewModifier {
    @State private var isHovered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isHovered && !reduceMotion ? 1.01 : 1.0)
            .animation(GhostUI.quickSpring, value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

extension View {
    func hoverScaleEffect() -> some View {
        self.modifier(HoverScaleModifier())
    }
}

// MARK: - Animated Number View

struct AnimatedNumberView: View {
    let value: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        if #available(macOS 14.0, *) {
            Text("\(value)")
                .contentTransition(.numericText(value: Double(value)))
                .animation(GhostUI.motionAnimation(GhostUI.gentleSpring), value: value)
        } else {
            Text("\(value)")
        }
    }
}

// MARK: - Ghost Timeline Connector

/// A subtle vertical connector between timeline events, creating the "memory stream" visual.
struct GhostTimelineConnector: View {
    var height: CGFloat = 24
    var opacity: Double = 0.15
    
    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.secondary.opacity(opacity))
                .frame(width: GhostUI.connectorWidth)
                .frame(height: height)
        }
    }
}

/// A dot used at timeline junction points.
struct GhostTimelineDot: View {
    var size: CGFloat = GhostUI.connectorDotSize
    var color: Color = .secondary
    var isCurrent: Bool = false
    
    @State private var pulse = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        ZStack {
            if isCurrent && !reduceMotion {
                Circle()
                    .fill(color.opacity(0.3))
                    .frame(width: size * 2, height: size * 2)
                    .scaleEffect(pulse ? 1.5 : 1.0)
                    .opacity(pulse ? 0.0 : 0.5)
                    .onAppear {
                        withAnimation(.easeOut(duration: 2.0).repeatForever(autoreverses: false)) {
                            pulse = true
                        }
                    }
            }
            Circle()
                .fill(color)
                .frame(width: size, height: size)
        }
    }
}

// MARK: - Ghost Pulse (Presence Indicator)

enum GhostPresenceState {
    case idle      // · no recent activity
    case watching  // • tracking active
    case captured  // ✦ new memory just captured
}

struct GhostPulse: View {
    let state: GhostPresenceState
    
    @State private var isAnimating = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        ZStack {
            Circle()
                .fill(stateColor.opacity(0.3))
                .frame(width: 12, height: 12)
                .scaleEffect(isAnimating && !reduceMotion ? 1.8 : 1.0)
                .opacity(isAnimating && !reduceMotion ? 0.0 : 0.6)
            
            Circle()
                .fill(stateColor)
                .frame(width: 8, height: 8)
        }
        .onChange(of: state) { newState in
            if newState == .captured {
                // Brief flash, then settle
                withAnimation(.easeOut(duration: 0.3)) { isAnimating = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    withAnimation(.easeIn(duration: 0.3)) { isAnimating = false }
                }
            }
        }
        .onAppear {
            if state == .watching {
                withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                    isAnimating = true
                }
            }
        }
    }
    
    private var stateColor: Color {
        switch state {
        case .idle: return .secondary
        case .watching: return .green
        case .captured: return .indigo
        }
    }
}

// MARK: - Ghost Recovery Badge

/// A small contextual recovery action badge. Appears on hover for recoverable events.
struct GhostRecoveryBadge: View {
    let label: String
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: "arrow.uturn.backward")
                    .font(.caption2)
                Text(label)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(isHovered ? Color.blue.opacity(0.15) : Color.blue.opacity(0.08))
            .foregroundColor(.blue)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(GhostUI.quickSpring) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Ghost Empty State

struct GhostEmptyState: View {
    let icon: String
    let title: String
    let subtitle: String
    
    @State private var isFloating = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 44))
                .foregroundColor(.secondary.opacity(0.6))
                .offset(y: isFloating && !reduceMotion ? -4 : 4)
                .animation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true), value: isFloating)
                .onAppear { isFloating = true }
            
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            
            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

// MARK: - Ghost Keyboard Shortcut Label

struct GhostShortcutHint: View {
    let keys: String  // e.g. "⌘⇧R"
    
    var body: some View {
        Text(keys)
            .font(.system(.caption2, design: .rounded))
            .fontWeight(.medium)
            .foregroundColor(.secondary)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(4)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color(NSColor.separatorColor).opacity(0.3), lineWidth: 0.5)
            )
    }
}
