import SwiftUI

/// Full-screen scrollable debug log viewer (temporary auth diagnostics).
struct DebugLogsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var logText = ""
    @State private var isLoading = true
    @State private var scrollID = UUID()

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    Group {
                        if isLoading && logText.isEmpty {
                            ProgressView()
                                .frame(maxWidth: .infinity, minHeight: 120)
                        } else {
                            Text(logText.isEmpty ? "Нет записей" : logText)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(AppColors.textPrimary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .textSelection(.enabled)
                        }
                    }
                    .padding(AppSpacing.sm)
                    .id(scrollID)
                }
                .background(AppColors.background)
                .onChange(of: logText) { _, _ in
                    scrollID = UUID()
                    withAnimation(.easeOut(duration: 0.15)) {
                        proxy.scrollTo(scrollID, anchor: .bottom)
                    }
                }
                .onAppear {
                    proxy.scrollTo(scrollID, anchor: .bottom)
                }
            }
            .navigationTitle("Логи")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppColors.background, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Назад") { dismiss() }
                }
                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        AppDebugLogger.shared.clear()
                    } label: {
                        Image(systemName: "trash")
                    }
                    Button {
                        Task { await reloadLogs(scrollToBottom: true) }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    Button {
                        Task {
                            let text = await loadExportText()
                            UIPasteboard.general.string = text
                        }
                    } label: {
                        Image(systemName: "doc.on.doc")
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .task { await reloadLogs(scrollToBottom: false) }
        .onReceive(
            AppDebugLogger.shared.$revision
                .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
        ) { _ in
            Task { await reloadLogs(scrollToBottom: true) }
        }
    }

    @MainActor
    private func reloadLogs(scrollToBottom: Bool) async {
        isLoading = true
        let text = await loadExportText()
        logText = text
        isLoading = false
        if scrollToBottom {
            scrollID = UUID()
        }
    }

    private func loadExportText() async -> String {
        await Task.detached {
            AppDebugLogger.shared.makeSnapshot().exportText
        }.value
    }
}

/// Small bug button that opens debug logs page (NavigationStack push).
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
