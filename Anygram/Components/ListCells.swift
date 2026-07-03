import SwiftUI

struct DeliveryStatusView: View {
    let state: MessageDeliveryState

    var body: some View {
        switch state {
        case .sending:
            Image(systemName: "clock")
                .font(.system(size: 10))
                .foregroundStyle(AppColors.textTertiary)
        case .sent:
            Image(systemName: "checkmark")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(AppColors.textTertiary)
        case .delivered:
            Image(systemName: "checkmark")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(AppColors.textSecondary)
        case .read:
            HStack(spacing: -4) {
                Image(systemName: "checkmark")
                Image(systemName: "checkmark")
            }
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(AppColors.accent)
        case .failed:
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 10))
                .foregroundStyle(AppColors.destructive)
        }
    }
}

struct MessageBubbleView: View {
    let message: Message
    var replyPreview: String?
    var isSelected: Bool

    var body: some View {
        VStack(alignment: message.isOutgoing ? .trailing : .leading, spacing: AppSpacing.xxs) {
            if message.isForwarded, let from = message.forwardedFrom {
                HStack(spacing: 4) {
                    Image(systemName: "arrowshape.turn.up.right.fill")
                        .font(.system(size: 10))
                    Text("Forwarded from \(from)")
                        .font(AppTypography.caption)
                }
                .foregroundStyle(AppColors.accent)
            }

            if let reply = replyPreview {
                HStack {
                    Rectangle()
                        .fill(AppColors.accent)
                        .frame(width: 2)
                    Text(reply)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textSecondary)
                        .lineLimit(1)
                }
                .padding(AppSpacing.xxs)
                .background(AppColors.background.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.small))
            }

            HStack(alignment: .bottom, spacing: AppSpacing.xxs) {
                messageContent
                VStack(alignment: .trailing, spacing: 0) {
                    HStack(spacing: 2) {
                        Text(message.timestamp.formatted(date: .omitted, time: .shortened))
                            .font(.system(size: 11))
                            .foregroundStyle(AppColors.textTertiary)
                        if message.isEdited {
                            Text("edited")
                                .font(.system(size: 11))
                                .foregroundStyle(AppColors.textTertiary)
                        }
                        if message.isOutgoing {
                            DeliveryStatusView(state: message.deliveryState)
                        }
                    }
                }
            }
            .padding(.horizontal, AppSpacing.sm)
            .padding(.vertical, AppSpacing.xs)
            .background(message.isOutgoing ? AppColors.bubbleOutgoing : AppColors.bubbleIncoming)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.bubble))
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: AppRadius.bubble)
                        .stroke(AppColors.accent, lineWidth: 2)
                }
            }

            if !message.reactions.isEmpty {
                HStack(spacing: 4) {
                    ForEach(message.reactions) { reaction in
                        Text("\(reaction.emoji) \(reaction.count)")
                            .font(AppTypography.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(AppColors.tertiaryBackground)
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: message.isOutgoing ? .trailing : .leading)
        .accessibilityLabel(AccessibilityLabels.message(message))
    }

    @ViewBuilder
    private var messageContent: some View {
        switch message.contentType {
        case .image:
            RoundedRectangle(cornerRadius: AppRadius.small)
                .fill(Color(hex: message.attachment?.thumbnailColorHex ?? "#3390EC"))
                .frame(width: 200, height: 150)
                .overlay {
                    Image(systemName: "photo")
                        .font(.largeTitle)
                        .foregroundStyle(.white.opacity(0.8))
                }
        case .voice:
            HStack {
                Image(systemName: "waveform")
                Text(Date.formatDuration(message.attachment?.duration ?? 0))
                    .font(AppTypography.subheadline)
            }
            .foregroundStyle(AppColors.textPrimary)
        case .video:
            RoundedRectangle(cornerRadius: AppRadius.small)
                .fill(Color(hex: message.attachment?.thumbnailColorHex ?? "#3390EC"))
                .frame(width: 200, height: 120)
                .overlay {
                    Image(systemName: "play.circle.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.white.opacity(0.9))
                }
        default:
            Text(message.text)
                .font(AppTypography.body)
                .foregroundStyle(AppColors.textPrimary)
        }
    }
}

struct SettingsRowView: View {
    let icon: String
    let title: String
    var subtitle: String?
    var iconColor: Color = AppColors.accent
    var showChevron: Bool = true

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(iconColor)
                .clipShape(RoundedRectangle(cornerRadius: 7))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppTypography.body)
                    .foregroundStyle(AppColors.textPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }

            Spacer()

            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppColors.textTertiary)
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.xs)
        .contentShape(Rectangle())
    }
}

