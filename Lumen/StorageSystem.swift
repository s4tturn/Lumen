import Observation
import SwiftUI
import Security

// MARK: - Keychain Primitive

/// Bare keychain persistence: an Int per string key. No logic, no caching.
enum Keychain {
    private static let service = "Lumen.CompletionStore"

    static func read(_ key: String) -> Int? {
        var query = baseQuery(key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return Int(String(data: data, encoding: .utf8) ?? "")
    }

    static func write(_ key: String, _ value: Int) {
        let data = Data(String(value).utf8)
        var attributes = baseQuery(key)
        attributes[kSecValueData as String] = data
        let status = SecItemUpdate(attributes as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            SecItemAdd(attributes as CFDictionary, nil)
        }
    }

    private static func baseQuery(_ key: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
    }
}

// MARK: - Models

/// The emoji item currently centered in the expanded card.
struct FocusedItem: Equatable {
    let key: String
    let collectionColor: Color
}

/// An in-flight 5s undo window for one item.
struct PendingUndo: Equatable {
    let priorValue: Int
    let expiresAt: Date
}

// MARK: - Store

/// Single brain for completion counts: committed values live in keychain,
/// undo windows are memory-only. `focused` is set externally by the UI.
@Observable
final class CompletionStore {
    static let undoWindow: TimeInterval = 5

    private(set) var focused: FocusedItem?
    private(set) var pending: [String: PendingUndo] = [:]

    var count: Int { focused.map { Keychain.read($0.key) ?? 0 } ?? 0 }
    var activeUndo: PendingUndo? { focused.flatMap { pending[$0.key] } }

    func setFocused(_ item: FocusedItem?) {
        focused = item
    }

    /// +1 to the focused item's committed value and open its undo window.
    /// No-op while the item is already pending — prevents spam.
    func complete() {
        guard let key = focused?.key, pending[key] == nil else { return }
        let prior = Keychain.read(key) ?? 0
        Keychain.write(key, prior + 1)
        let record = PendingUndo(priorValue: prior, expiresAt: Date().addingTimeInterval(Self.undoWindow))
        pending[key] = record
        Task { await expire(key, record) }
    }

    /// Restores the pre-completion value. Only valid inside the window.
    func undo() {
        guard let key = focused?.key, let record = pending[key], record.expiresAt > Date() else { return }
        Keychain.write(key, record.priorValue)
        pending[key] = nil
    }

    /// Removes the window once it lapses. The guard ensures a stale task
    /// can never close a newer window for the same key.
    private func expire(_ key: String, _ record: PendingUndo) async {
        try? await Task.sleep(for: .seconds(Self.undoWindow))
        guard pending[key]?.expiresAt == record.expiresAt else { return }
        pending[key] = nil
    }
}
