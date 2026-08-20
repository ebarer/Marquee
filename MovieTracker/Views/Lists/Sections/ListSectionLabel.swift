//
//  ListSectionLabel.swift
//  MovieTracker
//

import SwiftUI

/// A section's header content: filled stars for rating-sorted sections, otherwise its title.
struct ListSectionLabel: View {
    let section: SectionSnapshot
    let tint: Color

    var body: some View {
        if let stars = section.ratingStars {
            StarRating(display: stars, size: 15, tint: tint)
        } else {
            Text(section.title)
                .font(.headline)
                .foregroundStyle(tint)
        }
    }
}

#Preview("Section labels") {
    let rated = SectionSnapshot(id: DateComponents(year: 9010), title: "4.5 Stars",
                                entries: [], isCollapsible: false, ratingStars: 4.5)
    let month = SectionSnapshot(id: DateComponents(year: 2026, month: 8), title: "August 2026",
                                entries: [], isCollapsible: false)
    let letter = SectionSnapshot(id: DateComponents(year: 8065), title: "A",
                                 entries: [], isCollapsible: false)
    VStack(alignment: .leading, spacing: 16) {
        ListSectionLabel(section: rated, tint: ListDestination.watchedColor)
        ListSectionLabel(section: month, tint: .appAccent)
        ListSectionLabel(section: letter, tint: .appAccent)
    }
    .padding()
    .background(Color.appBackground)
    .preferredColorScheme(.dark)
}
