//
//  NotificationSettings.swift
//  MovieTracker
//

import Foundation

/// Episode-reminder preferences. Device-local, because permission is granted per device.
@MainActor
@Observable
final class NotificationSettings {
    static let shared = NotificationSettings()

    private enum Key {
        static let enabled = "episodeRemindersEnabled"
        static let hour = "episodeReminderHour"
        static let minute = "episodeReminderMinute"
    }

    private let defaults: UserDefaults

    private(set) var isEnabled: Bool
    private(set) var hour: Int
    private(set) var minute: Int

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        isEnabled = defaults.bool(forKey: Key.enabled)
        // A missing key reads as 0, which would fire reminders at midnight.
        hour = defaults.object(forKey: Key.hour) as? Int ?? 20
        minute = defaults.object(forKey: Key.minute) as? Int ?? 0
    }

    // A throwaway suite: a preview must not rewrite the real preferences.
    static func preview(isEnabled: Bool) -> NotificationSettings {
        let settings = NotificationSettings(
            defaults: UserDefaults(suiteName: "preview.notifications") ?? .standard)
        settings.isEnabled = isEnabled
        return settings
    }

    var deliveryTime: DateComponents {
        DateComponents(hour: hour, minute: minute)
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        defaults.set(enabled, forKey: Key.enabled)
    }

    func setDeliveryTime(hour: Int, minute: Int) {
        self.hour = hour
        self.minute = minute
        defaults.set(hour, forKey: Key.hour)
        defaults.set(minute, forKey: Key.minute)
    }
}
