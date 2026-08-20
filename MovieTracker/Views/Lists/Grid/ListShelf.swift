//
//  ListShelf.swift
//  MovieTracker
//

import SwiftUI

/// One section's cards, scrolling horizontally under a pinned bookmark and fading out as they reach it.
struct ListShelf<Bookmark: View, Cards: View>: View {
    let spacing: CGFloat
    private let bookmark: Bookmark
    private let cards: Cards

    @State private var scrolled: CGFloat = 0

    init(spacing: CGFloat, @ViewBuilder bookmark: () -> Bookmark,
         @ViewBuilder cards: () -> Cards) {
        self.spacing = spacing
        self.bookmark = bookmark()
        self.cards = cards()
    }

    var body: some View {
        ZStack(alignment: .leading) {
            ScrollView(.horizontal) {
                LazyHStack(spacing: spacing) {
                    cards
                }
                .padding(.leading, ListSectionBookmark.width + spacing)
                .padding(.trailing, 20)
                .background { travelReader }
            }
            .scrollIndicators(.hidden)
            .fadesPastBookmark(scrolled: scrolled)

            bookmark
        }
        .coordinateSpace(.named(shelfSpace))
    }

    /// How far the cards have travelled, read from where they sit in the shelf. Taken from the
    /// cards, not the scroll view: this one is nested inside the list's own vertical scroll.
    private var travelReader: some View {
        GeometryReader { geometry in
            let travelled = max(0, -geometry.frame(in: .named(shelfSpace)).minX)
            Color.clear
                .onChange(of: travelled, initial: true) { _, new in scrolled = new }
        }
    }
}

private let shelfSpace = "listShelf"

extension View {
    /// Masks a shelf so its cards dissolve at the bookmark's edge. The ramp starts at that edge
    /// and grows outward with `scrolled`, so at rest it has no width and the first card is crisp.
    func fadesPastBookmark(scrolled: CGFloat) -> some View {
        let ramp = min(scrolled, ListSectionBookmark.fadeSpan)
        return mask(alignment: .leading) {
            HStack(spacing: 0) {
                Rectangle()
                    .fill(.clear)
                    .frame(width: ListSectionBookmark.width)
                LinearGradient(colors: [.clear, .black], startPoint: .leading, endPoint: .trailing)
                    .frame(width: ramp)
                Rectangle()
            }
        }
    }
}

#Preview("At rest") {
    let context = ListEntryContext(selection: .list(UUID()), isWatchList: true,
                                   watchListIDs: [], listColor: .appAccent)
    let section = SectionSnapshot(id: DateComponents(year: 2026, month: 8), title: "August 2026",
                                  entries: (1...5).map { .preview(id: $0, title: "Title \($0)") },
                                  isCollapsible: false)

    ListShelf(spacing: 16) {
        ListSectionBookmark(section: section, tint: .appAccent)
    } cards: {
        ForEach(section.entries) { entry in
            ListEntryContent(entry: entry, context: context)
                .frame(maxHeight: .infinity, alignment: .top)
                .gridCard()
                .frame(width: 280)
        }
    }
    .frame(height: 102)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    .background(Color.appBackground)
    .modelContainer(previewModelContainer)
    .environment(PersistenceCoordinator(previewModelContainer.mainContext))
    .preferredColorScheme(.dark)
}

#Preview("Mid-scroll fade") {
    let context = ListEntryContext(selection: .list(UUID()), isWatchList: true,
                                   watchListIDs: [], listColor: .appAccent)
    let section = SectionSnapshot(id: DateComponents(year: 2026, month: 8), title: "August 2026",
                                  entries: (1...5).map { .preview(id: $0, title: "Title \($0)") },
                                  isCollapsible: false)

    VStack(spacing: 24) {
        ForEach([CGFloat(0), 24, 64, 200], id: \.self) { scrolled in
            ZStack(alignment: .leading) {
                HStack(spacing: 16) {
                    ForEach(section.entries.prefix(2)) { entry in
                        ListEntryContent(entry: entry, context: context)
                            .gridCard()
                            .frame(width: 280)
                    }
                }
                .padding(.leading, ListSectionBookmark.width + 16)
                .offset(x: -scrolled)
                .fadesPastBookmark(scrolled: scrolled)

                ListSectionBookmark(section: section, tint: .appAccent)
            }
            .frame(height: 102)
            .frame(maxWidth: .infinity, alignment: .leading)
            .clipped()
        }
    }
    .background(Color.appBackground)
    .modelContainer(previewModelContainer)
    .environment(PersistenceCoordinator(previewModelContainer.mainContext))
    .preferredColorScheme(.dark)
}
