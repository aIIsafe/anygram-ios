import Foundation

/// Stable mapping between Telegram numeric IDs and app UUIDs.
enum TelegramIdentity {
    static func uuid(fromTelegramId id: Int64) -> UUID {
        var bytes = [UInt8](repeating: 0, count: 16)
        let bigEndian = id.bigEndian
        withUnsafeBytes(of: bigEndian) { raw in
            for index in 0..<min(8, raw.count) {
                bytes[index] = raw[index]
            }
        }
        bytes[8] = 0xA0
        bytes[9] = 0xA1
        return uuid(from: bytes)
    }

    static func telegramId(from uuid: UUID) -> Int64? {
        let bytes = uuidBytes(uuid)
        guard bytes[8] == 0xA0, bytes[9] == 0xA1 else { return nil }
        guard bytes[10...15].allSatisfy({ $0 == 0 }) else { return nil }
        return int64BigEndian(from: Array(bytes[0..<8]))
    }

    static func messageUUID(chatId: Int64, messageId: Int64) -> UUID {
        var bytes = [UInt8](repeating: 0, count: 16)
        appendBigEndian(chatId, to: &bytes, offset: 0)
        appendBigEndian(messageId, to: &bytes, offset: 8)
        return uuid(from: bytes)
    }

    static func telegramMessageId(from uuid: UUID) -> (chatId: Int64, messageId: Int64)? {
        let bytes = uuidBytes(uuid)
        guard bytes[8] != 0xA0 || bytes[9] != 0xA1 || !bytes[10...15].allSatisfy({ $0 == 0 }) else {
            return nil
        }
        let chatId = int64BigEndian(from: Array(bytes[0..<8]))
        let messageId = int64BigEndian(from: Array(bytes[8..<16]))
        return (chatId, messageId)
    }

    private static func uuid(from bytes: [UInt8]) -> UUID {
        UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }

    private static func uuidBytes(_ uuid: UUID) -> [UInt8] {
        let tuple = uuid.uuid
        return [
            tuple.0, tuple.1, tuple.2, tuple.3,
            tuple.4, tuple.5, tuple.6, tuple.7,
            tuple.8, tuple.9, tuple.10, tuple.11,
            tuple.12, tuple.13, tuple.14, tuple.15,
        ]
    }

    private static func appendBigEndian(_ value: Int64, to bytes: inout [UInt8], offset: Int) {
        var bigEndian = value.bigEndian
        withUnsafeBytes(of: bigEndian) { raw in
            for index in 0..<8 {
                bytes[offset + index] = raw[index]
            }
        }
    }

    private static func int64BigEndian(from bytes: [UInt8]) -> Int64 {
        var value: Int64 = 0
        withUnsafeBytes(of: bytes) { raw in
            value = raw.load(as: Int64.self)
        }
        return Int64(bigEndian: value)
    }

    static func colorHex(forTelegramId id: Int64) -> String {
        let palette = MockDataGenerator.avatarColors
        let index = Int(abs(id) % Int64(palette.count))
        return palette[index]
    }
}

extension Data {
    init?(hexString: String) {
        let hex = hexString.filter(\.isHexDigit)
        guard hex.count.isMultiple(of: 2) else { return nil }
        var data = Data(capacity: hex.count / 2)
        var index = hex.startIndex
        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 2)
            guard let byte = UInt8(hex[index..<next], radix: 16) else { return nil }
            data.append(byte)
            index = next
        }
        self = data
    }
}
