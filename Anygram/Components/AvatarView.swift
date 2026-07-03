import SwiftUI

/// Circular avatar with initials and online indicator.
struct AvatarView: View {
    let name: String
    let colorHex: String
    var size: CGFloat = 48
    var isOnline: Bool = false
    var showOnlineIndicator: Bool = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Circle()
                .fill(Color(hex: colorHex))
                .frame(width: size, height: size)
                .overlay {
                    Text(name.initials)
                        .font(.system(size: size * 0.35, weight: .semibold))
                        .foregroundStyle(.white)
                }

            if showOnlineIndicator {
                Circle()
                    .fill(isOnline ? AppColors.online : AppColors.textTertiary)
                    .frame(width: size * 0.25, height: size * 0.25)
                    .overlay {
                        Circle()
                            .stroke(AppColors.secondaryBackground, lineWidth: 2)
                    }
                    .offset(x: 2, y: 2)
            }
        }
        .accessibilityHidden(true)
    }
}
