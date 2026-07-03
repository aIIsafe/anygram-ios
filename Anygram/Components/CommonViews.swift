import SwiftUI

struct SearchBarView: View {
    @Binding var text: String
    var placeholder: String = "Search"

    var body: some View {
        HStack(spacing: AppSpacing.xs) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(AppColors.textSecondary)
            TextField(placeholder, text: $text)
                .foregroundStyle(AppColors.textPrimary)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(AppColors.textSecondary)
                }
                .accessibilityLabel("Clear search")
            }
        }
        .padding(AppSpacing.xs)
        .background(AppColors.tertiaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium))
        .padding(.horizontal, AppSpacing.md)
    }
}

struct PrimaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(AppTypography.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.sm)
                .background(AppColors.accent)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium))
        }
    }
}

struct BlurBackgroundView: View {
    var body: some View {
        Rectangle()
            .fill(.ultraThinMaterial)
            .background(AppColors.tabBarBackground)
    }
}

struct LoadingView: View {
    var body: some View {
        ProgressView()
            .tint(AppColors.accent)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct SkeletonView: View {
    @State private var phase: CGFloat = 0

    var body: some View {
        RoundedRectangle(cornerRadius: AppRadius.small)
            .fill(AppColors.tertiaryBackground)
            .overlay {
                GeometryReader { geo in
                    LinearGradient(
                        colors: [.clear, AppColors.textTertiary.opacity(0.3), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geo.size.width * 0.6)
                    .offset(x: phase * geo.size.width * 1.6 - geo.size.width * 0.3)
                }
                .clipped()
            }
            .onAppear {
                guard !UIAccessibility.isReduceMotionEnabled else { return }
                withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

struct TypingIndicatorView: View {
    @State private var animating = false

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(AppColors.textSecondary)
                    .frame(width: 6, height: 6)
                    .opacity(animating ? 1 : 0.3)
                    .animation(
                        UIAccessibility.isReduceMotionEnabled ? nil :
                            .easeInOut(duration: 0.5).repeatForever().delay(Double(index) * 0.15),
                        value: animating
                    )
            }
        }
        .onAppear { animating = true }
        .accessibilityLabel("Typing")
    }
}
