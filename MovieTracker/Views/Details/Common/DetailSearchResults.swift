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

    @Query(sort: [SortDescriptor(\MediaList.sortOrder), SortDescriptor(\MediaList.createdAt)])
    private var lists: [MediaList]

    var body: some View {
        ScrollView {
            // One flat ForEach: a lazy stack only builds rows on demand when they are its own
            // ForEach's elements. Nested inside another view's body, all of them are built at once.
            LazyVStack(spacing: 0) {
                ForEach(rows) { row in
                    view(for: row)
                }
            }
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        // Otherwise the bar shows its glass edge effect as the results scroll under it.
        .scrollEdgeEffectHidden(true, for: .top)
    }

    @ViewBuilder
    private func view(for row: ResultRow) -> some View {
        switch row {
        case .group(let title):
            SectionHeader(title: title)
        case .year(let title):
            SectionHeader(title: title, color: .appAccent)
                .background(Color.appBackground)
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

    private var rows: [ResultRow] {
        let matches = request.groups.compactMap { $0.filtered(by: query) }
        guard !matches.isEmpty else { return [.noMatches] }

        var rows: [ResultRow] = []
        for group in matches {
            if request.groups.count > 1 { rows.append(.group(group.title)) }
            switch group.content {
            case .people(let people):
                rows.append(contentsOf: people.enumerated().map { index, person in
                    .person(person, separated: index < people.count - 1)
                })
            case .credits(let entries):
                rows.append(contentsOf: creditRows(entries))
            }
        }
        return rows
    }

    private func creditRows(_ entries: [FilmographyEntry]) -> [ResultRow] {
        let upcoming = FilmographyEntry.upcoming(in: entries)
        let byYear = FilmographyEntry.byYear(in: entries)
        if upcoming.isEmpty, byYear.isEmpty {
            // No year section would show these.
            return Self.credits(entries)
        }
        var rows: [ResultRow] = []
        if !upcoming.isEmpty {
            rows.append(.year("Upcoming"))
            rows.append(contentsOf: Self.credits(upcoming))
        }
        for group in byYear {
            rows.append(.year(String(group.year)))
            rows.append(contentsOf: Self.credits(group.entries))
        }
        return rows
    }

    private static func credits(_ entries: [FilmographyEntry]) -> [ResultRow] {
        entries.enumerated().map { index, entry in
            .credit(entry, separated: index < entries.count - 1)
        }
    }
}

private enum ResultRow: Identifiable {
    case group(String)
    case year(String)
    case person(Person, separated: Bool)
    case credit(FilmographyEntry, separated: Bool)
    case noMatches

    var id: String {
        switch self {
        case .group(let title): return "group-\(title)"
        case .year(let title): return "year-\(title)"
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

private struct DetailSearchResultsPreview: View {
    let request: DetailSearchRequest
    var query: String = ""

    var body: some View {
        NavigationStack {
            DetailSearchResults(request: request, query: query)
                .detailDestinations()
        }
        .background(Color.appBackground)
        .modelContainer(previewModelContainer)
        .environment(PersistenceCoordinator(previewModelContainer.mainContext))
        .preferredColorScheme(.dark)
    }
}
