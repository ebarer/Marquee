//
//  ListResult.swift
//  MovieTracker
//

import Foundation

/// A list row with the date its section is anchored on.
struct DatedRow: Sendable, Equatable {
    let date: Date
    let snapshot: MediaSnapshot
}

/// How a list's rows should be arranged into sections.
enum SectionLayout: Sendable, Equatable {
    case flat
    case months(foldOlder: OlderFold)
    case ratingStars
    case initials
}

/// `ListCoordinator`'s output: rows plus the layout to apply.
struct ListResult: Sendable, Equatable {
    let rows: [DatedRow]
    let layout: SectionLayout
}
