import Foundation

struct Country: Identifiable, Hashable {
    let id: String
    let name: String
    let dialCode: String
    let flag: String

    static let `default` = Country(id: "RU", name: "Россия", dialCode: "+7", flag: "🇷🇺")

    static let all: [Country] = [
        .default,
        Country(id: "UA", name: "Украина", dialCode: "+380", flag: "🇺🇦"),
        Country(id: "BY", name: "Беларусь", dialCode: "+375", flag: "🇧🇾"),
        Country(id: "KZ", name: "Казахстан", dialCode: "+7", flag: "🇰🇿"),
        Country(id: "US", name: "США", dialCode: "+1", flag: "🇺🇸"),
        Country(id: "GB", name: "Великобритания", dialCode: "+44", flag: "🇬🇧"),
        Country(id: "DE", name: "Германия", dialCode: "+49", flag: "🇩🇪"),
        Country(id: "FR", name: "Франция", dialCode: "+33", flag: "🇫🇷"),
        Country(id: "TR", name: "Турция", dialCode: "+90", flag: "🇹🇷"),
        Country(id: "UZ", name: "Узбекистан", dialCode: "+998", flag: "🇺🇿"),
        Country(id: "GE", name: "Грузия", dialCode: "+995", flag: "🇬🇪"),
        Country(id: "AM", name: "Армения", dialCode: "+374", flag: "🇦🇲"),
        Country(id: "AZ", name: "Азербайджан", dialCode: "+994", flag: "🇦🇿"),
        Country(id: "IL", name: "Израиль", dialCode: "+972", flag: "🇮🇱"),
        Country(id: "CN", name: "Китай", dialCode: "+86", flag: "🇨🇳"),
        Country(id: "IN", name: "Индия", dialCode: "+91", flag: "🇮🇳")
    ]
}

enum PhoneFormatter {
    static func format(_ raw: String, country: Country) -> String {
        let digits = raw.filter(\.isNumber)
        guard country.id == "RU" || country.id == "KZ" else { return digits }
        var result = ""
        for (index, char) in digits.prefix(10).enumerated() {
            switch index {
            case 0: result.append("(\(char)")
            case 2: result.append("\(char)) ")
            case 5: result.append("\(char)-")
            case 7: result.append("\(char)-")
            default: result.append(String(char))
            }
        }
        return result
    }

    static func internationalNumber(dialCode: String, localNumber: String, country: Country? = nil) -> String {
        let codeDigits = dialCode.filter(\.isNumber)
        var localDigits = localNumber.filter(\.isNumber)

        if let country {
            if (country.id == "RU" || country.id == "KZ"), localDigits.hasPrefix("8"), localDigits.count == 11 {
                localDigits = String(localDigits.dropFirst())
            }
            if localDigits.hasPrefix(codeDigits), localDigits.count > codeDigits.count + 6 {
                localDigits = String(localDigits.dropFirst(codeDigits.count))
            }
        }

        return "+\(codeDigits)\(localDigits)"
    }
}
