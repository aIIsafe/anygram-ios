import SwiftUI

struct TwoFactorView: View {
    @ObservedObject var viewModel: AuthViewModel
    @FocusState private var isPasswordFocused: Bool

    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            VStack(spacing: AppSpacing.sm) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(AppColors.accent)
                    .padding(.top, AppSpacing.xxl)

                Text(L10n.authTwoFactorTitle)
                    .font(AppTypography.largeTitle)
                    .foregroundStyle(AppColors.textPrimary)

                Text(viewModel.passwordHint ?? L10n.authTwoFactorHint)
                    .font(AppTypography.subheadline)
                    .foregroundStyle(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.lg)
            }

            SecureField(L10n.authPassword, text: $viewModel.password)
                .textContentType(.password)
                .focused($isPasswordFocused)
                .font(AppTypography.body)
                .foregroundStyle(AppColors.textPrimary)
                .padding(AppSpacing.md)
                .liquidGlass(cornerRadius: AppRadius.medium)
                .padding(.horizontal, AppSpacing.lg)
                .onAppear { isPasswordFocused = true }

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.destructive)
            }

            Spacer()

            Button {
                Task { await viewModel.submitPassword() }
            } label: {
                Group {
                    if viewModel.isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text(L10n.authSignIn)
                            .font(AppTypography.headline)
                    }
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.sm)
            }
            .background(AppColors.accent)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium))
            .padding(.horizontal, AppSpacing.lg)
            .disabled(viewModel.isLoading)
        }
        .padding(.bottom, AppSpacing.lg)
    }
}
