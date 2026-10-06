import Foundation
import Observation

/// Which collection tasks have been finished, newest first, and the only way
/// anything in the app changes that answer.
///
/// The visible list is the single source of truth: membership, ordering and
/// count all read it, so they cannot disagree. It is small by construction —
/// one entry per task, and each task can be finished once.
///
/// The keychain is the durable copy, and the order of the two matters. A tap
/// updates the list first and writes afterwards, so the interface answers on
/// the same frame; if the write then fails the list is put back exactly as it
/// was, because a task shown as finished that does not survive a relaunch is
/// worse than one that never appeared. Reads happen at launch and whenever the
/// app comes forward, so a completion made on another device shows up without a
/// relaunch — iCloud Keychain offers no change notification to subscribe to.
@MainActor @Observable
final class CollectionStore {
    /// Finished tasks, newest first. Read for listing; written only here.
    private(set) var entries: [(id: CollectionTask.ID, completedAt: Date)] = []

    private let keychain = KeychainStore(service: "s4tturn.Lumen.collectionCompletion")

    /// Whether this task has been finished.
    ///
    /// A linear scan, deliberately: the list is capped at the size of the
    /// catalog, and callers ask about one task at a time rather than testing the
    /// whole set per body evaluation. An index would be a second source of truth
    /// to keep in step with the first for no measurable gain.
    func isCompleted(_ id: CollectionTask.ID) -> Bool {
        entries.contains { $0.id == id }
    }

    /// Files a completion, unless this task is already finished.
    func complete(_ id: CollectionTask.ID) {
        guard !isCompleted(id) else { return }
        entries.insert((id, Date()), at: 0)
        Task { [keychain] in
            guard !(await keychain.write(id.rawValue)) else { return }
            // Undo is by identity, so this cannot remove a completion the person
            // made in the meantime. Rolled back in place rather than by calling
            // `undo`, which would try the keychain again and, against a
            // permanently broken store, trade one write for an endless ping-pong
            // between them.
            entries.removeAll { $0.id == id }
        }
    }

    /// Withdraws a completion, so the task can be finished again.
    func undo(_ id: CollectionTask.ID) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        let removed = entries.remove(at: index)
        Task { [keychain] in
            guard !(await keychain.remove(id.rawValue)) else { return }
            // The keychain still holds it, so the next launch would honour a
            // withdrawal that never happened. Put the entry back where it was,
            // timestamp included.
            entries.insert(removed, at: min(index, entries.endIndex))
        }
    }

    /// Adopts whatever the keychain currently holds, replacing the list.
    func refresh() async {
        let keychain = self.keychain
        let stored = await keychain.records()
        // The keychain's own timestamps order the list, so a completion is
        // filed newest-first without storing a date anywhere. Identities this
        // build does not recognise do not resolve: they stay in the keychain
        // and reappear if that content ever returns, but they cannot break the
        // list on screen.
        entries = stored
            .sorted { $0.modified > $1.modified }
            .compactMap { record in
                CollectionCatalog.entry(for: CollectionTask.ID(record.account))
                    .map { (id: $0.1.id, completedAt: record.modified) }
            }
    }
}
