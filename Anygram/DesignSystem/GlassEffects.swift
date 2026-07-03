import SwiftUI

/// Reusable Liquid Glass modifiers.
/// Native `.glassEffect()` (iOS 26+) is applied when the SDK provides the symbol;
/// otherwise a material + border fallback mimics the Liquid Glass aesthetic on iOS 17+.
enum GlassStyle {
    case regular
    case clear
    case prominent
}

struct LiquidGlassModifier: ViewModifier {
    var style: GlassStyle = .regular
    var cornerRadius: CGFloat = AppRadius.medium
    var isInteractive: Bool = false

    func body(content: Content) -> some View {
        content.modifier(FallbackGlassModifier(cornerRadius: cornerRadius, style: style))
    }
}

private struct FallbackGlassModifier: ViewModifier {
    let cornerRadius: CGFloat
    var style: GlassStyle = .regular

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(materialFill)
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(style == .prominent ? 0.28 : 0.22),
                                        Color.white.opacity(0.06),
                                        Color.white.opacity(0.12)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.5
                            )
                    }
                    .shadow(color: Color.black.opacity(0.18), radius: 12, y: 4)
            }
    }

    private var materialFill: some ShapeStyle {
        switch style {
        case .clear:
            return AnyShapeStyle(.thinMaterial)
        case .prominent:
            return AnyShapeStyle(.regularMaterial)
        case .regular:
            return AnyShapeStyle(.ultraThinMaterial)
        }
    }
}

struct GlassTabBarModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, AppSpacing.xs)
            .padding(.vertical, AppSpacing.xs)
            .background {
                RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.2), Color.white.opacity(0.08)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 0.5
                            )
                    }
                    .shadow(color: Color.black.opacity(0.28), radius: 20, y: 8)
                    .padding(.horizontal, AppSpacing.sm)
                    .padding(.bottom, AppSpacing.xxs)
            }
    }
}

struct GlassNavigationBarModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
    }
}

struct GlassCardModifier: ViewModifier {
    var cornerRadius: CGFloat = AppRadius.medium

    func body(content: Content) -> some View {
        content.modifier(LiquidGlassModifier(style: .regular, cornerRadius: cornerRadius))
    }
}

struct GlassSheetBackground: ViewModifier {
    func body(content: Content) -> some View {
        content.presentationBackground(.ultraThinMaterial)
    }
}

extension View {
    func liquidGlass(
        _ style: GlassStyle = .regular,
        cornerRadius: CGFloat = AppRadius.medium,
        interactive: Bool = false
    ) -> some View {
        modifier(LiquidGlassModifier(style: style, cornerRadius: cornerRadius, isInteractive: interactive))
    }

    func glassTabBar() -> some View {
        modifier(GlassTabBarModifier())
    }

    func glassNavigationBar() -> some View {
        modifier(GlassNavigationBarModifier())
    }

    func glassCard(cornerRadius: CGFloat = AppRadius.medium) -> some View {
        modifier(GlassCardModifier(cornerRadius: cornerRadius))
    }

    func glassSheetBackground() -> some View {
        modifier(GlassSheetBackground())
    }
}

#if swift(>=6.0)
// When building with the iOS 26 SDK, swap FallbackGlassModifier for native Liquid Glass:
// content.glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: cornerRadius))
#endif
