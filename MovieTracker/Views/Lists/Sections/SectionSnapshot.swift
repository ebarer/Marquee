//
//  SectionSnapshot.swift
//  MovieTracker
//

import Foundation

struct SectionSnapshot: Identifiable, Sendable, Equatable {
    let id: DateComponents
    let title: String
    let entries: [MediaSnapshot]
    let isCollapsible: Bool
    let ratingStars: Double?

    init(id: DateComponents, title: String, entries: [MediaSnapshot],
         isCollapsible: Bool, ratingStars: Double? = nil) {
        self.id = id
        self.title = title
        self.entries = entries
        self.isCollapsible = isCollapsible
        self.ratingStars = ratingStars
    }

    // Sentinel id: the negative year never collides with a real `[.year, .month]` key.
    static let olderID = DateComponents(year: -1, month: -1)
}

extension Array where Element == SectionSnapshot {
    func monthSection(monthsBack: Int, from date: Date = Date(),
                      calendar: Calendar = .current) -> SectionSnapshot? {
        let anchor = calendar.date(byAdding: .month, value: -monthsBack, to: date) ?? date
        guard let target = Self.monthIndex(calendar.dateComponents([.year, .month], from: anchor))
        else { return nil }
        return compactMap { section in
            Self.monthIndex(section.id).map { (section: section, distance: abs($0 - target), index: $0) }
        }
        // Ties go to the earlier month, so a gap resolves backwards rather than into the future.
        .min { ($0.distance, $0.index) < ($1.distance, $1.index) }?
        .section
    }

    private static func monthIndex(_ components: DateComponents) -> Int? {
        guard let year = components.year, let month = components.month,
              (1...12).contains(month) else { return nil }
        return year * 12 + month
    }
}
