//
//  CloudSyncMonitor.swift
//  MovieTracker
//

import Foundation
import CoreData
import CloudKit
import Observation

/// Surfaces CloudKit sync activity as a flag the UI can show during import/export.
@MainActor
@Observable
final class CloudSyncMonitor {
    private(set) var isSyncing = false

    // NSPersistentCloudKitContainer reports each event twice (begin, then finish), so track the
    // in-flight ones to know when all are done.
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
            MainActor.assumeIsolated {
                self?.update(with: event)
            }
        }
    }

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

    // A `CKError.partialFailure` describes itself as a generic "error 2"; the real reasons are
    // per-record in `partialErrorsByItemID`.
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
            // A record's own error carries the real reason, so skip cascaded batch failures.
            let sample = underlying.first(where: { $0.code != .batchRequestFailed }) ?? underlying.first
            let detail = sample.map { " — e.g. \($0.localizedDescription)" } ?? ""
            return "partialFailure across \(partials.count) record(s): [\(summary)]\(detail)"
        }

        return "\(ckError.localizedDescription) [CKError \(ckError.code.rawValue) \(name(for: ckError.code))]"
    }

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
