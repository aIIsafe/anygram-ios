import Foundation

/// Generates realistic fake data for development and previews.
enum MockDataGenerator {
    static let currentUserID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    static let avatarColors = ["#FF6B6B", "#4ECDC4", "#45B7D1", "#96CEB4", "#FFEAA7", "#DDA0DD", "#98D8C8", "#F7DC6F", "#BB8FCE", "#85C1E9", "#F8B500", "#E74C3C", "#3498DB", "#2ECC71", "#9B59B6"]
    static let firstNames = ["Alex", "Jordan", "Taylor", "Morgan", "Casey", "Riley", "Quinn", "Avery", "Blake", "Cameron", "Drew", "Emery", "Finley", "Harper", "Hayden", "Jamie", "Kai", "Logan", "Noah", "Parker", "Reese", "River", "Rowan", "Sage", "Skyler"]
    static let lastNames = ["Smith", "Johnson", "Williams", "Brown", "Jones", "Garcia", "Miller", "Davis", "Rodriguez", "Martinez", "Anderson", "Taylor", "Thomas", "Moore", "Jackson", "Martin", "Lee", "Thomson", "White", "Harris", "Clark", "Lewis", "Walker", "Hall", "Young"]
    static let messageSamples = ["Hey, how are you?", "See you tomorrow!", "Thanks for the info 👍", "Can we meet at 3?", "Check this out", "LOL 😂", "On my way", "Got it, thanks!", "Let's discuss later", "Sent you the files", "Voice message", "Photo", "Video call?", "Missed you at the meeting", "Happy birthday! 🎉", "New project update", "Running late, sorry", "Perfect!", "Will do", "👀"]
    static let groupNames = ["Design Team", "Dev Squad", "Weekend Plans", "Family Group", "Book Club", "Travel Buddies", "Crypto Talk", "Music Lovers", "Fitness Crew", "Foodies"]
    static let channelNames = ["Tech News", "Daily Updates", "Announcements", "Tips & Tricks", "Community"]
    static let emojis = ["👍", "❤️", "🔥", "😂", "🎉", "👀", "💯", "🙏"]

    static func generateUsers(count: Int = 50) -> [User] {
        var users: [User] = []
        for index in 0..<count {
            let first = firstNames[index % firstNames.count]
            let last = lastNames[(index / firstNames.count) % lastNames.count]
            let name = index < 5 ? "\(first) \(last)" : (index % 3 == 0 ? "\(first) \(last)" : first)
            let username = name.lowercased().replacingOccurrences(of: " ", with: "_") + "\(index)"
            let isOnline = index % 7 == 0
            let lastSeen = isOnline ? nil : Date().addingTimeInterval(-Double(index * 3600))
            users.append(User(
                id: UUID(uuidString: String(format: "10000000-0000-0000-0000-%012d", index + 1)) ?? UUID(),
                name: name,
                username: username,
                avatarColorHex: avatarColors[index % avatarColors.count],
                lastSeen: lastSeen,
                phone: "+1 555 \(String(format: "%03d", 100 + index)) \(String(format: "%04d", 2000 + index))",
                bio: index % 4 == 0 ? "Available" : (index % 5 == 0 ? "Busy" : ""),
                status: index % 6 == 0 ? "At work" : "",
                isOnline: isOnline,
                isPremium: index % 11 == 0,
                isVerified: index % 13 == 0,
                isPinned: index < 3
            ))
        }
        return users
    }

    static func generateChats(users: [User], count: Int = 100) -> [Chat] {
        var chats: [Chat] = []
        let now = Date()
        let deliveryStates: [MessageDeliveryState] = [.sending, .sent, .delivered, .read]

        for index in 0..<count {
            let type: ChatType
            let title: String
            let participantIDs: [UUID]

            switch index % 10 {
            case 0:
                type = .savedMessages
                title = "Saved Messages"
                participantIDs = [currentUserID]
            case 1...2:
                type = .group
                title = groupNames[index % groupNames.count]
                participantIDs = Array(users.prefix(5).map(\.id))
            case 3:
                type = .channel
                title = channelNames[index % channelNames.count]
                participantIDs = []
            default:
                type = .privateChat
                let user = users[index % users.count]
                title = user.name
                participantIDs = [user.id]
            }

            chats.append(Chat(
                id: UUID(uuidString: String(format: "20000000-0000-0000-0000-%012d", index + 1)) ?? UUID(),
                title: title,
                type: type,
                participantIDs: participantIDs,
                lastMessage: index % 5 == 0 && type != .savedMessages ? "typing..." : messageSamples[index % messageSamples.count],
                lastMessageDate: now.addingTimeInterval(-Double(index * 1800)),
                unreadCount: index % 4 == 0 ? (index % 20) + 1 : 0,
                isPinned: index < 5,
                isMuted: index % 9 == 0,
                isArchived: index >= 95,
                isVerified: type == .channel || index % 17 == 0,
                isPremium: index % 15 == 0,
                avatarColorHex: avatarColors[index % avatarColors.count],
                deliveryState: deliveryStates[index % deliveryStates.count],
                isTyping: index % 5 == 0 && type == .privateChat
            ))
        }
        return chats
    }

