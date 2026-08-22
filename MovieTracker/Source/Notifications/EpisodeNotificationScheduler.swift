//
//  EpisodeNotificationScheduler.swift
//  MovieTracker
//

import Foundation
import UserNotifications
import OSLog

/// Schedules one local notification per upcoming airing, replacing the previous batch each time.
@MainActor
enum EpisodeNotificationScheduler {
    static let identifierPrefix = "episode-airing-"

    // iOS keeps only the 64 soonest pending requests per app and silently discards the rest,
    // so cap below that and report what was dropped.
    static let maxScheduled = 60

    private static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Marquee",
                                    category: "Notifications")

    struct Outcome: Sendable, Equatable {
        var scheduled = 0
        var dropped = 0
    }

    static func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    static func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            log.error("🔔 authorization failed: \(error, privacy: .public)")
            return false
        }
    }

    // Rebuilds the whole batch: airings shift as TMDB revises schedules, so incremental edits drift.
    @discardableResult
    // `settings` resolves inside the body: a `.shared` default argument would be evaluated
    // outside this actor.
    static func reschedule(_ reminders: [EpisodeReminder],
                           settings injected: NotificationSettings? = nil,
                           now: Date = Date()) async -> Outcome {
        let settings = injected ?? .shared
        let center = UNUserNotificationCenter.current()
        await clearPending(on: center)

        guard settings.isEnabled else { return Outcome() }
        guard await authorizationStatus() == .authorized else {
            log.log("🔔 reminders enabled but not authorized — nothing scheduled")
            return Outcome()
        }

        let due = reminders.compactMap { reminder -> (EpisodeReminder, Date, DateComponents)? in
            guard let (fireDate, components) = fireTime(for: reminder, settings: settings),
                  fireDate > now else { return nil }
            return (reminder, fireDate, components)
        }
        .sorted { $0.1 < $1.1 }

        var outcome = Outcome(scheduled: 0, dropped: max(0, due.count - maxScheduled))
        for (reminder, _, components) in due.prefix(maxScheduled) {
            let content = UNMutableNotificationContent()
            content.title = reminder.showName
            content.body = body(for: reminder)
            content.sound = .default
            let request = UNNotificationRequest(
                identifier: identifierPrefix + "\(reminder.showTmdbID)",
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false))
            do {
                try await center.add(request)
                outcome.scheduled += 1
            } catch {
                log.error("🔔 could not schedule \(reminder.showName, privacy: .public): \(error, privacy: .public)")
            }
        }
        log.log("🔔 scheduled \(outcome.scheduled) reminder(s), dropped \(outcome.dropped) past the cap")
        return outcome
    }

    static func cancelAll() async {
        await clearPending(on: UNUserNotificationCenter.current())
    }

    // MARK: - Helpers

    private static func clearPending(on center: UNUserNotificationCenter) async {
        let ours = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix(identifierPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: ours)
    }

    // Air dates are stored at UTC midnight, so read the day in UTC and fire at the local time on it.
    private static func fireTime(for reminder: EpisodeReminder,
                                 settings: NotificationSettings) -> (Date, DateComponents)? {
        let day = DateFormatter.utcCalendar
            .dateComponents([.year, .month, .day], from: reminder.airDate)
        var components = DateComponents()
        components.year = day.year
        components.month = day.month
        components.day = day.day
        components.hour = settings.hour
        components.minute = settings.minute
        guard let date = Calendar.current.date(from: components) else { return nil }
        return (date, components)
    }

    private static func body(for reminder: EpisodeReminder) -> String {
        "Season \(reminder.seasonNumber), Episode \(reminder.episodeNumber) airs today."
    }
}
