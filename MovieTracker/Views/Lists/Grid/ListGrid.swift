//
//  ListGrid.swift
//  MovieTracker
//

import SwiftUI
import SwiftData

/// The iPad presentation: a shelf per section, its name pinned at the leading edge. Taps route
/// through `DetailLink` because in-`List` row taps were being swallowed during sync.
struct ListGrid: View {
    let sections: [SectionSnapshot]
    let context: ListEntryContext
    let lists: [MediaList]

    @Environment(PersistenceCoordinator.self) private var store: PersistenceCoordinator?
    @Environment(\.scrollTopToken) private var scrollTopToken
    @State private var pending: ListEntryConfirmation?
    @State private var position = ScrollPosition()
    /// Where a pinned header comes to rest, and whether anything has scrolled under it.
    @State private var pinLine: CGFloat = 0
    @State private var scrolled = false

    /// Room for a row's poster beside two lines of title and a rating.
    private static let cardWidth: CGFloat = 280
    private static let spacing: CGFloat = 16
    private static let space = "listGrid"

    private var actions: ListEntryActions {
        ListEntryActions(store: store, context: context, pending: $pending)
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: Self.spacing, pinnedViews: [.sectionHeaders]) {
                ForEach(sections) { section in
                    Section {
                        content(for: section)
                    } header: {
                        header(for: section)
                    }
                }
            }
            // A pinned header brings its own top inset; a shelf has none of its own.
            .padding(.top, topPadding)
            .padding(.bottom, 20)
        }
        .background(Color.appBackground)
        // The header's own glass reaches the top edge, so the system's would double it.
        .scrollEdgeEffectHidden(hasPinnedHeaders, for: .top)
        .coordinateSpace(.named(Self.space))
        .scrollPosition($position)
        .onScrollGeometryChange(for: CGFloat.self) { $0.contentInsets.top } action: { _, inset in
            pinLine = inset
        }
        .onScrollGeometryChange(for: Bool.self) { geometry in
            geometry.contentOffset.y + geometry.contentInsets.top > 1
        } action: { _, isScrolled in
            scrolled = isScrolled
        }
        .swipeGridContainer()
        .onChange(of: scrollTopToken) { scrollToTop() }
    }

    private var hasPinnedHeaders: Bool {
        sections.contains { !isShelf($0) && !$0.title.isEmpty }
    }

    /// Month buckets and the "Older" archive scroll sideways under a bookmark. "Older" isn't
    /// folded here: a shelf costs no more room than the collapsed bookmark standing in for it.
    private func isShelf(_ section: SectionSnapshot) -> Bool {
        section.monthAndYear != nil || section.isCollapsible
    }

    /// A headered layout takes the header's own 10pt inset plus 2pt, which lands its title on the
    /// sidebar's section headers — the system insets those by 12pt. A shelf has no inset of its own.
    private var topPadding: CGFloat {
        guard let first = sections.first, !isShelf(first), !first.title.isEmpty else { return 20 }
        return 2
    }

    @ViewBuilder
    private func content(for section: SectionSnapshot) -> some View {
        if isShelf(section) {
            shelf(for: section) {
                ListSectionBookmark(section: section, tint: context.listColor)
            }
        } else {
            grid(for: section)
        }
    }

    /// A bucket that isn't a month — a rating or an initial — holds far more titles than a shelf
    /// can show, so it flows under a pinned header instead. The flat layout has no header at all.
    @ViewBuilder
    private func header(for section: SectionSnapshot) -> some View {
        if !isShelf(section), !section.title.isEmpty {
            ListSectionLabel(section: section, tint: context.listColor)
                .sectionHeaderInsets(horizontal: 20)
                .stickyHeaderBackground(space: Self.space, pinLine: pinLine, scrolled: scrolled,
                                        glassTop: pinLine)
        }
    }

    private func shelf(for section: SectionSnapshot,
                       @ViewBuilder bookmark: () -> some View) -> some View {
        ListShelf(spacing: Self.spacing, bookmark: bookmark) {
            ForEach(section.entries) { entry in
                card(for: entry)
            }
        }
    }

    /// Scrolled by edge, not by section id, which doesn't resolve outside a long list's realised
    /// range. Released once it lands so the edge isn't held against the next scroll.
    private func scrollToTop() {
        withAnimation(.easeOut(duration: 0.3)) {
            position.scrollTo(edge: .top)
        } completion: {
            position = ScrollPosition()
        }
    }

    private func grid(for section: SectionSnapshot) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: Self.cardWidth, maximum: 480),
                                    spacing: Self.spacing)],
                  spacing: Self.spacing) {
            ForEach(section.entries) { entry in
                ListEntryLink(entry: entry) {
                    ListEntryContent(entry: entry, context: context)
                        .gridCard()
                }
                .buttonStyle(.plain)
                .listEntryContextMenu(for: entry, lists: lists)
                .listEntrySwipes(entry: entry, context: context, actions: actions)
            }
        }
        .padding(.horizontal, 20)
    }

    private func card(for entry: MediaSnapshot) -> some View {
        ListEntryLink(entry: entry) {
            ListEntryContent(entry: entry, context: context)
                // Fills the shelf, so every card on it is the same height.
                .frame(maxHeight: .infinity, alignment: .top)
                .gridCard()
        }
        .frame(width: Self.cardWidth)
        .buttonStyle(.plain)
        .listEntryContextMenu(for: entry, lists: lists)
        .listEntrySwipes(entry: entry, context: context, actions: actions)
    }
}

