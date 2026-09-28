import Foundation
import Security

/// Named, iCloud-synced keychain records — small pieces of state that must
/// outlive the process and follow the person to their other devices.
///
/// Lumen files **one record per finished task**, named by the task's stable
/// identity, rather than one record holding the whole set. That is what makes
/// sync safe: two devices finishing two different tasks each rewrite only their
/// own record, so neither can clobber the other's work. A single blob would
/// last-writer-win and silently lose a completion.
///
/// Records go through iCloud Keychain, which is end-to-end encrypted and free —
/// `kSecAttrSynchronizable` needs no CloudKit container, no capability and no
/// paid account. When iCloud Keychain is unavailable the same write is retried
/// device-locally rather than dropped, and reads ask for both kinds so a
/// device that once synced can still see records a peer wrote unsynced.
///
/// Every entry point is `async` and not actor-isolated, so calling one from the
/// main actor genuinely leaves it: each call is a round trip into `securityd`,
/// and a completion happens on the touch path.
struct KeychainStore: Sendable {
    /// One record currently filed under this store.
    struct Record: Sendable {
        let account: String
        /// When the record was last written, as reported by the keychain.
        let modified: Date
    }

    /// Namespaces records within the app's keychain.
    let service: String

    init(service: String) {
        self.service = service
    }

    /// Every record filed here, synchronizable or not.
    func records() async -> [Record] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let items = result as? [[String: Any]]
        else { return [] }

        return items.compactMap { item in
            // The account is the record's whole content, so an item without one
            // is not ours to interpret.
            guard let account = item[kSecAttrAccount as String] as? String else { return nil }
            // The modification date is the completion time for free — it is
            // already there, so nothing extra is stored to keep it. A record
            // missing it sorts last rather than dropping out of the list.
            let modified = item[kSecAttrModificationDate as String] as? Date ?? .distantPast
            return Record(account: account, modified: modified)
        }
    }

    /// Files a record, or leaves the existing one alone. Returns whether the
    /// keychain now holds it.
    func write(_ account: String) async -> Bool {
        let attributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: Data(account.utf8),
            // The app only ever reads this in the foreground, so the stricter
            // class costs nothing and keeps the records out of reach while the
            // device is locked.
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]

        var status = add(attributes, synchronizable: true)
        if Self.requiresLocalFallback(status) {
            // Tried fresh every time rather than cached: a person who switches
            // iCloud Keychain on should start syncing on their next completion
            // without the app needing to know it had changed.
            status = add(attributes, synchronizable: false)
        }
        // A double-tap can race a second write of the same account. The record
        // is already there, which is all the caller wanted.
        return status == errSecSuccess || status == errSecDuplicateItem
    }

    /// Removes a record, treating an absent one as success.
    func remove(_ account: String) async -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    private func add(_ attributes: [String: Any], synchronizable: Bool) -> OSStatus {
        SecItemAdd(attributes.merging([kSecAttrSynchronizable as String: synchronizable]) { _, new in new } as CFDictionary, nil)
    }

    /// The two statuses that mean "this device cannot sync", as opposed to
    /// "this write went wrong".
    private static func requiresLocalFallback(_ status: OSStatus) -> Bool {
        status == errSecNotAvailable || status == errSecMissingEntitlement
    }
}