    static func generateMessages(for chat: Chat, users: [User], count: Int = 40) -> [Message] {
        var messages: [Message] = []
        let baseDate = Date().addingTimeInterval(-Double(count * 300))
        let senderID = chat.participantIDs.first ?? users.first?.id ?? currentUserID
        let deliveryStates: [MessageDeliveryState] = [.sending, .sent, .delivered, .read]

        for index in 0..<count {
            let isOutgoing = index % 2 == 0
            let contentType: MessageContentType = {
                switch index % 8 {
                case 0: return .image
                case 1: return .voice
                case 2: return .video
                default: return .text
                }
            }()

            var attachment: Attachment?
            var text = messageSamples[index % messageSamples.count]
            switch contentType {
            case .image:
                text = "Photo"
                attachment = Attachment(fileName: "photo.jpg", mimeType: "image/jpeg", fileSize: 245_000, thumbnailColorHex: avatarColors[index % avatarColors.count], width: 800, height: 600)
            case .voice:
                text = "Voice message"
                attachment = Attachment(fileName: "voice.m4a", mimeType: "audio/m4a", fileSize: 48_000, duration: Double(5 + index % 30), thumbnailColorHex: "#3390EC")
            case .video:
                text = "Video"
                attachment = Attachment(fileName: "video.mp4", mimeType: "video/mp4", fileSize: 1_200_000, duration: Double(30 + index % 60), thumbnailColorHex: avatarColors[index % avatarColors.count], width: 1280, height: 720)
            default:
                break
            }

            var reactions: [Reaction] = []
            if index % 6 == 0 {
                reactions = [Reaction(emoji: emojis[index % emojis.count], count: 1 + index % 5)]
            }

            messages.append(Message(
                id: UUID(uuidString: String(format: "30000000-%04d-0000-0000-%08d", abs(chat.id.hashValue) & 0xFFFF, index + 1)) ?? UUID(),
                chatID: chat.id,
                senderID: isOutgoing ? currentUserID : senderID,
                text: text,
                contentType: contentType,
                timestamp: baseDate.addingTimeInterval(Double(index * 300)),
                isOutgoing: isOutgoing,
                isEdited: index % 10 == 0,
                isForwarded: index % 12 == 0,
                forwardedFrom: index % 12 == 0 ? "Original Channel" : nil,
                replyToMessageID: index % 7 == 0 && index > 0 ? messages[index - 1].id : nil,
                reactions: reactions,
                attachment: attachment,
                deliveryState: isOutgoing ? deliveryStates[index % deliveryStates.count] : .read
            ))
        }
        return messages
    }

    static func generateCalls(users: [User], count: Int = 30) -> [Call] {
        var calls: [Call] = []
        for index in 0..<count {
            let user = users[index % users.count]
            let direction: CallDirection = index % 5 == 0 ? .missed : (index % 2 == 0 ? .outgoing : .incoming)
            calls.append(Call(
                id: UUID(uuidString: String(format: "40000000-0000-0000-0000-%012d", index + 1)) ?? UUID(),
                userID: user.id,
                userName: user.name,
                avatarColorHex: user.avatarColorHex,
                direction: direction,
                mediaType: index % 3 == 0 ? .video : .voice,
                date: Date().addingTimeInterval(-Double(index * 7200)),
                duration: direction == .missed ? 0 : Double(30 + index * 15)
            ))
        }
        return calls.sorted { $0.date > $1.date }
    }

    static func generateDevices() -> [Device] {
        [
            Device(name: "iPhone 15 Pro", platform: "iOS 17.4", location: "New York, USA", lastActive: Date(), isCurrent: true),
            Device(name: "MacBook Pro", platform: "macOS 14.3", location: "New York, USA", lastActive: Date().addingTimeInterval(-3600)),
            Device(name: "iPad Air", platform: "iPadOS 17.2", location: "Boston, USA", lastActive: Date().addingTimeInterval(-86400 * 3))
        ]
    }

    static func generateFolders(chats: [Chat]) -> [Folder] {
        [
            Folder(name: "Personal", icon: "person.fill", chatIDs: Array(chats.prefix(10).map(\.id))),
            Folder(name: "Work", icon: "briefcase.fill", chatIDs: Array(chats.dropFirst(10).prefix(15).map(\.id))),
            Folder(name: "Unread", icon: "envelope.fill", chatIDs: chats.filter { $0.unreadCount > 0 }.prefix(20).map(\.id))
        ]
    }

    static func generateMedia(for userID: UUID, count: Int = 12) -> [Media] {
        let mediaTypes: [MediaType] = [.photo, .video, .file, .link, .voice]
        return (0..<count).map { index in
            Media(
                userID: userID,
                type: mediaTypes[index % mediaTypes.count],
                title: "Media \(index + 1)",
                thumbnailColorHex: avatarColors[index % avatarColors.count],
                date: Date().addingTimeInterval(-Double(index * 86400)),
                fileSize: Int64(100_000 + index * 50_000)
            )
        }
    }
}
