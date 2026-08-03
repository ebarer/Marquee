//
//  DateFormatter+Formats.swift
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
    
    public static var detailPresentation: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }
}
