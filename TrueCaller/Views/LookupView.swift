import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            LookupView()
                .tabItem { Label("Lookup", systemImage: "magnifyingglass") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
    }
}

struct LookupView: View {
    @EnvironmentObject private var settings: SettingsStore
    @StateObject private var model = LookupViewModel()
    @State private var input = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if settings.token.isEmpty {
                        banner(
                            message: "No token yet — add your Truecaller installationId in Settings before looking up numbers.",
                            icon: "key.fill"
                        )
                    }

                    inputCard

                    if !model.records.isEmpty {
                        resultsCard
                    }
                }
                .padding()
            }
            .navigationTitle("Truecaller Lookup")
        }
    }

    private var inputCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Numbers to look up")
                .font(.subheadline.weight(.semibold))

            TextEditor(text: $input)
                .frame(minHeight: 120)
                .padding(8)
                .scrollContentBackground(.hidden)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(alignment: .topLeading) {
                    if input.isEmpty {
                        Text("Paste numbers — one per line, or separated by commas/spaces\n\nExample:\n+14370000000\n6502530000")
                            .foregroundStyle(.secondary)
                            .padding(.top, 17)
                            .padding(.leading, 12)
                            .allowsHitTesting(false)
                    }
                }

            HStack {
                Text("Default country: \(settings.country.flag) \(settings.country.name)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            Button {
                Task { await model.run(query: input, defaultCountry: settings.country) }
            } label: {
                if model.status == .loading {
                    ProgressView().frame(maxWidth: .infinity, minHeight: 18)
                } else {
                    Label("Look Up", systemImage: "magnifyingglass")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(settings.token.isEmpty || input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.status == .loading)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var resultsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Results")
                .font(.subheadline.weight(.semibold))

            ForEach(model.records) { record in
                VStack(alignment: .leading, spacing: 8) {
                    Text(record.number)
                        .font(.callout.weight(.semibold))
                        .textSelection(.enabled)

                    if let error = record.error {
                        Label {
                            Text(error)
                                .font(.footnote)
                                .foregroundStyle(.orange)
                        } icon: {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                        }
                    } else if record.isEmpty {
                        Text("No result found for this number.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(record.entries) { entry in
                            EntryRow(entry: entry)
                        }
                    }
                }
                .padding(12)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                Divider()
            }
        }
    }

    private func banner(message: String, icon: String) -> some View {
        Label {
            Text(message)
                .font(.footnote)
        } icon: {
            Image(systemName: icon)
                .foregroundStyle(.orange)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct EntryRow: View {
    let entry: LookupEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .center, spacing: 6) {
                Text(entry.displayName)
                    .font(.subheadline.weight(.semibold))
                    .textSelection(.enabled)
                if entry.spamInfo?.isSpam == true {
                    Text("SPAM")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.red)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
                Spacer()
                if let score = entry.score {
                    Text(String(format: "%.0f%%", score * 100))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            if let phone = entry.primaryPhone {
                Text(phone.e164Format ?? phone.nationalFormat ?? "")
                    .font(.footnote.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                if let detail = phoneDetail(phone) {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            if let spam = entry.spamInfo, spam.isSpam {
                Text(spamSummary(spam))
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            if let email = entry.internetAddresses?.first(where: { $0.service == "email" || $0.id?.contains("@") == true }), let id = email.id {
                Text(id)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
    }

    private func spamSummary(_ spam: SpamInfo) -> String {
        var text = "Flagged \(spam.spamType ?? "spam")"
        if let n = spam.numReports {
            text += " · \(n) report\(n == 1 ? "" : "s")"
        }
        return text
    }

    private func phoneDetail(_ phone: Phone) -> String? {
        var parts: [String] = []
        if let carrier = phone.carrier, !carrier.isEmpty { parts.append(carrier) }
        if let type = phone.numberType, !type.isEmpty { parts.append(type.capitalized) }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}
