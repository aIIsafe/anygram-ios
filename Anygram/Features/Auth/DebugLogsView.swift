import SwiftUI

/// Full-screen scrollable debug log viewer (temporary auth diagnostics).
struct DebugLogsView: View {
    @ObservedObject private var logger = AppDebugLogger.shared
    @Environment(\.dismiss) private var dismiss
    @State private var scrollID = UUID()

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    Text(logger.exportText().isEmpty ? "Нет записей" : logger.exportText())
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(AppColors.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(AppSpacing.sm)
                        .textSelection(.enabled)
                        .id(scrollID)
                }
                .background(AppColors.background)
                .onChange(of: logger.revision) { _, _ in
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
                    Button("Закрыть") { dismiss() }
                }
                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        logger.clear()
                    } label: {
                        Image(systemName: "trash")
                    }
                    Button {
                        scrollID = UUID()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    Button {
                        UIPasteboard.general.string = logger.exportText()
                    } label: {
                        Image(systemName: "doc.on.doc")
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

/// Small bug button that opens debug logs sheet.
struct DebugLogsButton: View {
    @Binding var showLogs: Bool

    var body: some View {
        Button {
            showLogs = true
        } label: {
            Image(systemName: "ladybug.fill")
                .font(.caption)
                .foregroundStyle(AppColors.textSecondary)
                .padding(8)
        }
        .accessibilityLabel("Логи")
    }
}
