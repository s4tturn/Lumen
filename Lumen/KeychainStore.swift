import Foundation
import Security

struct KeychainStore: Sendable {

    struct Record: Sendable {
        let account: String

        let modified: Date
    }

    let service: String

    init(service: String) {
        self.service = service
    }

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

            guard let account = item[kSecAttrAccount as String] as? String else { return nil }

            let modified = item[kSecAttrModificationDate as String] as? Date ?? .distantPast
            return Record(account: account, modified: modified)
        }
    }

    func write(_ account: String) async -> Bool {
        let attributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: Data(account.utf8),

            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]

        var status = add(attributes, synchronizable: true)
        if Self.requiresLocalFallback(status) {

            status = add(attributes, synchronizable: false)
        }

        return status == errSecSuccess || status == errSecDuplicateItem
    }

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

    private static func requiresLocalFallback(_ status: OSStatus) -> Bool {
        status == errSecNotAvailable || status == errSecMissingEntitlement
    }
}
