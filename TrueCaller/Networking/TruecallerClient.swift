import Foundation

/// Mirrors the request/response contract of `tc.py`:
///   GET https://search5-noneu.truecaller.com/v2/search?q=<n>&countryCode=<cc>&type=4&encoding=json
///   Authorization: Bearer <installationId>
/// 429 responses carry a throttle payload (strategy / timeoutSeconds / searchTypes).
struct TruecallerClient {
    private static let host = "search5-noneu.truecaller.com"
    private static let userAgent = "Truecaller/26.30.5 (Android;15)"

    let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    var isConfigured: Bool {
        true
    }

    func lookup(token: String, number: String, countryCode: String) async throws -> LookupResponse {
        var components = URLComponents()
        components.scheme = "https"
        components.host = Self.host
        components.path = "/v2/search"
        components.queryItems = [
            URLQueryItem(name: "q", value: number),
            URLQueryItem(name: "countryCode", value: countryCode),
            URLQueryItem(name: "type", value: "4"),
            URLQueryItem(name: "encoding", value: "json"),
        ]
        guard let url = components.url else {
            throw TruecallerError(kind: .invalidURL)
        }

        var request = URLRequest(url: url)
        request.setValue(Self.userAgent, forHTTPHeaderField: "user-agent")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "authorization")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw TruecallerError(kind: .transport(error))
        }

        guard let http = response as? HTTPURLResponse else {
            throw TruecallerError(kind: .badStatus(-1))
        }

        if http.statusCode == 429 {
            throw TruecallerError(kind: .rateLimited(parseThrottle(data: data, response: http)))
        }

        guard (200..<300).contains(http.statusCode) else {
            throw TruecallerError(kind: .badStatus(http.statusCode))
        }

        do {
            return try JSONDecoder().decode(LookupResponse.self, from: data)
        } catch {
            throw TruecallerError(kind: .decoding(error))
        }
    }

    /// Truecaller rejects numbers with no leading `+`; normalize local-form to E.164
    /// using a caller-supplied default country.
    private func parseThrottle(data: Data, response: HTTPURLResponse) -> ThrottleInfo {
        let retryAfter = response.value(forHTTPHeaderField: "Retry-After").flatMap(Int.init)
        guard
            let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return ThrottleInfo(retryAfter: retryAfter, timeoutSeconds: nil, strategy: nil, searchTypes: nil)
        }
        let timeoutSeconds = obj["timeoutSeconds"] as? Double
            ?? (obj["timeoutSeconds"] as? Int).map(Double.init)
        return ThrottleInfo(
            retryAfter: retryAfter,
            timeoutSeconds: timeoutSeconds,
            strategy: obj["strategy"] as? String,
            searchTypes: obj["searchTypes"] as? [String]
        )
    }
}

struct ThrottleInfo: Equatable {
    let retryAfter: Int?
    let timeoutSeconds: Double?
    let strategy: String?
    let searchTypes: [String]?
}

struct TruecallerError: LocalizedError {
    enum Kind {
        case noToken
        case invalidURL
        case rateLimited(ThrottleInfo)
        case transport(Error)
        case badStatus(Int)
        case decoding(Error)
    }

    let kind: Kind

    var errorDescription: String? {
        switch kind {
        case .noToken:
            return "No token configured. Add your Truecaller installationId in Settings."
        case .invalidURL:
            return "Could not build a valid request URL."
        case .rateLimited(let info):
            return rateLimitMessage(info)
        case .transport(let error):
            return "Network error: \(error.localizedDescription)"
        case .badStatus(let code):
            return "Server returned HTTP \(code)."
        case .decoding(let error):
            return "Could not parse response: \(error.localizedDescription)"
        }
    }

    private func rateLimitMessage(_ info: ThrottleInfo) -> String {
        var parts = ["Rate limited (429)"]
        if let t = info.timeoutSeconds {
            let total = Int(t)
            parts.append("wait \(total / 3600)h \(total % 3600 / 60)m")
        }
        if let s = info.retryAfter {
            parts.append("Retry-After \(s)s")
        }
        if let strategy = info.strategy, strategy == "manual" {
            parts.append("MANUAL throttle — stop; each request extends the block")
        }
        return parts.joined(separator: " · ")
    }
}
