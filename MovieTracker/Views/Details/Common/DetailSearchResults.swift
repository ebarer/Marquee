//
//  DetailSearchResults.swift
//  MovieTracker
//

import SwiftUI
import SwiftData

/// The rows a detail search shows. Its own view so that moving the field doesn't rebuild them.
struct DetailSearchResults: View {
    let request: DetailSearchRequest
    let query: String
    var barHeight: CGFloat = 0
    var onFieldGlassChange: (Bool) -> Void = { _ in }

    @Query(sort: [SortDescriptor(\MediaList.sortOrder), SortDescriptor(\MediaList.createdAt)])
    private var lists: [MediaList]

    @State private var pinLine: CGFloat = 0
    @State private var pinnedSections: Set<String> = []
    /// Matches system behavior: glass only becomes visible once content scrolls under the header.
    @State private var scrolled = false

    private static let space = "detailSearchResults"

    var body: some View {
        ScrollView {
            // Rows stay elements of the stack's own ForEach: a lazy stack only builds them on
            // demand there. Nested inside another view's body, all of them are built at once.
            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                ForEach(sections) { section in
                    Section {
                        ForEach(section.rows) { row in
                            view(for: row)
                        }
                    } header: {
                        header(for: section)
                    }
                }
            }
            .padding(.bottom, 24)
        }
        // A bar inset rather than padding, so content scrolls under the field.
        .safeAreaBar(edge: .top, spacing: 0) {
            Color.clear.frame(height: barHeight)
        }
        // The system effect blurs pinned headers along with the rows, so the glass is drawn here.
        .scrollEdgeEffectHidden(true, for: .top)
        .coordinateSpace(.named(Self.space))
        .onScrollGeometryChange(for: CGFloat.self) { geometry in
            geometry.contentInsets.top
        } action: { _, inset in
            pinLine = inset
        }
        .onScrollGeometryChange(for: Bool.self) { geometry in
            geometry.contentOffset.y + geometry.contentInsets.top > 1
        } action: { _, isScrolled in
            scrolled = isScrolled
        }
        .onChange(of: fieldNeedsGlass, initial: true) { _, needs in
            onFieldGlassChange(needs)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var fieldNeedsGlass: Bool { scrolled && pinnedSections.isEmpty }

    @ViewBuilder
    private func header(for section: ResultSection) -> some View {
        if let title = section.title {
            ResultSectionHeader(title: title, color: section.titleColor, space: Self.space,
                                pinLine: pinLine, scrolled: scrolled) { pinned in
                if pinned {
                    pinnedSections.insert(section.id)
                } else {
                    pinnedSections.remove(section.id)
                }
            }
        }
    }

    @ViewBuilder
    private func view(for row: ResultRow) -> some View {
        switch row {
        case .person(let person, let separated):
            CastPersonRow(person: person)
            if separated { CastRowSeparator() }
        case .credit(let entry, let separated):
            FilmographyRow(entry: entry, lists: lists)
            if separated { FilmographyRowSeparator() }
        case .noMatches:
            DetailSearchNoResults(query: query)
        }
    }

    private var sections: [ResultSection] {
        let matches = request.groups.compactMap { $0.filtered(by: query) }
        guard !matches.isEmpty else {
            return [ResultSection(id: "no-matches", rows: [.noMatches])]
        }

        var sections: [ResultSection] = []
        for group in matches {
            // With one group its title duplicates the field's prompt, so no header is shown.
            let title = request.groups.count > 1 ? group.title : nil
            switch group.content {
            case .people(let people):
                let rows = people.enumerated().map { index, person in
                    ResultRow.person(person, separated: index < people.count - 1)
                }
                sections.append(ResultSection(id: "group-\(group.title)", title: title, rows: rows))
            case .credits(let entries):
                // The years below head their own sections, so the group title takes a section too.
                if let title {
                    sections.append(ResultSection(id: "group-\(group.title)", title: title, rows: []))
                }
                sections.append(contentsOf: creditSections(entries, in: group.title))
            }
        }
        return sections
    }

    private func creditSections(_ entries: [FilmographyEntry], in groupTitle: String) -> [ResultSection] {
        let upcoming = FilmographyEntry.upcoming(in: entries)
        let byYear = FilmographyEntry.byYear(in: entries)
        if upcoming.isEmpty, byYear.isEmpty {
            // No year section would show these.
            return [ResultSection(id: "credits-\(groupTitle)", rows: Self.credits(entries))]
        }
        var sections: [ResultSection] = []
        if !upcoming.isEmpty {
            sections.append(ResultSection(id: "year-upcoming", title: "Upcoming",
                                          titleColor: .appAccent, rows: Self.credits(upcoming)))
        }
        for group in byYear {
            sections.append(ResultSection(id: "year-\(group.year)", title: String(group.year),
                                          titleColor: .appAccent, rows: Self.credits(group.entries)))
        }
        return sections
    }

    private static func credits(_ entries: [FilmographyEntry]) -> [ResultRow] {
        entries.enumerated().map { index, entry in
            .credit(entry, separated: index < entries.count - 1)
        }
    }
}

/// The glass shared by the field's backdrop and pinned headers.
struct DetailSearchGlass: View {
    /// Puts the glass's own bright edge outside the view's bounds, for the caller to clip.
    private static let bleed: CGFloat = 24

