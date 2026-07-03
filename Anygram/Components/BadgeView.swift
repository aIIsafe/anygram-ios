import SwiftUI

/// Unread count badge.
struct BadgeView: View {
    let count: Int
    var isMuted: Bool = false

    var body: some View {
        if count > 0 {
            Text(count > 99 ? "99+" : "\(count)")
                .font(AppTypography.captionBold)
                .foregroundStyle(.white)
                .padding(.horizontal, count > 9 ? 6 : 5)
                .padding(.vertical, 2)
                .background(isMuted ? AppColors.muted : AppColors.badge)
                .clipShape(Capsule())
                .accessibilityLabel("\(count) unread")
        }
    }
}

struct PremiumBadge: View {
    var body: some View {
        Image(systemName: "star.fill")
            .font(.system(size: 12))
            .foregroundStyle(AppColors.premium)
            .accessibilityLabel("Premium")
    }
}

struct VerifiedBadge: View {
    var body: some View {
        Image(systemName: "checkmark.seal.fill")
            .font(.system(size: 14))
            .foregroundStyle(AppColors.verified)
            .accessibilityLabel("Verified")
    }
}