#Preview("Grid") {
    let sections = [
        SectionSnapshot(id: DateComponents(year: 2026, month: 8), title: "August 2026",
                        entries: [.preview(id: 1, title: "The Odyssey"),
                                  .preview(id: 2, title: "Severance", mediaType: .tv, season: 2,
                                           seasonWatched: 3, seasonTotal: 10),
                                  .preview(id: 3, title: "Andor", mediaType: .tv)],
                        isCollapsible: false),
    ]
    NavigationStack {
        ListGrid(sections: sections,
                 context: ListEntryContext(selection: .list(UUID()), isWatchList: true,
                                           watchListIDs: [], listColor: .appAccent),
                 lists: [])
            .detailDestinations()
    }
    .modelContainer(previewModelContainer)
    .environment(PersistenceCoordinator(previewModelContainer.mainContext))
    .preferredColorScheme(.dark)
}

#Preview("Sparse sections") {
    let sections = [
        SectionSnapshot(id: DateComponents(year: 2026, month: 9), title: "September 2026",
                        entries: [.preview(id: 1, title: "One Alone")], isCollapsible: false),
        SectionSnapshot(id: DateComponents(year: 2026, month: 10), title: "October 2026",
                        entries: [.preview(id: 2, title: "Severance", mediaType: .tv, season: 2,
                                           seasonWatched: 3, seasonTotal: 10),
                                  .preview(id: 3, title: "Andor", mediaType: .tv)],
                        isCollapsible: false),
        SectionSnapshot(id: DateComponents(year: 2026, month: 11), title: "November 2026",
                        entries: [.preview(id: 4, title: "The Odyssey"),
                                  .preview(id: 5, title: "Dune: Part Three"),
                                  .preview(id: 6, title: "Wicked: For Good"),
                                  .preview(id: 7, title: "Avatar: Fire and Ash")],
                        isCollapsible: false),
        SectionSnapshot(id: DateComponents(year: 2026, month: 12), title: "December 2026",
                        entries: (8...14).map { .preview(id: $0, title: "Title Number \($0)") },
                        isCollapsible: false),
    ]
    NavigationStack {
        ListGrid(sections: sections,
                 context: ListEntryContext(selection: .list(UUID()), isWatchList: true,
                                           watchListIDs: [], listColor: .appAccent),
                 lists: [])
            .detailDestinations()
    }
    .modelContainer(previewModelContainer)
    .environment(PersistenceCoordinator(previewModelContainer.mainContext))
    .preferredColorScheme(.dark)
}

#Preview("Older bucket") {
    let sections = [
        SectionSnapshot(id: DateComponents(year: 2026, month: 8), title: "August 2026",
                        entries: [.preview(id: 1, title: "New Release")], isCollapsible: false),
        SectionSnapshot(id: SectionSnapshot.olderID, title: "Older",
                        entries: [.preview(id: 3, title: "Old One"),
                                  .preview(id: 4, title: "Old Two"),
                                  .preview(id: 5, title: "Old Three")],
                        isCollapsible: true),
    ]
    NavigationStack {
        ListGrid(sections: sections,
                 context: ListEntryContext(selection: .list(UUID()), isWatchList: true,
                                           watchListIDs: [], listColor: .appAccent),
                 lists: [])
            .detailDestinations()
    }
    .modelContainer(previewModelContainer)
    .environment(PersistenceCoordinator(previewModelContainer.mainContext))
    .preferredColorScheme(.dark)
}

// Rating buckets stack under their header rather than scrolling sideways.
#Preview("Rated sections") {
    let sections = [
        SectionSnapshot(id: DateComponents(year: 9009), title: "4.5 Stars",
                        entries: (1...5).map { .preview(id: $0, title: "Title Number \($0)",
                                                        dateWatched: .now, userRating: 4.5) },
                        isCollapsible: false, ratingStars: 4.5),
        SectionSnapshot(id: DateComponents(year: 9008), title: "4 Stars",
                        entries: (6...8).map { .preview(id: $0, title: "Title Number \($0)",
                                                        dateWatched: .now, userRating: 4) },
                        isCollapsible: false, ratingStars: 4),
        SectionSnapshot(id: DateComponents(year: 9000), title: "Unrated",
                        entries: (9...11).map { .preview(id: $0, title: "Title Number \($0)",
                                                         dateWatched: .now) },
                        isCollapsible: false),
    ]
    NavigationStack {
        ListGrid(sections: sections,
                 context: ListEntryContext(selection: .watched, isWatchList: false,
                                           watchListIDs: [],
                                           listColor: ListDestination.watchedColor),
                 lists: [])
            .detailDestinations()
    }
    .modelContainer(previewModelContainer)
    .environment(PersistenceCoordinator(previewModelContainer.mainContext))
    .preferredColorScheme(.dark)
}

#Preview("Flat (no sections)") {
    let sections = [
        SectionSnapshot(id: DateComponents(), title: "",
                        entries: (1...9).map { .preview(id: $0, title: "Title Number \($0)") },
                        isCollapsible: false),
    ]
    NavigationStack {
        ListGrid(sections: sections,
                 context: ListEntryContext(selection: .list(UUID()), isWatchList: true,
                                           watchListIDs: [], listColor: .appAccent),
                 lists: [])
            .detailDestinations()
    }
    .modelContainer(previewModelContainer)
    .environment(PersistenceCoordinator(previewModelContainer.mainContext))
    .preferredColorScheme(.dark)
}
