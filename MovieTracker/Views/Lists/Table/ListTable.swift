//
//  ListTable.swift
//  MovieTracker
//

import SwiftUI
import SwiftData

/// The iPhone presentation. No SwiftData in `body`, and `Equatable`: a store tick mid-push costs the row its selection.
struct ListTable: View, Equatable {
    let sections: [SectionSnapshot]
    let context: ListEntryContext
    let lists: [MediaList]
    var startToken: Int = 0

    @Environment(PersistenceCoordinator.self) private var store: PersistenceCoordinator?

    @State private var olderExpanded = false
    // One per screen: two presentations of a kind would cancel each other out.
    @State private var pending: ListEntryConfirmation?
    @State private var pinLine: CGFloat = 0

    // `lists` is excluded: comparing them would put a SwiftData read back in the render path.
    static func == (lhs: ListTable, rhs: ListTable) -> Bool {
        lhs.sections == rhs.sections && lhs.context == rhs.context
            && lhs.startToken == rhs.startToken
    }

    private static let olderAnchor = "older-section"

    private static let headerInsets = SectionHeaderMetrics.listRowInsets

    private static let olderFadeDistance: CGFloat = 14

    private var actions: ListEntryActions {
        ListEntryActions(store: store, context: context, pending: $pending)
    }

    var body: some View {
        ScrollViewReader { proxy in
            List { sectionsContent }
                // The header's own insets set the spacing; section spacing would add to it.
                .listSectionSpacing(0)
                // Clear the floating tab bar so the last section isn't jammed against
                // it, and leave slack to scroll an expanded "Older" bucket into view.
                .contentMargins(.bottom, 24, for: .scrollContent)
                .onChange(of: olderExpanded) { _, expanded in
                    guard expanded else { return }
                    withAnimation { proxy.scrollTo(Self.olderAnchor, anchor: .top) }
                }
                .onChange(of: startToken) { scrollToOpeningMonth(proxy) }
                // Where the month headers pin, and so where the "Older" header has to disappear.
                .onScrollGeometryChange(for: CGFloat.self) { $0.contentInsets.top } action: { _, top in
                    pinLine = top
                }
        }
    }

    private func scrollToOpeningMonth(_ proxy: ScrollViewProxy) {
        guard context.isWatchList,
              let start = sections.monthSection(monthsBack: 1) else { return }
        withAnimation(.easeOut(duration: 0.35)) { proxy.scrollTo(start.id, anchor: .top) }
    }

    // MARK: - Sections

    @ViewBuilder
    private var sectionsContent: some View {
        if context.isViewed {
            rows(for: sections.first?.entries ?? [], hasHeader: false)
        } else {
            ForEach(sections) { section in
                if section.isCollapsible {
                    Section {
                        if olderExpanded {
                            rows(for: section.entries, hasHeader: true)
                        }
                    } header: {
                        olderHeader(count: section.entries.count)
                    }
                    .id(Self.olderAnchor)
                } else if section.title.isEmpty {
                    rows(for: section.entries, hasHeader: false)
                } else {
                    Section {
                        rows(for: section.entries, hasHeader: true)
                    } header: {
                        // The scroll target lives on the header row, not the section: a `List`
                        // won't scroll to a section's own id.
                        ListSectionLabel(section: section, tint: context.listColor)
                            .listRowInsets(Self.headerInsets)
                            .id(section.id)
                    }
                }
            }
        }
    }

    // Collapsed, this section is only its header, so the list has no room to pin it: it scrolls into
    // the bar, where the edge effect has faded to nothing and leaves it legible. Fade it out there.
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
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowInsets(Self.headerInsets)
        .visualEffect { [expanded = olderExpanded, pinLine] content, proxy in
            let crossed = proxy.frame(in: .scrollView).minY - pinLine
            let fade = min(1, max(0, 1 + crossed / Self.olderFadeDistance))
            return content.opacity(expanded ? 1 : fade)
        }
    }

    // MARK: - Rows

    private func rows(for entries: [MediaSnapshot], hasHeader: Bool) -> some View {
        ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
            let firstEdge: Visibility = (!hasHeader && index == 0) ? .hidden : .automatic
            let lastEdge: Visibility = index == entries.count - 1 ? .hidden : .automatic
            ListEntryRow(entry: entry, context: context, actions: actions, lists: lists)
                .listRowSeparator(lastEdge, edges: .bottom)
                // Hide the first row's top separator when it has no header above it.
                .listRowSeparator(firstEdge, edges: .top)
        }
    }
}

