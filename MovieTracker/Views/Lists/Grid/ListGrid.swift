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
    @State private var pending: ListEntryConfirmation?
    /// The "Older" archive bucket starts collapsed each visit, as in `ListTable`.
    @State private var olderExpanded = false

    /// Room for a row's poster beside two lines of title and a rating.
    private static let cardWidth: CGFloat = 280
    private static let spacing: CGFloat = 16

    private var actions: ListEntryActions {
        ListEntryActions(store: store, context: context, pending: $pending)
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: Self.spacing) {
                ForEach(sections) { section in
                    if section.isCollapsible {
                        collapsible(section)
                    } else if section.monthAndYear != nil {
                        shelf(for: section) {
                            ListSectionBookmark(section: section, tint: context.listColor)
                        }
                    } else {
                        stack(section)
                    }
                }
            }
            .padding(.vertical, 20)
        }
        .background(Color.appBackground)
        .swipeGridContainer()
    }

    private func shelf(for section: SectionSnapshot,
                       @ViewBuilder bookmark: () -> some View) -> some View {
        ListShelf(spacing: Self.spacing, bookmark: bookmark) {
            ForEach(section.entries) { entry in
                card(for: entry)
            }
        }
    }

    /// The "Older" bucket: its bookmark is the control, and its shelf appears alongside.
    @ViewBuilder
    private func collapsible(_ section: SectionSnapshot) -> some View {
        if olderExpanded {
            shelf(for: section) { olderBookmark(section) }
        } else {
            olderBookmark(section)
                .frame(height: Self.collapsedHeight)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func olderBookmark(_ section: SectionSnapshot) -> some View {
        Button {
            withAnimation { olderExpanded.toggle() }
        } label: {
            ListSectionBookmark(section: section, tint: context.listColor, expanded: olderExpanded)
        }
        .buttonStyle(.plain)
    }

    /// Tall enough that the collapsed bucket reads as the shelf it stands in for.
    private static let collapsedHeight: CGFloat = 72

    /// A bucket that isn't a month — a rating or an initial — holds far more titles than a shelf
    /// can show, so it flows under a plain header instead. The flat layout has no header at all.
    @ViewBuilder
    private func stack(_ section: SectionSnapshot) -> some View {
        if !section.title.isEmpty {
            ListSectionLabel(section: section, tint: context.listColor)
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .bottomLeading)
                .padding(.horizontal, 20)
        }
        grid(for: section)
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
