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
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
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
