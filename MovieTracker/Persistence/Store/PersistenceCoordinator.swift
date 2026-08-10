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

    private(set) var revision = 0

    private static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "PersistenceCoordinator",
                                    category: "Persistence")

    @ObservationIgnored private var launchRoutineClaimed = false

    init(_ context: ModelContext) {
        self.context = context
    }

    /// Returns `true` only on the first call. Safe without locking: `@MainActor`.
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
            pending?.cancel()
            pending = Task {
                try? await Task.sleep(for: debounce)
                guard !Task.isCancelled else { return }
                onSettled()
            }
        }
    }
}
