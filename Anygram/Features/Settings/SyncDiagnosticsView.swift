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
        #endif
        do {
            let chats = try await container.chatRepository.fetchChats(includeArchived: true)
            chatsCount = chats.count
            loaded.append(.init(
                title: L10n.diagnosticsChats,
                detail: L10n.diagnosticsCountFormat(chatsCount),
                isSuccess: true
            ))
        } catch {
            chatsCount = 0
            failed.append(.init(title: L10n.diagnosticsChats, detail: error.localizedDescription, isSuccess: false))
            hints.append(.init(title: L10n.diagnosticsChats, detail: L10n.diagnosticsHintChats, isSuccess: false))
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

        let recentErrors = AppDebugLogger.shared.recentErrors(8)
        for line in recentErrors {
            failed.append(.init(title: L10n.diagnosticsRecentError, detail: line, isSuccess: false))
        }

        if chatsCount == 0 && container.isAuthenticated {
            hints.append(.init(title: L10n.diagnosticsChats, detail: L10n.diagnosticsHintEmptyChats, isSuccess: false))
        }

        loadedItems = loaded
        failedItems = failed
        hintItems = hints
    }
}

struct SyncDiagnosticsView: View {
    @StateObject private var viewModel: SyncDiagnosticsViewModel
    @ObservedObject private var logger = AppDebugLogger.shared
    @State private var expandedCategories: Set<AppDebugLogger.Category> = Set(AppDebugLogger.Category.allCases)

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

                logsSection
            }
            .padding(AppSpacing.md)
        }
        .background(AppColors.background)
        .navigationTitle(L10n.diagnosticsTitle)
        .navigationBarTitleDisplayMode(.inline)
        .glassNavigationBar()
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    logger.clear()
                } label: {
                    Image(systemName: "trash")
                }
                .accessibilityLabel(L10n.diagnosticsClearLogs)

                Button {
                    UIPasteboard.general.string = logger.exportText()
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .accessibilityLabel(L10n.diagnosticsCopyLogs)

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

    private var logsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(L10n.diagnosticsLogs)
                .font(AppTypography.headline)
                .foregroundStyle(AppColors.textPrimary)

            ForEach(AppDebugLogger.Category.allCases, id: \.self) { category in
                let lines = logger.lines(for: category)
                DisclosureGroup(isExpanded: binding(for: category)) {
                    if lines.isEmpty {
                        Text(L10n.diagnosticsNoLogs)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(AppColors.textTertiary)
                            .padding(.vertical, AppSpacing.xs)
                    } else {
                        Text(lines.joined(separator: "\n"))
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(AppColors.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                            .padding(.vertical, AppSpacing.xs)
                    }
                } label: {
                    HStack {
                        Text(category.rawValue)
                            .font(AppTypography.captionBold)
                        Spacer()
                        Text("\(lines.count)")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.textTertiary)
                    }
                }
                .tint(AppColors.accent)
            }
        }
    }

    private func binding(for category: AppDebugLogger.Category) -> Binding<Bool> {
        Binding(
            get: { expandedCategories.contains(category) },
            set: { isExpanded in
                if isExpanded {
                    expandedCategories.insert(category)
                } else {
                    expandedCategories.remove(category)
                }
            }
        )
    }
}
