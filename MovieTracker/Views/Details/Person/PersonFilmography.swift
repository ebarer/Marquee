//
//  PersonFilmography.swift
//  MovieTracker
//

import SwiftUI

/// The person's movie + TV credits grouped into per-year sections (``FilmographyRows``),
/// with upcoming work in a collapsible ``UpcomingSection``.
struct PersonFilmography: View {
    let entries: [FilmographyEntry]
    let lists: [MediaList]
    @Binding var filter: CreditFilter
    /// True while the TV credits are still resolving — a row's year section depends on them,
    /// so the list waits rather than laying out rows it would then have to move.
    var isResolving: Bool = false
    /// Where a year header comes to rest: the bottom edge of the pinned detail header.
    var pinLine: CGFloat = 0
    /// Set to hand the section's search request to the screen, which then owns the control in its
    /// navigation bar. Unset, this header carries it.
    var onSearchRequest: ((DetailSearchRequest?) -> Void)?

    var body: some View {
        if isResolving {
            LazyVStack(spacing: 0) {
                header
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
            }
        } else if !visibleEntries.isEmpty {
            LazyVStack(spacing: 0) {
                header
                if !upcomingEntries.isEmpty {
                    UpcomingSection(entries: upcomingEntries, lists: lists)
                }
                ForEach(releasedByYear, id: \.year) { group in
                    StickySection(space: "scroll", pinLine: pinLine) {
                        SectionHeader(title: String(group.year), color: .appAccent)
                    } content: {
                        FilmographyRows(entries: group.entries, lists: lists)
                    }
                }
            }
            // Declared here so every route into the filter animates alike — a `withAnimation`
            // around the mutation misses, since `@AppStorage` publishes outside it.
            .animation(.easeInOut, value: filter.active)
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Credits")
                .font(.headline)
                .foregroundStyle(.white)
            Spacer(minLength: 8)
            if onSearchRequest == nil {
                DetailSearchButton(request: searchRequest)
            }
            if availableKinds.count > 1 {
                CreditFilterMenu(kinds: availableKinds, filter: $filter) {
                    Image(systemName: "line.3.horizontal.decrease")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(isFiltering ? .black : Color.appAccent)
                        .filterOnBadge(isFiltering, size: SectionHeaderControl.fill)
                        .sectionHeaderControl()
                }
                .buttonStyle(.plain)
            }
        }
        .sectionHeaderInsets()
        .onChange(of: searchSignature, initial: true) { _, _ in
            onSearchRequest?(isResolving ? nil : searchRequest)
        }
    }

    /// The request is rebuilt off this rather than diffed: a filmography runs to hundreds of
    /// entries, which is too much to compare on every layout pass.
    private var searchSignature: [Int] {
        [entries.count, visibleEntries.count, filterKinds.count, isResolving ? 1 : 0]
    }

    private var availableKinds: [CreditKind] { CreditKind.present(in: entries.map(\.ref)) }

    private var isFiltering: Bool { availableKinds.contains(where: filter.hides) }

    private var visibleEntries: [FilmographyEntry] {
        entries.filter { !filter.hides($0.ref.creditKind) }
    }

    /// The kinds the filter offers, which is nothing to choose from below two.
    private var filterKinds: [CreditKind] {
        availableKinds.count > 1 ? availableKinds : []
    }

    private var searchRequest: DetailSearchRequest {
        // Every entry once the filter travels with search, so turning it off there reveals the
        // rest; only the visible ones when there is no filter to turn off.
        let rows = filterKinds.isEmpty ? visibleEntries : entries
        return DetailSearchRequest(prompt: "Search Credits",
                                   groups: [DetailSearchGroup(title: "Credits",
                                                              content: .credits(rows))],
                                   filterKinds: filterKinds)
    }

    private var upcomingEntries: [FilmographyEntry] { FilmographyEntry.upcoming(in: visibleEntries) }

    private var releasedByYear: [(year: Int, entries: [FilmographyEntry])] {
        FilmographyEntry.byYear(in: visibleEntries)
    }
}

#Preview("Filtering") {
    FilmographyPreview(filter: CreditFilter())
}

#Preview("Filter off") {
    FilmographyPreview(filter: CreditFilter(isOn: false))
}

#Preview("Resolving") {
    FilmographyPreview(filter: CreditFilter(), isResolving: true)
}

private struct FilmographyPreview: View {
    @State var filter: CreditFilter
    var isResolving = false

    /// A run spanning three years, so the preview shows the same show under each of them.
    private var entries: [FilmographyEntry] {
        let seasons = Season.previewSeasons
        let credits: [Int: EpisodeCredit] = [
            1001: EpisodeCredit(seasons: [
                .init(season: seasons[0]),
                .init(season: seasons[1]),
                .init(season: seasons[2], episodeNumbers: [3]),
            ]),
        ]
        return FilmographyEntry.entries(for: Person.preview.allCredits, episodeCredits: credits)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 0) {
                    PersonFilmography(entries: entries, lists: [], filter: $filter,
                                      isResolving: isResolving)
                }
            }
            .coordinateSpace(name: "scroll")
            .detailDestinations()
            .detailSearchHost()
        }
        .background(Color.appBackground)
        .modelContainer(previewModelContainer)
        .environment(PersistenceCoordinator(previewModelContainer.mainContext))
        .preferredColorScheme(.dark)
    }
}
