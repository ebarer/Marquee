//
//  ListGrid.swift
//  MovieTracker
//

import SwiftUI
import SwiftData

/// The iPad presentation: the same sections, entries and swipes as `ListTable`, as grid cards.
/// Taps route through `DetailLink` because in-`List` row taps were being swallowed during sync.
struct ListGrid: View {
    let sections: [SectionSnapshot]
    let context: ListEntryContext
    let lists: [MediaList]

    @Environment(PersistenceCoordinator.self) private var store: PersistenceCoordinator?
    @State private var pending: ListEntryConfirmation?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 16), count: 3)

    private var actions: ListEntryActions {
        ListEntryActions(store: store, context: context, pending: $pending)
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                ForEach(sections) { section in
                    if !section.title.isEmpty {
                        ListSectionLabel(section: section, tint: context.listColor)
                            .font(.headline)
                            .padding(.horizontal, 20)
                    }
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(section.entries) { entry in
                            card(for: entry)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
            .padding(.vertical, 16)
        }
        .modifier(SwipeGridContainer())
    }

    private func card(for entry: MediaSnapshot) -> some View {
        ListEntryLink(entry: entry) {
            ListEntryContent(entry: entry, context: context)
                .gridCard()
        }
        .buttonStyle(.plain)
        .listEntryContextMenu(for: entry, lists: lists)
        .listEntrySwipes(entry: entry, context: context, actions: actions)
    }
}

/// iOS 27+ enables `swipeActions` outside a `List`; a no-op (no swipe) on earlier systems.
private struct SwipeGridContainer: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 27, *) {
            content.swipeActionsContainer()
        } else {
            content
        }
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
