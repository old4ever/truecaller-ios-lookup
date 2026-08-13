import Contacts
import ContactsUI
import SwiftUI

/// The user-visible data passed to Apple's new-contact editor.
struct ContactDraft: Identifiable {
    struct LabeledPhone {
        let number: String
        let label: String
    }

    let id = UUID()
    let givenName: String
    let phones: [LabeledPhone]

    init?(entry: LookupEntry, queriedNumber: String) {
        givenName = entry.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        var seenNumbers = Set<String>()
        var mappedPhones: [LabeledPhone] = []

        for phone in entry.phones ?? [] {
            guard let number = Self.usableNumber(phone.e164Format) ?? Self.usableNumber(phone.nationalFormat) else {
                continue
            }

            let key = Self.deduplicationKey(for: number)
            guard seenNumbers.insert(key).inserted else { continue }

            mappedPhones.append(
                LabeledPhone(number: number, label: Self.contactLabel(for: phone.numberType))
            )
        }

        if mappedPhones.isEmpty, let fallback = Self.usableNumber(queriedNumber) {
            mappedPhones.append(LabeledPhone(number: fallback, label: CNLabelPhoneNumberMain))
        }

        guard !mappedPhones.isEmpty else { return nil }
        phones = mappedPhones
    }

    fileprivate var contact: CNMutableContact {
        let contact = CNMutableContact()
        contact.givenName = givenName
        contact.phoneNumbers = phones.map {
            CNLabeledValue(label: $0.label, value: CNPhoneNumber(stringValue: $0.number))
        }
        return contact
    }

    private static func usableNumber(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let digitCount = trimmed.unicodeScalars.lazy.filter(CharacterSet.decimalDigits.contains).count
        return digitCount >= 3 ? trimmed : nil
    }

    private static func deduplicationKey(for number: String) -> String {
        String(number.unicodeScalars.filter(CharacterSet.decimalDigits.contains))
    }

    private static func contactLabel(for numberType: String?) -> String {
        guard numberType?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "mobile" else {
            return CNLabelPhoneNumberMain
        }
        return CNLabelPhoneNumberMobile
    }
}

/// Presents the native new-contact flow without reading or writing the contact store directly.
struct ContactEditorView: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss

    let draft: ContactDraft

    func makeCoordinator() -> Coordinator {
        Coordinator(onComplete: dismiss.callAsFunction)
    }

    func makeUIViewController(context: Context) -> UINavigationController {
        let editor = CNContactViewController(forNewContact: draft.contact)
        editor.contactStore = CNContactStore()
        editor.delegate = context.coordinator
        return UINavigationController(rootViewController: editor)
    }

    func updateUIViewController(_ controller: UINavigationController, context: Context) {}

    final class Coordinator: NSObject, CNContactViewControllerDelegate {
        private let onComplete: () -> Void

        init(onComplete: @escaping () -> Void) {
            self.onComplete = onComplete
        }

        func contactViewController(_ viewController: CNContactViewController, didCompleteWith contact: CNContact?) {
            onComplete()
        }
    }
}
