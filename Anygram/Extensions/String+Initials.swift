import Foundation

extension String {
    /// Returns up to two initials from a display name.
    var initials: String {
        let components = split(separator: " ").prefix(2)
        let letters = components.compactMap { $0.first.map(String.init) }
        return letters.joined().uppercased()
    }

    /// Returns the first letter for alphabetical section headers.
    var sectionLetter: String {
        guard let first = uppercased().first, first.isLetter else { return "#" }
        return String(first)
    }
}
