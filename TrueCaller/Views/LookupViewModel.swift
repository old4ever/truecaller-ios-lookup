import Foundation
import SwiftUI

@MainActor
final class LookupViewModel: ObservableObject {
    enum Status: Equatable {
        case idle
        case loading
        case done
    }

    struct Record: Identifiable {
        let id = UUID()
        let number: String
        let entries: [LookupEntry]
        let error: String?
        var isEmpty: Bool { entries.isEmpty && error == nil }
    }

    @Published var status: Status = .idle
    @Published var records: [Record] = []

    private let client = TruecallerClient()

    /// Runs sequentially (like `tc.py`) to stay gentle on the rate limiter.
    func run(query: String, defaultCountry: Country) async {
        let token = TokenStore.load() ?? ""
        guard !token.isEmpty else {
            records = [Record(number: "", entries: [], error: "No token configured. Open Settings and paste your Truecaller installationId.")]
            status = .done
            return
        }

        let parsed = NumberParser
            .tokens(from: query)
            .compactMap { NumberParser.parse($0, defaultCountry: defaultCountry) }

        guard !parsed.isEmpty else {
            records = [Record(number: "", entries: [], error: "No phone numbers found in that input.")]
            status = .done
            return
        }

        status = .loading
        records = []

        for item in parsed {
            do {
                let response = try await client.lookup(token: token, number: item.query, countryCode: item.countryCode)
                records.append(Record(number: item.original, entries: response.data, error: nil))
            } catch {
                let message = (error as? TruecallerError)?.errorDescription ?? error.localizedDescription
                records.append(Record(number: item.original, entries: [], error: message))
            }
        }

        status = .done
    }
}
