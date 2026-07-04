import SwiftUI

struct PhoneInputView: View {
    @ObservedObject var viewModel: AuthViewModel
    @State private var showCountryPicker = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: AppSpacing.lg) {
                VStack(spacing: AppSpacing.sm) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(AppColors.accent)
                        .padding(.top, AppSpacing.xxl)

                    Text(L10n.authTitle)
                        .font(AppTypography.largeTitle)
                        .foregroundStyle(AppColors.textPrimary)

                    Text(L10n.authSubtitle)
                        .font(AppTypography.subheadline)
                        .foregroundStyle(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AppSpacing.lg)
                }

                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text(L10n.authPhoneTitle)
                        .font(AppTypography.headline)
                        .foregroundStyle(AppColors.textPrimary)

                    Text(L10n.authPhoneHint)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textSecondary)

                    HStack(spacing: AppSpacing.sm) {
                        Button {
                            showCountryPicker = true
                        } label: {
                            HStack(spacing: AppSpacing.xxs) {
                                Text(viewModel.selectedCountry.flag)
                                Text(viewModel.selectedCountry.dialCode)
                                    .font(AppTypography.body)
                                    .foregroundStyle(AppColors.textPrimary)
                                Image(systemName: "chevron.down")
                                    .font(.caption)
                                    .foregroundStyle(AppColors.textSecondary)
                            }
                            .padding(.horizontal, AppSpacing.sm)
                            .padding(.vertical, AppSpacing.sm)
                        }
                        .liquidGlass(cornerRadius: AppRadius.medium)

                        TextField("(___) ___-__-__", text: Binding(
                            get: { viewModel.formattedPhone },
                            set: { newValue in
                                viewModel.phoneLocal = newValue.filter(\.isNumber)
                            }
                        ))
                        .keyboardType(.phonePad)
                        .font(AppTypography.title)
                        .foregroundStyle(AppColors.textPrimary)
                        .padding(.horizontal, AppSpacing.sm)
                        .padding(.vertical, AppSpacing.sm)
                        .liquidGlass(cornerRadius: AppRadius.medium)
                    }
                }
                .padding(.horizontal, AppSpacing.lg)

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.destructive)
                        .padding(.horizontal, AppSpacing.lg)

                    if viewModel.showWipeAndRetry {
                        Button(L10n.authWipeAndRetry) {
                            Task { await viewModel.wipeStorageAndRetry() }
                        }
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.accent)
                        .disabled(viewModel.isLoading)
                    }

                    if viewModel.showOpenLogsAfterError {
                        Button("Открыть логи") {
                            viewModel.showDebugLogs = true
                        }
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.accent)
                    }
                }

                if viewModel.isLoading {
                    VStack(spacing: AppSpacing.xs) {
                        if let progress = viewModel.flowProgressText {
                            Text(progress)
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(AppColors.textSecondary)
                        }
                        HStack(spacing: AppSpacing.xs) {
                            ProgressView()
                                .controlSize(.small)
                            Text("\(viewModel.loadingElapsedSeconds)с")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(AppColors.textSecondary)
                            if let status = viewModel.connectionStatusText {
                                Text(status)
                                    .font(AppTypography.caption)
                                    .foregroundStyle(AppColors.textSecondary)
                            }
                        }
                        ForEach(viewModel.recentLogLines, id: \.self) { line in
                            Text(line)
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(AppColors.textSecondary.opacity(0.85))
                                .lineLimit(2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.horizontal, AppSpacing.lg)
                } else if let status = viewModel.connectionStatusText {
                    HStack(spacing: AppSpacing.xs) {
                        ProgressView()
                            .controlSize(.small)
                        Text(status)
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                    .padding(.horizontal, AppSpacing.lg)
                }

                if viewModel.usesScaffoldAuth {
                    Text(L10n.authScaffoldNotice)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AppSpacing.lg)
                }

                Spacer()

                Button {
                    Task { await viewModel.submitPhone() }
                } label: {
                    Group {
                        if viewModel.isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text(L10n.authContinue)
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

            DebugLogsButton(showLogs: $viewModel.showDebugLogs)
                .padding(AppSpacing.sm)
        }
        .sheet(isPresented: $showCountryPicker) {
            CountryPickerView(selectedCountry: $viewModel.selectedCountry)
                .glassSheetBackground()
        }
    }
}

private struct CountryPickerView: View {
    @Binding var selectedCountry: Country
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var filtered: [Country] {
        guard !query.isEmpty else { return Country.all }
        return Country.all.filter {
            $0.name.localizedCaseInsensitiveContains(query) ||
            $0.dialCode.contains(query)
        }
    }

    var body: some View {
        NavigationStack {
            List(filtered) { country in
                Button {
                    selectedCountry = country
                    dismiss()
                } label: {
                    HStack {
                        Text(country.flag)
                        Text(country.name)
                            .foregroundStyle(AppColors.textPrimary)
                        Spacer()
                        Text(country.dialCode)
                            .foregroundStyle(AppColors.textSecondary)
                        if country.id == selectedCountry.id {
                            Image(systemName: "checkmark")
                                .foregroundStyle(AppColors.accent)
                        }
                    }
                }
                .listRowBackground(AppColors.secondaryBackground)
            }
            .scrollContentBackground(.hidden)
            .background(AppColors.background)
            .searchable(text: $query, prompt: L10n.authCountry)
            .navigationTitle(L10n.authCountry)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.cancel) { dismiss() }
                }
            }
            .glassNavigationBar()
        }
        .presentationDetents([.medium, .large])
    }
}
