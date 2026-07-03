import SwiftUI

/// Telegram-inspired dark theme color palette.
enum AppColors {
    static let background = Color(hex: "#0E1621")
    static let secondaryBackground = Color(hex: "#17212B")
    static let tertiaryBackground = Color(hex: "#242F3D")
    static let bubbleIncoming = Color(hex: "#182533")
    static let bubbleOutgoing = Color(hex: "#2B5278")
    static let accent = Color(hex: "#3390EC")
    static let accentSecondary = Color(hex: "#5EB3F6")
    static let textPrimary = Color.white
    static let textSecondary = Color(hex: "#8BA0B4")
    static let textTertiary = Color(hex: "#6C7883")
    static let separator = Color(hex: "#0E1621").opacity(0.6)
    static let online = Color(hex: "#4CAF50")
    static let destructive = Color(hex: "#E53935")
    static let badge = Color(hex: "#3390EC")
    static let premium = Color(hex: "#FFD700")
    static let verified = Color(hex: "#3390EC")
    static let muted = Color(hex: "#6C7883")
    static let tabBarBackground = Color(hex: "#17212B").opacity(0.85)
}

/// Typography scale matching Telegram styling.
enum AppTypography {
    static let largeTitle = Font.system(size: 28, weight: .bold)
    static let title = Font.system(size: 20, weight: .semibold)
    static let headline = Font.system(size: 17, weight: .semibold)
    static let body = Font.system(size: 16, weight: .regular)
    static let subheadline = Font.system(size: 15, weight: .regular)
    static let caption = Font.system(size: 13, weight: .regular)
    static let captionBold = Font.system(size: 13, weight: .semibold)
    static let tabLabel = Font.system(size: 10, weight: .medium)
}

/// Consistent spacing values.
enum AppSpacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 20
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
}

/// Corner radius values.
enum AppRadius {
    static let small: CGFloat = 8
    static let medium: CGFloat = 12
    static let large: CGFloat = 18
    static let bubble: CGFloat = 16
    static let avatar: CGFloat = 999
}

/// Animation presets respecting Reduce Motion.
enum AppAnimation {
    static var standard: Animation {
        UIAccessibility.isReduceMotionEnabled ? .linear(duration: 0.1) : .easeInOut(duration: 0.25)
    }

    static var spring: Animation {
        UIAccessibility.isReduceMotionEnabled ? .linear(duration: 0.1) : .spring(response: 0.35, dampingFraction: 0.8)
    }

    static var tab: Animation {
        UIAccessibility.isReduceMotionEnabled ? .linear(duration: 0.1) : .easeInOut(duration: 0.2)
    }
}

/// View modifier for Telegram dark theme background.
struct TelegramBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(AppColors.background.ignoresSafeArea())
            .preferredColorScheme(.dark)
    }
}

extension View {
    func telegramBackground() -> some View {
        modifier(TelegramBackgroundModifier())
    }
}
