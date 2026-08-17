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
    var navBarBottom: CGFloat = 0
    /// The request while this header is scrolled out of sight, so the page can carry its
    /// controls in the bar; nil while the header is on screen.
    var onHeaderHiddenChange: (DetailSearchRequest?) -> Void = { _ in }

    var body: some View {
        if isResolving {
            LazyVStack(spacing: 0) {
                header
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
            }
        } else if !visibleEntries.isEmpty {
            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                header
                if !upcomingEntries.isEmpty {
                    UpcomingSection(entries: upcomingEntries, lists: lists)
                }
                ForEach(releasedByYear, id: \.year) { group in
                    Section {
                        FilmographyRows(entries: group.entries, lists: lists)
                    } header: {
                        SectionHeader(title: String(group.year), color: .appAccent)
                            .background(Color.appBackground)
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
            DetailSearchButton(request: searchRequest)
            if availableKinds.count > 1 {
                CreditFilterMenu(kinds: availableKinds, filter: $filter) {
                    Image(systemName: isFiltering
                          ? "line.3.horizontal.decrease.circle.fill"
                          : "line.3.horizontal.decrease")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.appAccent)
                        .sectionHeaderControl()
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 4)
        .onGeometryChange(for: Bool.self) { proxy in
            proxy.frame(in: .global).maxY <= navBarBottom
        } action: { hidden in
            onHeaderHiddenChange(hidden ? searchRequest : nil)
        }
    }

    private var availableKinds: [CreditKind] { CreditKind.present(in: entries.map(\.ref)) }

    private var isFiltering: Bool { availableKinds.contains(where: filter.hides) }

    private var visibleEntries: [FilmographyEntry] {
        entries.filter { !filter.hides($0.ref.creditKind) }
    }

    private var searchRequest: DetailSearchRequest {
        DetailSearchRequest(prompt: "Search Credits",
                            groups: [DetailSearchGroup(title: "Credits",
                                                       content: .credits(visibleEntries))])
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
            .detailDestinations()
            .detailSearchHost()
        }
        .background(Color.appBackground)
        .modelContainer(previewModelContainer)
        .environment(PersistenceCoordinator(previewModelContainer.mainContext))
        .preferredColorScheme(.dark)
    }
}
