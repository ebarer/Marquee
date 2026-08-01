//
//  CloudSyncMonitor.swift
//  MovieTracker
//
//  Surfaces CloudKit sync activity from the SwiftData store as a simple flag the
//  UI can show while an import or export is in flight. Backed by the event
//  notifications NSPersistentCloudKitContainer posts as it mirrors the store.
//

import Foundation
import CoreData
import Observation

@MainActor
@Observable
final class CloudSyncMonitor {
    /// True while at least one CloudKit setup/import/export event is running.
    private(set) var isSyncing = false

    /// Identifiers of events that have started but not yet reported an end. An
    /// event is reported twice — once when it begins (no end date) and once when
    /// it finishes — so we track the in-flight ones to know when all are done.
    @ObservationIgnored private var inProgress: Set<UUID> = []

    @ObservationIgnored nonisolated(unsafe) private var observer: (any NSObjectProtocol)?

    init() {
        observer = NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                as? NSPersistentCloudKitContainer.Event else { return }
            // The notification is delivered on the main queue (queue: .main).
            MainActor.assumeIsolated {
                self?.update(with: event)
            }
        }
    }

    /// A monitor fixed in a given state with no live observation, for previews.
    init(isSyncing: Bool) {
        self.isSyncing = isSyncing
    }

    deinit {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    private func update(with event: NSPersistentCloudKitContainer.Event) {
        let type: String
        switch event.type {
        case .setup: type = "setup"
        case .import: type = "import"
        case .export: type = "export"
        @unknown default: type = "event"
        }
        let id = String(event.identifier.uuidString.prefix(8))

        if event.endDate == nil {
            inProgress.insert(event.identifier)
            SyncLog.logger.log("☁️ \(type, privacy: .public) started (\(id, privacy: .public))")
        } else {
            inProgress.remove(event.identifier)
            let seconds = event.endDate!.timeIntervalSince(event.startDate)
            if let error = event.error {
                SyncLog.logger.error("☁️ \(type, privacy: .public) FAILED (\(id, privacy: .public)) after \(seconds, format: .fixed(precision: 1))s: \(error.localizedDescription, privacy: .public)")
            } else {
                SyncLog.logger.log("☁️ \(type, privacy: .public) finished (\(id, privacy: .public)) ok in \(seconds, format: .fixed(precision: 1))s")
            }
        }
        isSyncing = !inProgress.isEmpty
    }
}
