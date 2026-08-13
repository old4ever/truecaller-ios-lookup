import Foundation

/// Top-level response from the Truecaller `/v2/search` endpoint.
struct LookupResponse: Decodable {
    let data: [LookupEntry]
}

/// One candidate hit for a looked-up number.
struct LookupEntry: Decodable, Identifiable, Hashable {
    let id: String
    let name: String?
    let score: Double?
    let phones: [Phone]?
    let addresses: [Address]?
    let internetAddresses: [InternetAddress]?
    let spamInfo: SpamInfo?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        name = try c.decodeIfPresent(String.self, forKey: .name)
        score = try c.decodeIfPresent(Double.self, forKey: .score)
        phones = try c.decodeIfPresent([Phone].self, forKey: .phones)
        addresses = try c.decodeIfPresent([Address].self, forKey: .addresses)
        internetAddresses = try c.decodeIfPresent([InternetAddress].self, forKey: .internetAddresses)
        spamInfo = try c.decodeIfPresent(SpamInfo.self, forKey: .spamInfo)
    }

    enum CodingKeys: String, CodingKey {
        case id, name, score, phones, addresses, spamInfo
        case internetAddresses
    }

    var displayName: String {
        guard let name, !name.trimmingCharacters(in: .whitespaces).isEmpty else { return "(no name)" }
        return name
    }

    /// The most useful phone, preferring one with carrier / type detail.
    var primaryPhone: Phone? {
        phones?.first { $0.hasDetail } ?? phones?.first
    }
}

struct Phone: Decodable, Hashable {
    let e164Format: String?
    let nationalFormat: String?
    let numberType: String?
    let carrier: String?
    let countryCode: String?

    var hasDetail: Bool {
        !(carrier?.isEmpty ?? true) || !(numberType?.isEmpty ?? true)
    }
}

struct Address: Decodable, Hashable {
    let city: String?
    let area: String?
    let countryCode: String?
}

struct InternetAddress: Decodable, Hashable {
    let id: String?
    let service: String?
    let caption: String?
}

struct SpamInfo: Decodable, Hashable {
    let spamScore: Int?
    let spamType: String?
    let numReports: Int?

    var isSpam: Bool { (spamScore ?? 0) > 0 || (spamType?.isEmpty == false) }
}
