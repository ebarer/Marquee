//
//  DateFormatter+Extension.swift
//  MovieTracker
//
//  Created by Elliot Barer on 6/12/18.
//  Copyright © 2018 ebarer. All rights reserved.
//

import Foundation

extension Date {
    func toString() -> String {
        return DateFormatter.detailPresentation.string(from: self)
    }

    /// Calendar year in UTC, matching the ISO-8601 formatters used across the app.
    var year: Int {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar.component(.year, from: self)
    }

    /// Whole calendar days from `reference`'s day to this date's day. Air dates parse at UTC
    /// midnight, so comparing days (not instants) stops tomorrow reading as past at 5pm here.
    func calendarDays(from reference: Date) -> Int? {
        let calendar = DateFormatter.utcCalendar
        let day = calendar.dateComponents([.year, .month, .day], from: self)
        let referenceDay = Calendar.current.dateComponents([.year, .month, .day], from: reference)
        guard let then = calendar.date(from: day),
              let now = calendar.date(from: referenceDay) else { return nil }
        return calendar.dateComponents([.day], from: now, to: then).day
    }

    /// True while this date's calendar day is still ahead of the device's own today, so an
    /// episode airing tomorrow can't be watched no matter how late in the evening it is here.
    func isInTheFuture(asOf reference: Date = Date()) -> Bool {
        guard let days = calendarDays(from: reference) else { return false }
        return days > 0
    }

    var inTheFuture: Bool { isInTheFuture() }

    /// True while this falls in the next seven days — the window `toRelativeDayString()` names
    /// a day in, so callers can highlight it.
    var isWithinTheComingWeek: Bool {
        guard let days = calendarDaysFromToday else { return false }
        return (0...6).contains(days)
    }

    private var calendarDaysFromToday: Int? { calendarDays(from: Date()) }

    /// "Today", "Tomorrow" or "Thursday" within the coming week — a bare weekday name only
    /// reads unambiguously that close. Otherwise the full date, "Aug 13, 2026".
    func toRelativeDayString() -> String {
        switch calendarDaysFromToday {
        case 0: return "Today"
        case 1: return "Tomorrow"
        case .some(2...6): return DateFormatter.weekdayName.string(from: self)
        default: return toString()
        }
    }
}

extension DateFormatter {
    enum DateFormats {
        case iso8601DAw
        case iso8601DTw
    }
    
    public static var iso8601DAw: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }
    
    public static var iso8601DTw: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ"
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }
    
    public static var sectionHeader: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }
    
    static var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    public static var weekdayName: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }

    public static var detailPresentation: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }
}
