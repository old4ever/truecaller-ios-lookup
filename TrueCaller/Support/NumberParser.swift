import Foundation

/// A caller-selected default country: used to (a) fill in E.164 for numbers the
/// user types without a country prefix and (b) hint Truecaller's countryCode.
struct Country: Identifiable, Hashable {
    let id: String          // ISO-2, e.g. "US"
    let name: String
    let flag: String
    let dialingCode: String // with leading "+", e.g. "+1"

    static let all: [Country] = [
        Country(id: "US", name: "United States", flag: "🇺🇸", dialingCode: "+1"),
        Country(id: "CA", name: "Canada", flag: "🇨🇦", dialingCode: "+1"),
        Country(id: "GB", name: "United Kingdom", flag: "🇬🇧", dialingCode: "+44"),
        Country(id: "DE", name: "Germany", flag: "🇩🇪", dialingCode: "+49"),
        Country(id: "FR", name: "France", flag: "🇫🇷", dialingCode: "+33"),
        Country(id: "ES", name: "Spain", flag: "🇪🇸", dialingCode: "+34"),
        Country(id: "IT", name: "Italy", flag: "🇮🇹", dialingCode: "+39"),
        Country(id: "NL", name: "Netherlands", flag: "🇳🇱", dialingCode: "+31"),
        Country(id: "SE", name: "Sweden", flag: "🇸🇪", dialingCode: "+46"),
        Country(id: "IN", name: "India", flag: "🇮🇳", dialingCode: "+91"),
        Country(id: "AU", name: "Australia", flag: "🇦🇺", dialingCode: "+61"),
        Country(id: "MX", name: "Mexico", flag: "🇲🇽", dialingCode: "+52"),
        Country(id: "BR", name: "Brazil", flag: "🇧🇷", dialingCode: "+55"),
        Country(id: "UA", name: "Ukraine", flag: "🇺🇦", dialingCode: "+380"),
        Country(id: "PL", name: "Poland", flag: "🇵🇱", dialingCode: "+48"),
    ]

    static let `default` = all[0]
}

/// Turns free-form user input into one or more E.164 query numbers plus a
/// countryCode hint, mirroring how `tc.py` decides the country.
enum NumberParser {
    /// Splits pasted text (newlines / commas / spaces) into raw tokens.
    static func tokens(from text: String) -> [String] {
        text
            .components(separatedBy: CharacterSet(charactersIn: "\n,;"))
            .flatMap { $0.components(separatedBy: .whitespacesAndNewlines) }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    struct ParsedNumber: Equatable {
        let query: String      // full E.164 sent as `q`
        let countryCode: String // ISO-2 hint sent as `countryCode`
        let original: String
    }

    /// Normalize a single token to (query, countryCode). Returns nil if it has
    /// no digits at all.
    static func parse(_ raw: String, defaultCountry: Country) -> ParsedNumber? {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        let digitsOnly = trimmed.filter { $0.isNumber }

        guard !digitsOnly.isEmpty else { return nil }

        if trimmed.hasPrefix("+") {
            // Already international. Use the full number.
            let cc = countryCode(for: digitsOnly)
            return ParsedNumber(query: "+" + digitsOnly, countryCode: cc, original: raw)
        }

        // National format: prepend the default country's dialing code.
        let dialing = defaultCountry.dialingCode.replacingOccurrences(of: "+", with: "")
        let full = dialing + digitsOnly
        return ParsedNumber(query: "+" + full, countryCode: defaultCountry.id, original: raw)
    }

    /// Best-effort detection of the leading country code for an E.164 digit
    /// string (no `+`). Tries longest dialing codes first; falls back to "" so
    /// Truecaller can infer it.
    private static func countryCode(for e164Digits: String) -> String {
        let codes = Country.all
            .sorted { $0.dialingCode.count > $1.dialingCode.count }
        for country in codes {
            let dialing = country.dialingCode.replacingOccurrences(of: "+", with: "")
            if e164Digits.hasPrefix(dialing) {
                return country.id
            }
        }
        return ""
    }
}
