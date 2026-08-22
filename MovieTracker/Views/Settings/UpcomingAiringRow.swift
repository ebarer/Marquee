//
//  UpcomingAiringRow.swift
//  MovieTracker
//

import SwiftUI

/// One scheduled airing: show, season and episode, with the day it lands on.
struct UpcomingAiringRow: View {
    let reminder: EpisodeReminder
    var tint: Color = .appAccent

    private var isSoon: Bool { reminder.airDate.hasRelativeDayName }

    var body: some View {
        LabeledContent {
            // This week the weekday is what you act on; further out the date is, so it leads.
            VStack(alignment: .trailing, spacing: 2) {
                Text(isSoon ? dayName : dateText)
                    .foregroundStyle(isSoon ? tint : .primary)
                Text(isSoon ? dateText : dayName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(reminder.showName)
                    .lineLimit(2)
                Text(reminder.seasonAndEpisode)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .alignmentGuide(.listRowSeparatorLeading) { $0[.leading] }
        }
    }

    // "Today"/"Tomorrow" read better than the weekday they fall on; everything else names the day.
    private var dayName: String {
        switch reminder.airDate.calendarDays(from: Date()) {
        case 0: return "Today"
        case 1: return "Tomorrow"
        default: return DateFormatter.weekdayName.string(from: reminder.airDate)
        }
    }

    private var dateText: String {
        let formatter = reminder.airDate.year == Date().year
            ? DateFormatter.airDayShort
            : DateFormatter.detailPresentation
        return formatter.string(from: reminder.airDate)
    }
}

#Preview {
    NavigationStack {
        List {
            Section("Next Up") {
                ForEach([EpisodeReminder].previewList) { reminder in
                    UpcomingAiringRow(reminder: reminder)
                }
            }
        }
    }
    .preferredColorScheme(.dark)
}
