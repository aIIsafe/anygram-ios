import SwiftUI

/// Export-only debug logs screen (no heavy in-app log text).
struct DebugLogsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showShareSheet = false
    @State private var logFileSizeText = "—"
    @State private var recentErrors: [String] = []

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Text(L10n.diagnosticsLogFileHint(logFileSizeText))
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)

                if !recentErrors.isEmpty {
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text(L10n.diagnosticsRecentError)
                            .font(AppTypography.captionBold)
                            .foregroundStyle(AppColors.textPrimary)
                        ForEach(recentErrors, id: \.self) { line in
                            Text(line)
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(AppColors.textSecondary)
                                .lineLimit(2)
                        }
                    }
                    .padding(AppSpacing.sm)
                    .glassCard()
                }

                Button {
                    AppDebugLogger.shared.flushNow()
                    showShareSheet = true
                } label: {
                    Label(L10n.diagnosticsExportLogs, systemImage: "square.and.arrow.up")
                        .font(AppTypography.body)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppSpacing.sm)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppColors.accent)

                Spacer()
            }
            .padding(AppSpacing.md)
            .background(AppColors.background)
            .navigationTitle("Логи")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppColors.background, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Назад") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { refreshSummary() }
        .sheet(isPresented: $showShareSheet) {
            LogFileShareSheet(url: AppDebugLogger.shared.logFileURL())
        }
    }

    private func refreshSummary() {
        logFileSizeText = formatByteCount(AppDebugLogger.shared.logFileByteCount())
        recentErrors = AppDebugLogger.shared.recentErrors(5)
    }

    private func formatByteCount(_ bytes: Int) -> String {
        if bytes < 1024 { return "\(bytes) B" }
        if bytes < 1024 * 1024 { return String(format: "%.1f KB", Double(bytes) / 1024) }
        return String(format: "%.1f MB", Double(bytes) / (1024 * 1024))
    }
}

private struct LogFileShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

/// Small bug button that opens debug logs export page.
struct DebugLogsButton: View {
    @Binding var showLogs: Bool

    var body: some View {
        Button {
            showLogs = true
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "ladybug.fill")
                    .font(.caption)
                Text("Логи")
                    .font(.caption)
            }
            .foregroundStyle(AppColors.textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
        }
        .accessibilityLabel("Логи")
    }
}