#Preview("Empty") {
    ListTable(sections: [],
             context: ListEntryContext(selection: .watched, isWatchList: false,
                                       watchListIDs: [], listColor: .appAccent),
             lists: [])
        .listStyle(.plain)
        .modelContainer(previewModelContainer)
        .environment(PersistenceCoordinator(previewModelContainer.mainContext))
}

#Preview("Older bucket") {
    let sections = [
        SectionSnapshot(id: DateComponents(year: 2026, month: 8), title: "August 2026",
                        entries: [.preview(id: 1, title: "New Release")], isCollapsible: false),
        SectionSnapshot(id: DateComponents(year: 2026, month: 7), title: "July 2026",
                        entries: [.preview(id: 2, title: "Still in Theatres")], isCollapsible: false),
        SectionSnapshot(id: SectionSnapshot.olderID, title: "Older",
                        entries: [.preview(id: 3, title: "Old One"),
                                  .preview(id: 4, title: "Old Two"),
                                  .preview(id: 5, title: "Old Three")],
                        isCollapsible: true),
    ]
    NavigationStack {
        ListTable(sections: sections,
                 context: ListEntryContext(selection: .list(UUID()), isWatchList: true,
                                           watchListIDs: [], listColor: .appAccent),
                 lists: [])
            .listStyle(.plain)
    }
    .modelContainer(previewModelContainer)
    .environment(PersistenceCoordinator(previewModelContainer.mainContext))
    .preferredColorScheme(.dark)
}

#Preview("Custom list — grouped by title") {
    let sections = [
        SectionSnapshot(id: DateComponents(year: 8035), title: "#",
                        entries: [.preview(id: 1, title: "1917")], isCollapsible: false),
        SectionSnapshot(id: DateComponents(year: 8065), title: "A",
                        entries: [.preview(id: 2, title: "Alien"),
                                  .preview(id: 3, title: "Arrival")], isCollapsible: false),
        SectionSnapshot(id: DateComponents(year: 8066), title: "B",
                        entries: [.preview(id: 4, title: "Blade Runner")], isCollapsible: false),
    ]
    NavigationStack {
        ListTable(sections: sections,
                 context: ListEntryContext(selection: .list(UUID()), isWatchList: false,
                                           watchListIDs: [], listColor: .appAccent),
                 lists: [])
            .listStyle(.plain)
    }
    .modelContainer(previewModelContainer)
    .environment(PersistenceCoordinator(previewModelContainer.mainContext))
    .preferredColorScheme(.dark)
}

#Preview("Watched — grouped by stars") {
    let sections = [
        SectionSnapshot(id: DateComponents(year: 9010), title: "5 Stars",
                        entries: [.preview(id: 1, title: "Masterpiece", dateWatched: .now, userRating: 5)],
                        isCollapsible: false, ratingStars: 5),
        SectionSnapshot(id: DateComponents(year: 9009), title: "4.5 Stars",
                        entries: [.preview(id: 2, title: "Nearly Perfect", dateWatched: .now, userRating: 4.5)],
                        isCollapsible: false, ratingStars: 4.5),
        SectionSnapshot(id: DateComponents(year: 9002), title: "1 Star",
                        entries: [.preview(id: 3, title: "A Misfire", dateWatched: .now, userRating: 1)],
                        isCollapsible: false, ratingStars: 1),
        SectionSnapshot(id: DateComponents(year: 9000), title: "Unrated",
                        entries: [.preview(id: 4, title: "Not Yet Rated", dateWatched: .now)],
                        isCollapsible: false),
    ]
    NavigationStack {
        ListTable(sections: sections,
                 context: ListEntryContext(selection: .watched, isWatchList: false, watchListIDs: [],
                                           listColor: ListDestination.watchedColor),
                 lists: [])
            .listStyle(.plain)
    }
    .modelContainer(previewModelContainer)
    .environment(PersistenceCoordinator(previewModelContainer.mainContext))
    .preferredColorScheme(.dark)
}
