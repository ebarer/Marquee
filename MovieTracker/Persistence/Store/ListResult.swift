//
//  ListResult.swift
//  MovieTracker
//

import Foundation

/// A list row with the date its section is anchored on (release, added, or watched — the
/// coordinator decides per list). Handed to `SectionFormatter`, which sorts and groups.
struct DatedRow: Sendable, Equatable {
    let date: Date
    let snapshot: MediaSnapshot
}

/// How a list's rows should be arranged into sections. The coordinator picks this from the
/// request (and the data — e.g. whether a list is the Watch List); the formatter carries it out.
enum SectionLayout: Sendable, Equatable {
    /// One headerless section, sorted by date.
    case flat
    /// Month/year buckets, folding the stale rows of the named media types into a collapsed
    /// "Older" bucket.
    case months(foldOlder: OlderFold)
    /// Buckets by half-star rating, unrated last.
    case ratingStars
    /// Buckets by the title's first letter, digits and symbols under "#".
    case initials
}

/// The raw output of `ListCoordinator`: rows plus the layout the formatter should apply.
struct ListResult: Sendable, Equatable {
    let rows: [DatedRow]
    let layout: SectionLayout
}
