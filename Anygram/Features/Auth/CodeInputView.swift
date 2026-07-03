import SwiftUI

struct CodeInputView: View {
    @ObservedObject var viewModel: AuthViewModel
    @FocusState private var focusedIndex: Int?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: AppSpacing.lg) {
                VStack(spacing: AppSpacing.sm) {
                    Text(L10n.authCodeTitle)
                        .font(AppTypography.largeTitle)
                        .foregroundStyle(AppColors.textPrimary)
                        .padding(.top, AppSpacing.xxl)

                    Text(viewModel.usesScaffoldAuth ? L10n.authScaffoldCodeHint : L10n.authCodeHint)
                        .font(AppTypography.subheadline)
                        .foregroundStyle(AppColors.textSecondary)
                        .multilineTextAlignment(.center)

                    Text(viewModel.fullPhoneNumber)
                        .font(AppTypography.headline)
                        .foregroundStyle(AppColors.accent)

                    Button(L10n.authEditPhone) {
                        viewModel.goBackToPhone()
                    }
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
                }
                .padding(.horizontal, AppSpacing.lg)

                HStack(spacing: AppSpacing.sm) {
                    ForEach(0..<viewModel.codeLength, id: \.self) { index in
                        TextField("", text: Binding(
                            get: {
                                index < viewModel.codeDigits.count ? viewModel.codeDigits[index] : ""
                            },
                            set: { viewModel.updateCodeDigit(at: index, value: $0) }
                        ))
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.center)
                        .font(.title.monospacedDigit())
                        .foregroundStyle(AppColors.textPrimary)
                        .frame(width: 48, height: 56)
                        .focused($focusedIndex, equals: index)
                        .liquidGlass(cornerRadius: AppRadius.medium, interactive: true)
                    }
                }
                .padding(.horizontal, AppSpacing.lg)
                .onChange(of: viewModel.focusNextIndex) { _, next in
                    if let next {
                        focusedIndex = next
                        viewModel.focusNextIndex = nil
                    }
                }
                .onAppear { focusedIndex = 0 }

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.destructive)
                }

                if viewModel.isLoading {
                    VStack(spacing: AppSpacing.xxs) {
                        ProgressView()
                            .tint(AppColors.accent)
                        ForEach(viewModel.recentLogLines, id: \.self) { line in
                            Text(line)
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(AppColors.textSecondary)
                                .lineLimit(1)
                        }
                    }
                }

                Spacer()

                if viewModel.resendSeconds > 0 {
                    Text(L10n.authResendCountdown(viewModel.resendSeconds))
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textSecondary)
                } else {
                    Button(L10n.authResendCode) {
                        Task { await viewModel.resendCode() }
                    }
                    .font(AppTypography.headline)
                    .foregroundStyle(AppColors.accent)
                }
            }
            .padding(.bottom, AppSpacing.lg)

            DebugLogsButton(showLogs: $viewModel.showDebugLogs)
                .padding(AppSpacing.sm)
        }
        .sheet(isPresented: $viewModel.showDebugLogs) {
            DebugLogsView()
        }
    }
}
