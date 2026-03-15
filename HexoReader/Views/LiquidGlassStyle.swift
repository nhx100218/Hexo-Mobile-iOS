import SwiftUI

struct LiquidGlassBackground: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    Rectangle()
                        .fill(.ultraThinMaterial)

                    LinearGradient(
                        colors: [
                            .white.opacity(colorScheme == .dark ? 0.12 : 0.35),
                            .clear,
                            .white.opacity(colorScheme == .dark ? 0.05 : 0.18)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )

                    RadialGradient(
                        colors: [
                            .white.opacity(colorScheme == .dark ? 0.14 : 0.25),
                            .clear
                        ],
                        center: .topLeading,
                        startRadius: 40,
                        endRadius: 420
                    )
                }
                .ignoresSafeArea()
            }
    }
}

struct LiquidGlassCard: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        .white.opacity(colorScheme == .dark ? 0.25 : 0.5),
                                        .white.opacity(colorScheme == .dark ? 0.04 : 0.15)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    }
                    .shadow(color: .black.opacity(colorScheme == .dark ? 0.35 : 0.15), radius: 20, y: 8)
            }
    }
}

extension View {
    func liquidGlassBackground() -> some View {
        modifier(LiquidGlassBackground())
    }

    func liquidGlassCard(cornerRadius: CGFloat = 20) -> some View {
        modifier(LiquidGlassCard(cornerRadius: cornerRadius))
    }
}
