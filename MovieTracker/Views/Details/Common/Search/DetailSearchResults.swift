//
//  DetailSearchResults.swift
//  MovieTracker
//

import SwiftUI
import SwiftData

/// The rows a detail search shows. Its own view so moving the field doesn't rebuild them.
struct DetailSearchResults: View {
    let request: DetailSearchRequest
    let query: String
    var barHeight: CGFloat = 0
    var onFieldGlassChange: (Bool) -> Void = { _ in }
    var onTopChange: (CGFloat) -> Void = { _ in }

    @Query(sort: [SortDescriptor(\MediaList.sortOrder), SortDescriptor(\MediaList.createdAt)])
    private var lists: [MediaList]
    @AppStorage("castEpisodeCounts") private var showsEpisodeCounts = true
    @AppStorage("personCreditFilter") private var creditFilter = CreditFilter()

    @State private var pinLine: CGFloat = 0
    @State private var pinnedSections: Set<String> = []
    // Matches system behavior: glass only becomes visible once content scrolls under the header.
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
            // `@AppStorage` publishes outside a `withAnimation`, so the rows animate their own
            // change of height as the counts come and go.
            .animation(.easeInOut, value: showsEpisodeCounts)
            .animation(.easeInOut, value: creditFilter.active)
        }
        // A bar inset rather than padding, so content scrolls under the field.
        .safeAreaBar(edge: .top, spacing: 0) {
            Color.clear.frame(height: barHeight)
        }
        // Measured from inside, where the top inset this view ignores has already been escaped.
        .background {
            Color.clear
                .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).minY } action: {
                    onTopChange($0)
                }
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
            SectionHeader(title: title, color: section.titleColor)
                .stickyHeaderBackground(space: Self.space, pinLine: pinLine, scrolled: scrolled,
                                        glassTop: pinLine) { pinned in
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
            CastPersonRow(person: person,
                          showsEpisodeCount: request.countsEpisodes && showsEpisodeCounts,
                          episodes: episodes(for: person))
            if separated { CastRowSeparator() }
        case .credit(let entry, let separated):
            FilmographyRow(entry: entry, lists: lists)
            if separated { FilmographyRowSeparator() }
        case .noMatches:
            DetailSearchNoResults(query: query)
        }
    }

    // Nil for a crew member whose roster carries no credit ids, leaving nothing to resolve.
    private func episodes(for person: Person) -> ShowEpisodeCredits? {
        guard let show = request.creditedShow else { return nil }
        guard person.type == .Cast || !(person.creditIDs ?? []).isEmpty else { return nil }
        return ShowEpisodeCredits(person: person, in: show)
    }

    private var visibleGroups: [DetailSearchGroup] {
        guard !request.filterKinds.isEmpty else { return request.groups }
        return request.groups.compactMap { group in
            guard case .credits(let entries) = group.content else { return group }
            let kept = entries.filter { !creditFilter.hides($0.ref.creditKind) }
            return kept.isEmpty ? nil : DetailSearchGroup(title: group.title,
                                                          content: .credits(kept))
        }
    }

    private var sections: [ResultSection] {
        let matches = visibleGroups.compactMap { $0.filtered(by: query) }
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
