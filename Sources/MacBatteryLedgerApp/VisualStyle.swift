import SwiftUI

enum PremiumStyle {
    static let ink = Color.primary
    static let secondaryInk = Color.secondary
    static let line = Color.primary.opacity(0.1)
    static let panel = Color(nsColor: .windowBackgroundColor)
    static let softPanel = Color(nsColor: .controlBackgroundColor)
    static let green = Color(nsColor: .systemGreen)
    static let amber = Color(nsColor: .systemOrange)
    static let red = Color(nsColor: .systemRed)
    static let graphite = Color(nsColor: .systemGray)

    static var metricFont: Font {
        .system(size: 28, weight: .semibold, design: .rounded)
    }

    static var titleFont: Font {
        .system(size: 15, weight: .semibold, design: .rounded)
    }

    static var smallFont: Font {
        .system(size: 11, weight: .medium, design: .rounded)
    }
}

struct GlassCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(14)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(PremiumStyle.line, lineWidth: 1)
            }
    }
}

extension View {
    func glassCard() -> some View {
        modifier(GlassCard())
    }

    func pointerCursor() -> some View {
        self.onHover { isHovered in
            if isHovered {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}
