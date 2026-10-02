//
//  DecisionStore.swift
//  SnapShred
//

import Foundation

/// Persists every verdict so progress survives relaunches.
final class DecisionStore {
    private struct Snapshot: Codable {
        var decisions: [String: SwipeDecision] = [:]
        /// Identifiers marked for deletion, in the order they were swiped.
        var bin: [String] = []
    }

    private var snapshot = Snapshot()
    private var saveTask: Task<Void, Never>?

    private let fileURL: URL = {
        let directory = URL.applicationSupportDirectory
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appending(path: "decisions.json")
    }()

    init() {
        if let data = try? Data(contentsOf: fileURL),
           let saved = try? JSONDecoder().decode(Snapshot.self, from: data) {
            snapshot = saved
        }
    }

    var binIdentifiers: [String] { snapshot.bin }

    func decision(for identifier: String) -> SwipeDecision? {
        snapshot.decisions[identifier]
    }

    func record(_ decision: SwipeDecision, for identifier: String) {
        snapshot.decisions[identifier] = decision
        snapshot.bin.removeAll { $0 == identifier }
        if decision == .shred {
            snapshot.bin.append(identifier)
        }
        scheduleSave()
    }

    func clear(_ identifier: String) {
        snapshot.decisions[identifier] = nil
        snapshot.bin.removeAll { $0 == identifier }
        scheduleSave()
    }

    /// Drops records for assets that no longer exist in the library.
    func forget(_ identifiers: some Sequence<String>) {
        let gone = Set(identifiers)
        for id in gone { snapshot.decisions[id] = nil }
        snapshot.bin.removeAll { gone.contains($0) }
        scheduleSave()
    }

    func reset() {
        snapshot = Snapshot()
        scheduleSave()
    }

    // MARK: Saving

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            save()
        }
    }

    func save() {
        saveTask?.cancel()
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        let url = fileURL
        Task.detached(priority: .utility) {
            try? data.write(to: url, options: .atomic)
        }
    }
}
