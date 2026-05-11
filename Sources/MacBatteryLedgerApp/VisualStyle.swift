import SwiftUI

enum PremiumStyle {
    static let ink = Color(red: 0.08, green: 0.09, blue: 0.10)
    static let secondaryInk = Color(red: 0.43, green: 0.45, blue: 0.48)
    static let line = Color.black.opacity(0.08)
    static let panel = Color(nsColor: .windowBackgroundColor)
    static let softPanel = Color(red: 0.965, green: 0.967, blue: 0.972)
    static let green = Color(red: 0.18, green: 0.66, blue: 0.42)
    static let amber = Color(red: 0.86, green: 0.57, blue: 0.16)
    static let graphite = Color(red: 0.18, green: 0.20, blue: 0.22)

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
}
