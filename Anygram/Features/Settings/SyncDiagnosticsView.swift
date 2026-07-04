import SwiftUI

struct DiagnosticItem: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let detail: String
    let isSuccess: Bool
}

@MainActor
final class SyncDiagnosticsViewModel: ObservableObject {
    @Published var loadedItems: [DiagnosticItem] = []
    @Published var failedItems: [DiagnosticItem] = []
    @Published var hintItems: [DiagnosticItem] = []
    @Published var isRefreshing = false
    @Published var logFileSizeText = ""

    private let container: DIContainer

    init(container: DIContainer) {
        self.container = container
    }

    func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }

        var loaded: [DiagnosticItem] = []
        var failed: [DiagnosticItem] = []
        var hints: [DiagnosticItem] = []

        if container.isAuthenticated {
            loaded.append(.init(title: L10n.diagnosticsAuth, detail: L10n.diagnosticsAuthOk, isSuccess: true))
        } else {
            failed.append(.init(title: L10n.diagnosticsAuth, detail: L10n.diagnosticsAuthFailed, isSuccess: false))
            hints.append(.init(title: L10n.diagnosticsAuth, detail: L10n.diagnosticsHintAuth, isSuccess: false))
        }

        #if canImport(TDLibKit)
        if TDLibAccessGate.shared.canCallAuthenticatedAPI {
            loaded.append(.init(title: "TDLib", detail: L10n.diagnosticsTdlibReady, isSuccess: true))
        } else {
            failed.append(.init(title: "TDLib", detail: L10n.diagnosticsTdlibNotReady, isSuccess: false))
            hints.append(.init(title: "TDLib", detail: L10n.diagnosticsHintTdlib, isSuccess: false))
        }

        let chatSync = TDLibChatService.currentSyncDiagnostics()
        if chatSync.isLoading {
            loaded.append(.init(
                title: L10n.diagnosticsChats,
                detail: L10n.diagnosticsChatsLoading,
                isSuccess: true
            ))
        } else if let error = chatSync.lastError, !error.isEmpty {
            failed.append(.init(
                title: L10n.diagnosticsChats,
                detail: L10n.diagnosticsChatsError(error),
                isSuccess: false
            ))
            hints.append(.init(title: L10n.diagnosticsChats, detail: L10n.diagnosticsHintChats, isSuccess: false))
        } else {
            loaded.append(.init(
                title: L10n.diagnosticsChats,
                detail: L10n.diagnosticsChatsLoaded(chatSync.loadedCount),
                isSuccess: true
            ))
        }
        #endif

        let chatsCount: Int
        do {
            let chats = try await container.chatRepository.fetchChats(includeArchived: true)
            chatsCount = chats.count
            loaded.append(.init(
                title: L10n.diagnosticsChatsFetch,
                detail: L10n.diagnosticsCountFormat(chatsCount),
                isSuccess: true
            ))
        } catch {
            chatsCount = 0
            failed.append(.init(title: L10n.diagnosticsChatsFetch, detail: error.localizedDescription, isSuccess: false))
            hints.append(.init(title: L10n.diagnosticsChatsFetch, detail: L10n.diagnosticsHintChats, isSuccess: false))
        }

        let contactsCount: Int
        do {
            let contacts = try await container.userRepository.fetchContacts()
            contactsCount = contacts.count
            loaded.append(.init(
                title: L10n.diagnosticsContacts,
                detail: L10n.diagnosticsCountFormat(contactsCount),
                isSuccess: true
            ))
        } catch {
            contactsCount = 0
            failed.append(.init(title: L10n.diagnosticsContacts, detail: error.localizedDescription, isSuccess: false))
        }

        let prefetchedChats = chatsCount > 0 ? min(chatsCount, 5) : 0
        if prefetchedChats > 0 {
            loaded.append(.init(
                title: L10n.diagnosticsMessages,
                detail: L10n.diagnosticsMessagesPrefetch(prefetchedChats),
                isSuccess: true
            ))
        }

        do {
            let calls = try await container.callsRepository.fetchCalls(filter: .all)
            if calls.isEmpty {
                loaded.append(.init(title: L10n.diagnosticsCalls, detail: L10n.diagnosticsCallsEmpty, isSuccess: true))
            } else {
                loaded.append(.init(
                    title: L10n.diagnosticsCalls,
                    detail: L10n.diagnosticsCountFormat(calls.count),
                    isSuccess: true
                ))
            }
        } catch {
            failed.append(.init(title: L10n.diagnosticsCalls, detail: error.localizedDescription, isSuccess: false))
        }

        for line in AppDebugLogger.shared.recentErrors(8) {
            failed.append(.init(title: L10n.diagnosticsRecentError, detail: line, isSuccess: false))
        }

        if chatsCount == 0 && container.isAuthenticated {
            hints.append(.init(title: L10n.diagnosticsChats, detail: L10n.diagnosticsHintEmptyChats, isSuccess: false))
        }

        logFileSizeText = Self.formatByteCount(AppDebugLogger.shared.logFileByteCount())
        loadedItems = loaded
        failedItems = failed
        hintItems = hints
    }

    private static func formatByteCount(_ bytes: Int) -> String {
        if bytes < 1024 { return "\(bytes) B" }
        if bytes < 1024 * 1024 { return String(format: "%.1f KB", Double(bytes) / 1024) }
        return String(format: "%.1f MB", Double(bytes) / (1024 * 1024))
    }
}

