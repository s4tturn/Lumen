import Foundation
import Observation

@MainActor @Observable
final class CollectionStore {

    private(set) var entries: [(id: CollectionTask.ID, completedAt: Date)] = []

    private let keychain = KeychainStore(service: "s4tturn.Lumen.collectionCompletion")

    func isCompleted(_ id: CollectionTask.ID) -> Bool {
        entries.contains { $0.id == id }
    }

    func complete(_ id: CollectionTask.ID) {
        guard !isCompleted(id) else { return }
        entries.insert((id, Date()), at: 0)
        Task { [keychain] in
            guard !(await keychain.write(id.rawValue)) else { return }

            entries.removeAll { $0.id == id }
        }
    }

    func undo(_ id: CollectionTask.ID) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        let removed = entries.remove(at: index)
        Task { [keychain] in
            guard !(await keychain.remove(id.rawValue)) else { return }

            entries.insert(removed, at: min(index, entries.endIndex))
        }
    }

    func refresh() async {
        let keychain = self.keychain
        let stored = await keychain.records()

        entries = stored
            .sorted { $0.modified > $1.modified }
            .compactMap { record in
                CollectionCatalog.entry(for: CollectionTask.ID(record.account))
                    .map { (id: $0.1.id, completedAt: record.modified) }
            }
    }
}
