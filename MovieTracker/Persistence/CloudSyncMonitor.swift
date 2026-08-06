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
import CloudKit
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
                SyncLog.logger.error("☁️ \(type, privacy: .public) FAILED (\(id, privacy: .public)) after \(seconds, format: .fixed(precision: 1))s: \(Self.describe(error), privacy: .public)")
            } else {
                SyncLog.logger.log("☁️ \(type, privacy: .public) finished (\(id, privacy: .public)) ok in \(seconds, format: .fixed(precision: 1))s")
            }
        }
        isSyncing = !inProgress.isEmpty
    }

    /// A readable one-line cause for a sync failure. A `CKError.partialFailure`'s
    /// own `localizedDescription` is the generic "operation couldn't be completed
    /// (error 2)" — the real reasons are per-record in `partialErrorsByItemID`, so
    /// unwrap those and summarise the distinct underlying errors (grouped by code,
    /// with one sample message) so the log names what CloudKit actually rejected.
    private static func describe(_ error: Error) -> String {
        guard let ckError = error as? CKError else { return error.localizedDescription }

        if ckError.code == .partialFailure,
           let partials = ckError.partialErrorsByItemID, !partials.isEmpty {
            let underlying = partials.values.compactMap { $0 as? CKError }
            let byCode = Dictionary(grouping: underlying, by: { $0.code })
            let summary = byCode
                .sorted { $0.value.count > $1.value.count }
                .map { "\(name(for: $0.key))×\($0.value.count)" }
                .joined(separator: ", ")
            // A record's error carries the offending field/reason in its own
            // description; surface one that isn't just a cascaded batch failure.
            let sample = underlying.first(where: { $0.code != .batchRequestFailed }) ?? underlying.first
            let detail = sample.map { " — e.g. \($0.localizedDescription)" } ?? ""
            return "partialFailure across \(partials.count) record(s): [\(summary)]\(detail)"
        }

        return "\(ckError.localizedDescription) [CKError \(ckError.code.rawValue) \(name(for: ckError.code))]"
    }

    /// A short human name for the CKError codes that show up in mirroring failures.
    private static func name(for code: CKError.Code) -> String {
        switch code {
        case .serverRecordChanged: return "serverRecordChanged"
        case .batchRequestFailed: return "batchRequestFailed"
        case .unknownItem: return "unknownItem"
        case .invalidArguments: return "invalidArguments"
        case .serverRejectedRequest: return "serverRejectedRequest"
        case .quotaExceeded: return "quotaExceeded"
        case .limitExceeded: return "limitExceeded"
        case .constraintViolation: return "constraintViolation"
        case .permissionFailure: return "permissionFailure"
        case .zoneNotFound: return "zoneNotFound"
        case .networkFailure, .networkUnavailable: return "network"
        default: return "code \(code.rawValue)"
        }
    }
}
