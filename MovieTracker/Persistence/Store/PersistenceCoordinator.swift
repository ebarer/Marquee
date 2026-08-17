//
//  PersistenceCoordinator.swift
//  MovieTracker
//

import Foundation
import Observation
import SwiftData
import CoreData
import OSLog

/// The single writer for a SwiftData store; mutations persist immediately.
@MainActor
@Observable
final class PersistenceCoordinator {
    let context: ModelContext

    /// Held separately from `context` so `readingOffMain` never reaches through the
    /// main-actor-isolated, non-Sendable `ModelContext` to get at it.
    @ObservationIgnored nonisolated let container: ModelContainer

    private(set) var revision = 0

    private static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "PersistenceCoordinator",
                                    category: "Persistence")

    @ObservationIgnored private var launchRoutineClaimed = false

    /// Run a Lists read on a background thread. The coordinator and its `ModelContext` are built
    /// and finished inside the detached task, so nothing crosses back but the Sendable result.
    nonisolated func readingOffMain<T: Sendable>(_ read: @Sendable @escaping (ListCoordinator) -> T) async -> T {
        let container = self.container
        return await Task.detached { read(ListCoordinator(container: container)) }.value
    }

    /// Diagnostic for FrameBudgetTests, over the same hop the real reads take.
    func listReadRunsOnMainThread() async -> Bool {
        await readingOffMain { $0.runsOnMainThread() }
    }

    init(_ context: ModelContext) {
        self.context = context
        self.container = context.container
    }

    /// Returns `true` only on the first call. Safe without locking: `@MainActor`.
    func claimLaunchRoutine() -> Bool {
        guard !launchRoutineClaimed else { return false }
        launchRoutineClaimed = true
        return true
    }

    // MARK: - Deferred writes

    /// Persist once the tap that asked for it has committed. A write, and the `revision` tick it
    /// raises, would otherwise run inside the gesture and cost its animation the opening frames.
    func afterCommit(_ mutation: @MainActor @escaping () -> Void) {
        Task { @MainActor in mutation() }
    }

    // MARK: - Memoised reads

    enum CountKind: Hashable { case watched, viewed, entries(UUID) }

    @ObservationIgnored private var counts: [CountKind: Int] = [:]
    @ObservationIgnored private var countsRevision = -1
    private(set) var badgeIndex = MediaBadgeIndex()
    @ObservationIgnored private var badgesPrimed = false
    @ObservationIgnored private var badgeRefresh: Task<Void, Never>?

    /// Badge state for every tracked title. Built once on the first read, then refreshed off the
    /// main actor after each save — a badge costs a set lookup and never a fetch.
    var badges: MediaBadgeIndex {
        if !badgesPrimed {
            badgesPrimed = true
            badgeIndex = MediaBadgeIndex(context: context)
        }
        return badgeIndex
    }

    /// Lands a frame or two after the write, so it can't share a frame with the animation.
    private func refreshBadges() {
        guard badgesPrimed else { return }
        badgeRefresh?.cancel()
        badgeRefresh = Task { @MainActor in
            let rebuilt = await readingOffMain { $0.badgeIndex() }
            guard !Task.isCancelled else { return }
            badgeIndex = rebuilt
        }
    }

    /// A count held until `revision` moves. Reading `revision` here is what makes callers
    /// re-render when it does, so the memo can't hand back a stale number.
    func cachedCount(_ kind: CountKind, compute: () -> Int) -> Int {
        let current = revision
        if countsRevision != current {
            counts.removeAll(keepingCapacity: true)
            countsRevision = current
        }
        if let cached = counts[kind] { return cached }
        let value = compute()
        counts[kind] = value
        return value
    }

    func save() {
        guard context.hasChanges else { return }
        do {
            try context.save()
            revision &+= 1
            refreshBadges()
        } catch {
            Self.log.error("💾 save failed: \(error, privacy: .public)")
        }
    }

    func perform(_ mutation: () -> Void) {
        mutation()
        save()
    }

    func insert(_ model: any PersistentModel) { context.insert(model); save() }
    func delete(_ model: any PersistentModel) { context.delete(model); save() }

    // MARK: - Remote-change observation (CloudKit)

    func observeRemoteChanges(debounce: Duration = .seconds(2),
                              onSettled: @MainActor @escaping () -> Void) async {
        var pending: Task<Void, Never>?
        for await _ in NotificationCenter.default.notifications(named: .NSPersistentStoreRemoteChange) {
            revision &+= 1
            refreshBadges()
            pending?.cancel()
            pending = Task {
                try? await Task.sleep(for: debounce)
                guard !Task.isCancelled else { return }
                onSettled()
            }
        }
    }
}