struct SyncDiagnosticsView: View {
    @StateObject private var viewModel: SyncDiagnosticsViewModel
    @State private var showShareSheet = false

    init(container: DIContainer) {
        _viewModel = StateObject(wrappedValue: SyncDiagnosticsViewModel(container: container))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                diagnosticsSection(
                    title: L10n.diagnosticsLoaded,
                    icon: "checkmark.circle.fill",
                    color: AppColors.online,
                    items: viewModel.loadedItems
                )

                if !viewModel.failedItems.isEmpty {
                    diagnosticsSection(
                        title: L10n.diagnosticsFailed,
                        icon: "xmark.circle.fill",
                        color: AppColors.destructive,
                        items: viewModel.failedItems
                    )
                }

                if !viewModel.hintItems.isEmpty {
                    diagnosticsSection(
                        title: L10n.diagnosticsHints,
                        icon: "lightbulb.fill",
                        color: AppColors.premium,
                        items: viewModel.hintItems
                    )
                }

                exportSection
            }
            .padding(AppSpacing.md)
        }
        .background(AppColors.background)
        .navigationTitle(L10n.diagnosticsTitle)
        .navigationBarTitleDisplayMode(.inline)
        .glassNavigationBar()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await viewModel.refresh() }
                } label: {
                    if viewModel.isRefreshing {
                        ProgressView()
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .accessibilityLabel(L10n.diagnosticsRefresh)
            }
        }
        .task { await viewModel.refresh() }
        .sheet(isPresented: $showShareSheet) {
            LogFileShareSheet(url: AppDebugLogger.shared.logFileURL())
        }
    }

    @ViewBuilder
    private func diagnosticsSection(
        title: String,
        icon: String,
        color: Color,
        items: [DiagnosticItem]
    ) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Label(title, systemImage: icon)
                .font(AppTypography.headline)
                .foregroundStyle(color)

            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title)
                            .font(AppTypography.captionBold)
                            .foregroundStyle(AppColors.textPrimary)
                        Text(item.detail)
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(AppSpacing.sm)

                    if index < items.count - 1 {
                        Divider().background(AppColors.separator)
                    }
                }
            }
            .glassCard()
        }
    }

    private var exportSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(L10n.diagnosticsLogs)
                .font(AppTypography.headline)
                .foregroundStyle(AppColors.textPrimary)

            Text(L10n.diagnosticsLogFileHint(viewModel.logFileSizeText))
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textSecondary)

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
        }
        .glassCard()
        .padding(.vertical, AppSpacing.xs)
    }
}

private struct LogFileShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
