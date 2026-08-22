//
//  NotificationSettingsView.swift
//  MovieTracker
//

import SwiftUI
import UserNotifications

/// Turns episode-airing reminders on and picks when they fire.
struct NotificationSettingsView: View {
    @Environment(PersistenceCoordinator.self) private var store: PersistenceCoordinator?

    private let settings: NotificationSettings
    private let previewReminders: [EpisodeReminder]?

    @State private var status: UNAuthorizationStatus = .notDetermined
    @State private var upcoming: [EpisodeReminder] = []
    @State private var scheduled = 0
    @State private var isWorking = false

    init() {
        settings = .shared
        previewReminders = nil
    }

    init(preview reminders: [EpisodeReminder], isEnabled: Bool = true) {
        settings = .preview(isEnabled: isEnabled)
        previewReminders = reminders
    }

    private var isDenied: Bool { status == .denied }

    var body: some View {
        List {
            Section {
                Toggle("Episode Reminders", isOn: Binding(
                    get: { settings.isEnabled },
                    set: { enable($0) }
                ))
                .disabled(isDenied || isWorking)

                if settings.isEnabled {
                    DatePicker("Remind Me At", selection: timeBinding,
                               displayedComponents: .hourAndMinute)
                }
            } header: {
                Text("Airings")
            } footer: {
                Text(footerText)
            }

            if settings.isEnabled, !upcoming.isEmpty {
                Section("Next Up") {
                    ForEach(upcoming.prefix(10)) { reminder in
                        UpcomingAiringRow(reminder: reminder)
                    }
                }
            }

            if isDenied {
                Section {
                    Button("Open Settings") {
                        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                        UIApplication.shared.open(url)
                    }
                }
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .task { await refresh() }
    }

    private var timeBinding: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(from: DateComponents(hour: settings.hour,
                                                           minute: settings.minute)) ?? Date()
            },
            set: { newValue in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                settings.setDeliveryTime(hour: parts.hour ?? 20, minute: parts.minute ?? 0)
                Task { await apply() }
            }
        )
    }

    private var footerText: String {
        if isDenied {
            return "Notifications are turned off for Marquee in Settings."
        }
        guard settings.isEnabled else {
            return "Get a reminder on the day a new episode of a show on your Watch List airs."
        }
        let count = upcoming.count
        guard count > 0 else {
            return "No airings scheduled. Shows on your Watch List with a known air date appear here."
        }
        let capped = count > EpisodeNotificationScheduler.maxScheduled
        let base = "Reminding you about \(scheduled) upcoming \(scheduled == 1 ? "airing" : "airings")."
        return capped ? base + " iOS allows only the soonest \(EpisodeNotificationScheduler.maxScheduled)." : base
    }

    // MARK: - Actions

    private func refresh() async {
        if let previewReminders {
            status = .authorized
            upcoming = previewReminders
            scheduled = previewReminders.count
            return
        }
        status = await EpisodeNotificationScheduler.authorizationStatus()
        upcoming = await store?.episodeReminders() ?? []
        if settings.isEnabled { await apply() }
    }

    private func enable(_ enabled: Bool) {
        isWorking = true
        Task {
            if enabled, status != .authorized {
                _ = await EpisodeNotificationScheduler.requestAuthorization()
                status = await EpisodeNotificationScheduler.authorizationStatus()
                // A denied prompt must not leave the toggle reading as on.
                settings.setEnabled(status == .authorized)
            } else {
                settings.setEnabled(enabled)
            }
            await apply()
            isWorking = false
        }
    }

    private func apply() async {
        guard previewReminders == nil else { return }
        let outcome = await EpisodeNotificationScheduler.reschedule(upcoming, settings: settings)
        scheduled = outcome.scheduled
    }
}

#Preview("On") {
    NavigationStack {
        NotificationSettingsView(preview: .previewList)
    }
    .preferredColorScheme(.dark)
}

#Preview("Off") {
    NavigationStack {
        NotificationSettingsView(preview: [], isEnabled: false)
    }
    .preferredColorScheme(.dark)
}

extension Array where Element == EpisodeReminder {
    static var previewList: [EpisodeReminder] {
        let day = 60.0 * 60 * 24
        return [
            EpisodeReminder(showTmdbID: 1, showName: "Last Week Tonight with John Oliver",
                            seasonNumber: 13, episodeNumber: 24,
                            airDate: MediaItem.floatingDay(from: Date())),
            EpisodeReminder(showTmdbID: 2, showName: "The Bear", seasonNumber: 5, episodeNumber: 3,
                            airDate: MediaItem.floatingDay(from: Date().addingTimeInterval(day))),
            EpisodeReminder(showTmdbID: 3, showName: "Slow Horses", seasonNumber: 6, episodeNumber: 1,
                            airDate: MediaItem.floatingDay(from: Date().addingTimeInterval(4 * day))),
            EpisodeReminder(showTmdbID: 4, showName: "Andor", seasonNumber: 3, episodeNumber: 7,
                            airDate: MediaItem.floatingDay(from: Date().addingTimeInterval(21 * day))),
            EpisodeReminder(showTmdbID: 5, showName: "Scrubs", seasonNumber: 2, episodeNumber: 1,
                            airDate: MediaItem.floatingDay(from: Date().addingTimeInterval(300 * day)))
        ]
    }
}
