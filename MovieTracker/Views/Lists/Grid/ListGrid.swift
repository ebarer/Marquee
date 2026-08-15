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
    /// The "Older" archive bucket starts collapsed each visit, as in `ListTable`.
    @State private var olderExpanded = false

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 16), count: 3)

    /// ScrollViewReader target for the collapsible "Older" section.
    private static let olderAnchor = "older-section"

    private var actions: ListEntryActions {
        ListEntryActions(store: store, context: context, pending: $pending)
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    ForEach(sections) { section in
                        if section.isCollapsible {
                            olderHeader(count: section.entries.count)
                                .padding(.horizontal, 20)
                                .id(Self.olderAnchor)
                            if olderExpanded {
                                grid(for: section)
                            }
                        } else {
                            if !section.title.isEmpty {
                                ListSectionLabel(section: section, tint: context.listColor)
                                    .font(.headline)
                                    .padding(.horizontal, 20)
                            }
                            grid(for: section)
                        }
                    }
                }
                .padding(.vertical, 16)
            }
            .onChange(of: olderExpanded) { _, expanded in
                guard expanded else { return }
                withAnimation { proxy.scrollTo(Self.olderAnchor, anchor: .top) }
            }
        }
        .swipeGridContainer()
    }

    private func grid(for section: SectionSnapshot) -> some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(section.entries) { entry in
                card(for: entry)
            }
        }
        .padding(.horizontal, 20)
    }

    /// Tappable header for the collapsible "Older" bucket.
    private func olderHeader(count: Int) -> some View {
        Button {
            withAnimation { olderExpanded.toggle() }
        } label: {
            HStack(spacing: 6) {
                Text("Older (\(count))")
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .rotationEffect(.degrees(olderExpanded ? 90 : 0))
                Spacer()
            }
            .font(.headline)
            .foregroundStyle(context.listColor)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
