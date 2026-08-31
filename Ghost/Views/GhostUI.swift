import SwiftUI

struct GhostUI {
    // MARK: - Animations
    static var gentleSpring: Animation {
        .spring(response: 0.4, dampingFraction: 0.8)
    }
    
    static var quickSpring: Animation {
        .spring(response: 0.25, dampingFraction: 0.7)
    }
    
    static var smoothFade: Animation {
        .easeIn(duration: 0.3)
    }
    
    // MARK: - Metrics
    static let standardCornerRadius: CGFloat = 12
    static let standardPadding: CGFloat = 16
    
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

// MARK: - Components

struct GhostCardModifier: ViewModifier {
    let backgroundColor: Color
    
    func body(content: Content) -> some View {
        content
            .background(backgroundColor)
            .cornerRadius(GhostUI.standardCornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: GhostUI.standardCornerRadius)
                    .stroke(Color(NSColor.separatorColor).opacity(0.3), lineWidth: 0.5)
            )
            .shadow(color: Color.black.opacity(0.03), radius: 5, x: 0, y: 2)
    }
}

extension View {
    func ghostCardStyle(backgroundColor: Color = Color(NSColor.controlBackgroundColor)) -> some View {
        self.modifier(GhostCardModifier(backgroundColor: backgroundColor))
    }
}

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
