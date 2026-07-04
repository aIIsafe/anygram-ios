import Combine
import Foundation

#if canImport(TDLibKit)
import TDLibKit

/// TDLib-backed call history via `searchCallMessages`.
public final class TDLibCallsService: CallsServiceProtocol, @unchecked Sendable {
    private var calls: [Call] = []
    private let callsSubject: CurrentValueSubject<[Call], Never>
    private let lock = NSLock()

    public init() {
        self.callsSubject = CurrentValueSubject([])
    }

    public func fetchCalls(filter: CallFilter) async throws -> [Call] {
        await waitForAuthorizedAccess()
        guard TDLibAccessGate.shared.canCallAuthenticatedAPI else { return [] }
        guard let client = TDLibSession.shared.tdClient else { return [] }

        let onlyMissed = filter == .missed
        do {
            let found = try await client.searchCallMessages(
                limit: 100,
                offset: "",
                onlyMissed: onlyMissed
            )
            var mapped: [Call] = []
            for message in found.messages {
                if let call = await mapCallMessage(message, client: client) {
                    mapped.append(call)
                }
            }
            mapped.sort { $0.date > $1.date }

            lock.lock()
            calls = mapped
            lock.unlock()
            callsSubject.send(mapped)
            AppDebugLogger.shared.log("searchCallMessages count=\(mapped.count) missed=\(onlyMissed)", category: .TDLIB)
            return mapped
        } catch {
            AppDebugLogger.shared.log(
                "searchCallMessages failed: \(Self.tdlibErrorMessage(error))",
                category: .ERROR
            )
            lock.lock()
            let snapshot = calls
            lock.unlock()
            return snapshot
        }
    }

    public func deleteCall(_ callID: UUID) async throws {
        lock.lock()
        calls.removeAll { $0.id == callID }
        let updated = calls
        lock.unlock()
        callsSubject.send(updated)
    }

    public func observeCalls() -> AnyPublisher<[Call], Never> {
        callsSubject.eraseToAnyPublisher()
    }

    private func waitForAuthorizedAccess() async {
        for _ in 0..<30 {
            if TDLibAccessGate.shared.canCallAuthenticatedAPI { return }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
    }

    private func mapCallMessage(_ message: TDLibKit.Message, client: TDLibClient) async -> Call? {
        guard case .messageCall(let callInfo) = message.content else { return nil }

        let partnerId = await partnerUserId(for: message, client: client)
        let userName: String
        let avatarHex: String
        if let partnerId,
           let tdUser = try? await client.getUser(userId: partnerId) {
            let first = tdUser.firstName
            let last = tdUser.lastName
            userName = [first, last].filter { !$0.isEmpty }.joined(separator: " ")
            avatarHex = TelegramIdentity.colorHex(forTelegramId: partnerId)
        } else {
            userName = L10n.unknownUser
            avatarHex = TelegramIdentity.colorHex(forTelegramId: message.chatId)
        }

        let direction = callDirection(from: message, callInfo: callInfo)
        let mediaType: CallMediaType = callInfo.isVideo ? .video : .voice

        return Call(
            id: TelegramIdentity.messageUUID(chatId: message.chatId, messageId: message.id),
            userID: partnerId.map { TelegramIdentity.uuid(fromTelegramId: $0) } ?? TelegramIdentity.uuid(fromTelegramId: message.chatId),
            userName: userName.isEmpty ? L10n.unknownUser : userName,
            avatarColorHex: avatarHex,
            direction: direction,
            mediaType: mediaType,
            date: Date(timeIntervalSince1970: TimeInterval(message.date)),
            duration: TimeInterval(callInfo.duration)
        )
    }

    private func partnerUserId(for message: TDLibKit.Message, client: TDLibClient) async -> Int64? {
        if case .messageSenderUser(let sender) = message.senderId {
            return sender.userId
        }
        if let tdChat = try? await client.getChat(chatId: message.chatId),
           case .chatTypePrivate(let info) = tdChat.type {
            return info.userId
        }
        return nil
    }

    private func callDirection(from message: TDLibKit.Message, callInfo: MessageCall) -> CallDirection {
        switch callInfo.discardReason {
        case .callDiscardReasonMissed, .callDiscardReasonDeclined:
            return .missed
        default:
            break
        }
        return message.isOutgoing ? .outgoing : .incoming
    }

    private static func tdlibErrorMessage(_ error: Swift.Error) -> String {
        if let tdError = error as? TDLibKit.Error {
            return "\(tdError.message) (code \(tdError.code))"
        }
        return error.localizedDescription
    }
}
#endif
