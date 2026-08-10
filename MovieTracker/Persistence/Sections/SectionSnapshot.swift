//
//  SectionSnapshot.swift
//  MovieTracker
//

import Foundation

struct SectionSnapshot: Identifiable, Sendable, Equatable {
    let id: DateComponents
    let title: String
    let entries: [MediaSnapshot]
    /// True for the "Older" archive bucket, which the list renders collapsed.
    let isCollapsible: Bool
    /// When set (rating-sorted sections), the header renders this many filled stars
    /// instead of `title`. Nil for month/older/unrated sections, which show `title`.
    let ratingStars: Double?

    init(id: DateComponents, title: String, entries: [MediaSnapshot],
         isCollapsible: Bool, ratingStars: Double? = nil) {
        self.id = id
        self.title = title
        self.entries = entries
        self.isCollapsible = isCollapsible
        self.ratingStars = ratingStars
    }

    /// Sentinel id for the "Older" section; the negative year never collides with a
    /// real `[.year, .month]` key.
    static let olderID = DateComponents(year: -1, month: -1)
}