struct ChatRowView: View {
    let chat: Chat

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            AvatarView(name: chat.title, colorHex: chat.avatarColorHex, size: 54)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(chat.title)
                        .font(AppTypography.headline)
                        .foregroundStyle(AppColors.textPrimary)
                        .lineLimit(1)
                    if chat.isVerified { VerifiedBadge() }
                    if chat.isPremium { PremiumBadge() }
                    Spacer()
                    Text(chat.lastMessageDate.chatListFormatted)
                        .font(AppTypography.caption)
                        .foregroundStyle(chat.unreadCount > 0 ? AppColors.accent : AppColors.textSecondary)
                }

                HStack {
                    if chat.isTyping {
                        TypingIndicatorView()
                    } else {
                        HStack(spacing: 4) {
                            DeliveryStatusView(state: chat.deliveryState)
                            Text(chat.lastMessage)
                                .font(AppTypography.subheadline)
                                .foregroundStyle(AppColors.textSecondary)
                                .lineLimit(1)
                        }
                    }
                    Spacer()
                    HStack(spacing: 4) {
                        if chat.isMuted {
                            Image(systemName: "speaker.slash.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(AppColors.muted)
                        }
                        if chat.isPinned {
                            Image(systemName: "pin.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(AppColors.textTertiary)
                                .rotationEffect(.degrees(45))
                        }
                        BadgeView(count: chat.unreadCount, isMuted: chat.isMuted)
                    }
                }
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.xs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(AccessibilityLabels.chat(chat))
    }
}

struct ContactRowView: View {
    let user: User

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            AvatarView(
                name: user.name,
                colorHex: user.avatarColorHex,
                size: 48,
                isOnline: user.isOnline,
                showOnlineIndicator: true
            )

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(user.name)
                        .font(AppTypography.headline)
                        .foregroundStyle(AppColors.textPrimary)
                    if user.isVerified { VerifiedBadge() }
                    if user.isPremium { PremiumBadge() }
                }
                Text(statusText)
                    .font(AppTypography.caption)
                    .foregroundStyle(user.isOnline ? AppColors.online : AppColors.textSecondary)
            }

            Spacer()
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.xs)
        .accessibilityLabel(AccessibilityLabels.contact(user))
    }

    private var statusText: String {
        if user.isOnline { return "online" }
        if let lastSeen = user.lastSeen { return lastSeen.lastSeenFormatted }
        return user.status.isEmpty ? "offline" : user.status
    }
}

struct CallRowView: View {
    let call: Call

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            AvatarView(name: call.userName, colorHex: call.avatarColorHex, size: 48)

            VStack(alignment: .leading, spacing: 2) {
                Text(call.userName)
                    .font(AppTypography.headline)
                    .foregroundStyle(call.direction == .missed ? AppColors.destructive : AppColors.textPrimary)
                HStack(spacing: 4) {
                    Image(systemName: directionIcon)
                        .font(.system(size: 12))
                        .foregroundStyle(AppColors.textSecondary)
                    Text(subtitle)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(call.date.chatListFormatted)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
                Image(systemName: call.mediaType == .video ? "video.fill" : "phone.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(AppColors.accent)
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.xs)
        .accessibilityLabel(AccessibilityLabels.call(call))
    }

    private var directionIcon: String {
        switch call.direction {
        case .incoming: return "arrow.down.left"
        case .outgoing: return "arrow.up.right"
        case .missed: return "phone.arrow.down.left"
        }
    }

    private var subtitle: String {
        if call.direction == .missed { return "Missed" }
        return Date.formatDuration(call.duration)
    }
}

