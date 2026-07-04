import SwiftUI

struct ChatDetailView: View {
    let chat: Chat
    @StateObject private var viewModel: ChatDetailViewModel
    @FocusState private var isInputFocused: Bool
    @Environment(\.dismiss) private var dismiss

    init(chat: Chat, container: DIContainer) {
        self.chat = chat
        _viewModel = StateObject(wrappedValue: ChatDetailViewModel(chat: chat, repository: container.chatRepository))
    }

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.isLoading && viewModel.messages.isEmpty {
                LoadingView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.messages.isEmpty, let error = viewModel.errorMessage {
                ContentUnavailableView(L10n.chatLoadFailed, systemImage: "exclamationmark.triangle", description: Text(error))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.messages.isEmpty {
                ContentUnavailableView(L10n.chatEmptyTitle, systemImage: "message", description: Text(L10n.chatEmptyDescription))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: AppSpacing.sm) {
                        ForEach(Array(viewModel.groupedMessages().enumerated()), id: \.offset) { _, group in
                            Text(group.0)
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.textSecondary)
                                .padding(.horizontal, AppSpacing.sm)
                                .padding(.vertical, AppSpacing.xxs)
                                .background(AppColors.tertiaryBackground.opacity(0.6))
                                .clipShape(Capsule())
                                .padding(.vertical, AppSpacing.xs)

                            ForEach(group.1) { message in
                                if viewModel.unreadSeparatorIndex == viewModel.messages.firstIndex(of: message) {
                                    HStack {
                                        Rectangle().fill(AppColors.accent).frame(height: 1)
                                        Text(L10n.unreadMessages)
                                            .font(AppTypography.caption)
                                            .foregroundStyle(AppColors.accent)
                                        Rectangle().fill(AppColors.accent).frame(height: 1)
                                    }
                                    .padding(.vertical, AppSpacing.xs)
                                }

                                messageRow(message)
                                    .id(message.id)
                            }
                        }

                        if viewModel.isTyping {
                            HStack {
                                TypingIndicatorView()
                                Text(L10n.typing + "...")
                                    .font(AppTypography.caption)
                                    .foregroundStyle(AppColors.textSecondary)
                                Spacer()
                            }
                            .padding(.horizontal, AppSpacing.md)
                        }
                    }
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, AppSpacing.sm)
                }
                .onChange(of: viewModel.messages.count) { _, _ in
                    if let last = viewModel.messages.last {
                        withAnimation(AppAnimation.standard) {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }

            if let reply = viewModel.replyToMessage {
                HStack {
                    Rectangle().fill(AppColors.accent).frame(width: 3)
                    VStack(alignment: .leading) {
                        Text(L10n.replyTo)
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.accent)
                        Text(reply.text)
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.textSecondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    Button { viewModel.replyToMessage = nil } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }
                .padding(AppSpacing.sm)
                .liquidGlass(cornerRadius: AppRadius.small)
            }

            HStack(spacing: AppSpacing.sm) {
                Button {} label: {
                    Image(systemName: "paperclip")
                        .foregroundStyle(AppColors.textSecondary)
                }
                TextField(L10n.messagePlaceholder, text: $viewModel.inputText, axis: .vertical)
                    .lineLimit(1...5)
                    .focused($isInputFocused)
                    .padding(.horizontal, AppSpacing.sm)
                    .padding(.vertical, AppSpacing.xs)
                    .liquidGlass(cornerRadius: AppRadius.large)
                Button {
                    Task { await viewModel.sendMessage() }
                } label: {
                    Image(systemName: viewModel.inputText.isEmpty ? "mic.fill" : "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundStyle(AppColors.accent)
                }
            }
            .padding(AppSpacing.sm)
            .liquidGlass(cornerRadius: 0)
            }
        }
        .background(AppColors.background)
        .navigationTitle(chat.title)
        .navigationBarTitleDisplayMode(.inline)
        .glassNavigationBar()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    if let userID = chat.participantIDs.first {
                        ProfileView(userID: userID, container: DIContainer.shared)
                    }
                } label: {
                    AvatarView(name: chat.title, colorHex: chat.avatarColorHex, size: 32)
                }
            }
        }
        .task { await viewModel.load() }
        .onDisappear {
            Task { await viewModel.close() }
        }
    }

    @ViewBuilder
    private func messageRow(_ message: Message) -> some View {
        MessageBubbleView(
            message: message,
            replyPreview: message.replyToMessageID.flatMap { viewModel.replyPreview(for: $0) },
            isSelected: viewModel.selectedMessageIDs.contains(message.id)
        )
        .onTapGesture {
            if !viewModel.selectedMessageIDs.isEmpty {
                viewModel.toggleSelection(message)
            }
        }
        .onLongPressGesture {
            viewModel.toggleSelection(message)
        }
        .gesture(
            DragGesture(minimumDistance: 30)
                .onEnded { value in
                    if value.translation.width > 50 {
                        viewModel.replyToMessage = message
                    }
                }
        )
        .contextMenu {
            Button { viewModel.replyToMessage = message } label: {
                Label(L10n.reply, systemImage: "arrowshape.turn.up.left")
            }
            Button { Task { await viewModel.addReaction("👍", to: message) } } label: {
                Label(L10n.react, systemImage: "face.smiling")
            }
            Button { viewModel.toggleSelection(message) } label: {
                Label(L10n.select, systemImage: "checkmark.circle")
            }
            Button {} label: {
                Label(L10n.forward, systemImage: "arrowshape.turn.up.right")
            }
            Button {} label: {
                Label(L10n.copy, systemImage: "doc.on.doc")
            }
        }
    }
}
