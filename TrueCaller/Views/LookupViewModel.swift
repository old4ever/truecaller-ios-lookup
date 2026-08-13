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

    init() {
#if DEBUG
        guard ProcessInfo.processInfo.arguments.contains("--ui-testing-contact-export-fixture") else { return }

        let fixture = """
        {
          "data": [
            {
              "id": "fixture-api-phones",
              "name": "Ada Fixture",
              "phones": [
                {
                  "e164Format": "+1 416 555 0123",
                  "nationalFormat": "(416) 555-0123",
                  "numberType": "MOBILE"
                },
                {
                  "e164Format": "+14165550123",
                  "nationalFormat": "416-555-0123",
                  "numberType": "mobile"
                }
              ]
            },
            {
              "id": "fixture-query-fallback",
              "name": "Fallback Fixture",
              "phones": [
                {
                  "e164Format": "—",
                  "nationalFormat": "unknown"
                }
              ]
            }
          ]
        }
        """

        guard let data = fixture.data(using: .utf8),
              let response = try? JSONDecoder().decode(LookupResponse.self, from: data) else {
            assertionFailure("Invalid contact-export UI test fixture")
            return
        }

        records = [Record(number: "+44 20 7946 0123", entries: response.data, error: nil)]
        status = .done
#endif
    }

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
