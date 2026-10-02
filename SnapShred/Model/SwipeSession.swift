//
//  SwipeSession.swift
//  SnapShred
//

import Photos
import SwiftUI

/// Drives the card deck: which photos are up next, what's in the shred bin, and undo.
@Observable
final class SwipeSession {
    private struct HistoryEntry {
        let asset: PHAsset
        let direction: SwipeDirection
        let wasFavorite: Bool
    }

    var filter: LibraryFilter = .photos {
        didSet { if filter != oldValue { reload() } }
    }

    var sortOrder: SortOrder = .newestFirst {
        didSet { if sortOrder != oldValue { reload() } }
    }

    /// Upcoming cards; the first element is the one on top.
    private(set) var deck: [PHAsset] = []
    /// Photos marked for deletion, in swipe order.
    private(set) var bin: [PHAsset] = []
    private(set) var remaining = 0
    private(set) var totalInFilter = 0
    private(set) var isLoaded = false

    private(set) var sessionKept = 0
    private(set) var sessionShredded = 0

    private(set) var lifetimeShredded = UserDefaults.standard.integer(forKey: "lifetimeShredded") {
        didSet { UserDefaults.standard.set(lifetimeShredded, forKey: "lifetimeShredded") }
    }
    private(set) var lifetimeBytesFreed = UserDefaults.standard.integer(forKey: "lifetimeBytesFreed") {
        didSet { UserDefaults.standard.set(lifetimeBytesFreed, forKey: "lifetimeBytesFreed") }
    }

    private var history: [HistoryEntry] = []
    private var fetchResult: PHFetchResult<PHAsset>?
    private var cursor = 0
    private let store = DecisionStore()
    private let photos = PhotoService.shared

    private static let deckBufferSize = 6
    static let cacheSize = CGSize(width: 1200, height: 1600)

    var canUndo: Bool { !history.isEmpty }
    var reviewedInFilter: Int { totalInFilter - remaining }

    // MARK: Loading

    func reload() {
        let result = filter.fetchAssets(order: sortOrder)
        fetchResult = result
        cursor = 0
        deck = []
        history = []

        var undecided = 0
        result.enumerateObjects { [store] asset, _, _ in
            if store.decision(for: asset.localIdentifier) == nil { undecided += 1 }
        }
        totalInFilter = result.count
        remaining = undecided

        loadBin()
        refillDeck()
        isLoaded = true
    }

    private func loadBin() {
        let ids = store.binIdentifiers
        let fetched = PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil)
        var byID: [String: PHAsset] = [:]
        fetched.enumerateObjects { asset, _, _ in byID[asset.localIdentifier] = asset }

        // Assets deleted outside the app shouldn't linger in the bin.
        let missing = ids.filter { byID[$0] == nil }
        if !missing.isEmpty { store.forget(missing) }

        bin = ids.compactMap { byID[$0] }
    }

    private func refillDeck() {
        guard let fetchResult else { return }
        while deck.count < Self.deckBufferSize, cursor < fetchResult.count {
            let asset = fetchResult.object(at: cursor)
            cursor += 1
            let id = asset.localIdentifier
            if store.decision(for: id) == nil, !deck.contains(where: { $0.localIdentifier == id }) {
                deck.append(asset)
            }
        }
        photos.startCaching(Array(deck.prefix(4)), targetSize: Self.cacheSize)
    }

    // MARK: Swiping

    func swipe(_ direction: SwipeDirection) {
        guard !deck.isEmpty else { return }
        let asset = deck.removeFirst()
        let id = asset.localIdentifier

        store.record(direction.decision, for: id)
        history.append(HistoryEntry(asset: asset, direction: direction, wasFavorite: asset.isFavorite))
        remaining = max(0, remaining - 1)

        switch direction {
        case .left:
            bin.append(asset)
            sessionShredded += 1
        case .right:
            sessionKept += 1
        case .up:
            sessionKept += 1
            if !asset.isFavorite {
                Task { try? await photos.setFavorite(true, identifier: id) }
            }
        }
        refillDeck()
    }

    /// Puts the last swiped card back on top and returns the direction it left in.
    @discardableResult
    func undo() -> SwipeDirection? {
        guard let entry = history.popLast() else { return nil }
        let id = entry.asset.localIdentifier

        store.clear(id)
        remaining += 1

        switch entry.direction {
        case .left:
            bin.removeAll { $0.localIdentifier == id }
            sessionShredded = max(0, sessionShredded - 1)
        case .right:
            sessionKept = max(0, sessionKept - 1)
        case .up:
            sessionKept = max(0, sessionKept - 1)
            if !entry.wasFavorite {
                Task { try? await photos.setFavorite(false, identifier: id) }
            }
        }
        deck.insert(entry.asset, at: 0)
        return entry.direction
    }

    // MARK: Bin

    func restore(_ asset: PHAsset) {
        let id = asset.localIdentifier
        store.record(.keep, for: id)
        bin.removeAll { $0.localIdentifier == id }
        history.removeAll { $0.asset.localIdentifier == id }
        sessionShredded = max(0, sessionShredded - 1)
        sessionKept += 1
    }

    func restoreAll() {
        for asset in bin { restore(asset) }
    }

    func estimatedBinSize() async -> Int64 {
        await photos.estimatedSize(ofIdentifiers: bin.map(\.localIdentifier))
    }

    /// Deletes everything in the bin. Returns `nil` if the user cancelled the system prompt.
    func shredBin(estimatedBytes: Int64) async throws -> Int? {
        let ids = bin.map(\.localIdentifier)
        guard !ids.isEmpty else { return 0 }
        do {
            try await photos.deleteAssets(withIdentifiers: ids)
        } catch where PhotoService.isUserCancellation(error) {
            return nil
        }

        store.forget(ids)
        let deleted = Set(ids)
        bin = []
        history.removeAll { deleted.contains($0.asset.localIdentifier) }
        lifetimeShredded += ids.count
        lifetimeBytesFreed += Int(estimatedBytes)
        return ids.count
    }

    // MARK: Housekeeping

    func resetProgress() {
        store.reset()
        sessionKept = 0
        sessionShredded = 0
        reload()
    }

    func persist() {
        store.save()
    }
}
