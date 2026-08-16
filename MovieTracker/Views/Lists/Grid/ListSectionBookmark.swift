//
//  ListSectionBookmark.swift
//  MovieTracker
//

import SwiftUI

/// A section's name pinned at the leading edge of its shelf, like a tab in a deck of cards.
struct ListSectionBookmark: View {
    let section: SectionSnapshot
    let tint: Color

    static let width: CGFloat = 124

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            if let year {
                Text(year)
                    .font(.footnote.bold())
                    .foregroundStyle(tint)
            }

            Text(section.monthAndYear?.month ?? section.title)
                .font(.headline.bold())
                .foregroundStyle(tint)

            Text("^[\(section.entries.count) Title](inflect: true)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 2)
        }
        .padding(.horizontal, 14)
        .frame(width: Self.width, alignment: .leading)
        .frame(maxHeight: .infinity)
        .background { backdrop }
    }

    /// Opaque in every layer, so a card scrolling past passes under it and never shows to its
    /// left. Square where it meets the page, rounded where it meets the cards.
    private var backdrop: some View {
        let shape = UnevenRoundedRectangle(bottomTrailingRadius: 14, topTrailingRadius: 14,
                                           style: .continuous)
        return ZStack {
            shape.fill(Color.appBackground)
            shape.fill(tint.opacity(0.14))
            HStack(spacing: 0) {
                Rectangle().fill(tint).frame(width: 4)
                Spacer(minLength: 0)
            }
        }
    }

    private var year: String? { section.monthAndYear?.year }
}

extension ListSectionBookmark {
    /// How far a card takes to fade in behind the bookmark, once the shelf is scrolled.
    static let fadeSpan: CGFloat = 64
}

extension SectionSnapshot {
    /// The month and year this section groups, when its key names one. Nil for the buckets whose
    /// keys carry no month — rating, initial, "Older" — and for the flat layout's one section.
    var monthAndYear: (month: String, year: String)? {
        guard let month = id.month, (1...12).contains(month), let year = id.year else { return nil }
        return (Calendar.current.standaloneMonthSymbols[month - 1],
                year.formatted(.number.grouping(.never)))
    }
}

#Preview("Bookmarks") {
    let month = SectionSnapshot(id: DateComponents(year: 2026, month: 8), title: "August 2026",
                                entries: [.preview(id: 1, title: "One")], isCollapsible: false)
    let rated = SectionSnapshot(id: DateComponents(year: 9009), title: "4.5 Stars",
                                entries: (1...4).map { .preview(id: $0, title: "T\($0)") },
                                isCollapsible: false, ratingStars: 4.5)
    let older = SectionSnapshot(id: SectionSnapshot.olderID, title: "Older",
                                entries: (1...12).map { .preview(id: $0, title: "T\($0)") },
                                isCollapsible: true)

    // Each one stands the height of the shelf it would be pinned to.
    VStack(alignment: .leading, spacing: 12) {
        ListSectionBookmark(section: month, tint: .appAccent)
        ListSectionBookmark(section: rated, tint: ListDestination.watchedColor)
        ListSectionBookmark(section: older, tint: .appAccent)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    .background(Color.appBackground)
    .preferredColorScheme(.dark)
}