    var body: some View {
        Color.clear
            .glassEffect(.regular.tint(Color.appBackground.opacity(0.55)), in: .rect)
            .padding(.vertical, -Self.bleed)
    }
}

/// Pinned, its glass extends to the screen's top edge: two adjacent glass views leave a boundary.
private struct ResultSectionHeader: View {
    let title: String
    let color: Color
    let space: String
    let pinLine: CGFloat
    let scrolled: Bool
    let onPinnedChange: (Bool) -> Void

    @State private var pinned = false
    @State private var height: CGFloat = 0

    private var wearsGlass: Bool { pinned && scrolled }

    var body: some View {
        SectionHeader(title: title, color: color)
            .background(alignment: .bottom) {
                if wearsGlass {
                    DetailSearchGlass().frame(height: pinLine + height)
                } else {
                    Color.appBackground
                }
            }
            .clipShape(HeaderSlabClip(extraTop: wearsGlass ? pinLine : 0))
            .animation(.easeOut(duration: 0.15), value: wearsGlass)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height = $0 }
            .onGeometryChange(for: Bool.self) { proxy in
                proxy.frame(in: .named(space)).minY <= pinLine + 0.5
            } action: { isPinned in
                pinned = isPinned
                onPinnedChange(isPinned)
            }
    }
}

/// The view's bounds extended upward, so a pinned header's glass can reach the screen's top edge.
private struct HeaderSlabClip: Shape {
    let extraTop: CGFloat

    func path(in rect: CGRect) -> Path {
        Path(CGRect(x: rect.minX, y: rect.minY - extraTop,
                    width: rect.width, height: rect.height + extraTop))
    }
}

/// One header and its rows. A section with no title contains rows only.
private struct ResultSection: Identifiable {
    let id: String
    var title: String? = nil
    var titleColor: Color = .white
    let rows: [ResultRow]
}

private enum ResultRow: Identifiable {
    case person(Person, separated: Bool)
    case credit(FilmographyEntry, separated: Bool)
    case noMatches

    var id: String {
        switch self {
        case .person(let person, _): return "person-\(person.id)"
        case .credit(let entry, _): return "credit-\(entry.id)"
        case .noMatches: return "no-matches"
        }
    }
}

#Preview("People") {
    DetailSearchResultsPreview(request: .previewCast)
}

#Preview("Credits") {
    DetailSearchResultsPreview(request: .previewCredits)
}

#Preview("No matches") {
    DetailSearchResultsPreview(request: .previewCast, query: "qqq")
}

#Preview("Pinned header") {
    DetailSearchResultsPreview(request: .previewCredits, scrolled: true)
}

private struct DetailSearchResultsPreview: View {
    let request: DetailSearchRequest
    var query: String = ""
    var scrolled = false

    var body: some View {
        NavigationStack {
            DetailSearchResults(request: request, query: query)
                .defaultScrollAnchor(scrolled ? .bottom : .top)
                .detailDestinations()
        }
        .background(Color.appBackground)
        .modelContainer(previewModelContainer)
        .environment(PersistenceCoordinator(previewModelContainer.mainContext))
        .preferredColorScheme(.dark)
    }
}
