//
//  PersistenceCoordinator.swift
//  MovieTracker
//

import Foundation
import Observation
import SwiftData
import CoreData
import OSLog

/// The single writer for a SwiftData store. Every mutation runs on the main actor
/// and persists immediately, so views reflect changes at once (rather than waiting
/// on autosave) and nothing is lost on a crash.
///
/// This file is deliberately app-agnostic: it knows only about `ModelContext`,
/// saving, and CloudKit remote-change observation, so it can be reused across
/// projects. App-specific domain logic lives in extensions — `+Lists` and `+Media`
/// (per-domain reads/writes) and `+Lifecycle` (launch seeding and reconciliation).
@MainActor
@Observable
final class PersistenceCoordinator {
    let context: ModelContext

    /// Increments on every persisted change — a local save or a CloudKit import.
    /// Views observe this instead of subscribing to store notifications themselves,
    /// so a mutation that doesn't alter a `@Query` (e.g. a watched-date edit) still
    /// drives a refresh.
    private(set) var revision = 0

    private static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "PersistenceCoordinator",
                                    category: "Persistence")

    /// Backs `claimLaunchRoutine()`. Not observed — it gates a one-time side effect,
    /// not UI state.
    @ObservationIgnored private var launchRoutineClaimed = false

    init(_ context: ModelContext) {
        self.context = context
    }

    /// Returns `true` exactly once — on the first call — and `false` thereafter, so
    /// a one-time launch routine stays idempotent even if the SwiftUI `.task` that
    /// drives it re-fires (e.g. a size-class change re-running the task at launch).
    /// Safe without locking: the coordinator is `@MainActor`.
    func claimLaunchRoutine() -> Bool {
        guard !launchRoutineClaimed else { return false }
        launchRoutineClaimed = true
        return true
    }

    func save() {
        guard context.hasChanges else { return }
        do {
            try context.save()
            revision &+= 1
        } catch {
            Self.log.error("💾 save failed: \(error, privacy: .public)")
        }
    }

    /// Applies a mutation and persists it. Prefer the typed helpers; use this for
    /// one-off changes that don't warrant their own method.
    func perform(_ mutation: () -> Void) {
        mutation()
        save()
    }

    func insert(_ model: any PersistentModel) { context.insert(model); save() }
    func delete(_ model: any PersistentModel) { context.delete(model); save() }

    // MARK: - Remote-change observation (CloudKit)

    /// Observes CloudKit remote-store changes for the lifetime of the caller's Task:
    /// bumps `revision` on every notification so observers refresh, and invokes
    /// `onSettled` once — after a burst of imported records settles (debounced).
    /// Never returns; call it from a long-lived Task.
    func observeRemoteChanges(debounce: Duration = .seconds(2),
                              onSettled: @MainActor @escaping () -> Void) async {
        var pending: Task<Void, Never>?
        for await _ in NotificationCenter.default.notifications(named: .NSPersistentStoreRemoteChange) {
            revision &+= 1   // a CloudKit import landed — nudge observers to refresh
            pending?.cancel()
            pending = Task {
                try? await Task.sleep(for: debounce)
                guard !Task.isCancelled else { return }
                onSettled()
            }
        }
    }
}
