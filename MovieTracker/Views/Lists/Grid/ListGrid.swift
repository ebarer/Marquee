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

    private var actions: ListEntryActions {
        ListEntryActions(store: store, context: context, pending: $pending)
    }

    // Headers scroll with the content. Pinning them put a strip of cards between the nav bar's
    // glass and the pinned header, and no scroll-to-anchor on expand: it aimed under the bar.
    var body: some View {
        ScrollView {
            // Spacing is small because every header carries its own height (`SectionHeaderRow`).
            LazyVStack(alignment: .leading, spacing: 10) {
                ForEach(sections) { section in
                    if section.isCollapsible {
                        olderHeader(count: section.entries.count)
                        if olderExpanded {
                            grid(for: section)
                        }
                    } else {
                        if !section.title.isEmpty {
                            ListSectionLabel(section: section, tint: context.listColor)
                                .font(.headline)
                                .modifier(SectionHeaderRow())
                        }
                        grid(for: section)
                    }
                }
            }
            .padding(.vertical, 16)
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
            }
            .font(.headline)
            .foregroundStyle(context.listColor)
            .modifier(SectionHeaderRow())
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

/// One height for every section header — the 44pt the collapsible one needs as a tap target —
/// so a list's first row sits where the last one's did. The text sits at the band's bottom.
private struct SectionHeaderRow: ViewModifier {
    /// Trims the gap above without shrinking the band: the button keeps its 44pt of hit area
    /// and the overhang lands on the empty space between sections.
    private static var overhang: CGFloat { 8 }

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .bottomLeading)
            .padding(.horizontal, 20)
            .padding(.top, -Self.overhang)
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
