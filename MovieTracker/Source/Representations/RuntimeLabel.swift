//
//  RuntimeLabel.swift
//  MovieTracker
//

import Foundation

/// Runtime presentation shared by movies, episodes and list rows.
enum RuntimeLabel {
    static let shortMinutes = 10

    static func duration(minutes: Int?) -> String? {
        // A 0 runtime means unknown, so show nothing rather than "0 hr 0 min".
        guard let minutes, minutes > 0 else { return nil }
        guard minutes >= 60 else { return "\(minutes) min" }
        return "\(minutes / 60) hr \(minutes % 60) min"
    }

    static func isShort(minutes: Int?) -> Bool {
        guard let minutes, minutes > 0 else { return false }
        return minutes < shortMinutes
    }
}
