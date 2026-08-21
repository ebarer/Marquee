//
//  PersonFilmography.swift
//  MovieTracker
//

import SwiftUI

/// The person's credits grouped into per-year sections, with upcoming work in a collapsible section.
struct PersonFilmography: View {
    let entries: [FilmographyEntry]
    let lists: [MediaList]
    @Binding var filter: CreditFilter
    var isResolving: Bool = false
    var pinLine: CGFloat = 0
    var isFilterPinned: Bool = false
    var onSearchRequest: ((DetailSearchRequest?) -> Void)?
    var onFilterPinned: ((Bool) -> Void)?

    var body: some View {
        let credits = Credits(entries: entries, filter: filter)
        if isResolving {
            LazyVStack(spacing: 0) {
                header(credits)
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
            }
        } else if !credits.visible.isEmpty {
            LazyVStack(spacing: 0) {
                header(credits)
                if !credits.upcoming.isEmpty {
                    UpcomingSection(entries: credits.upcoming, lists: lists)
                }
                ForEach(credits.byYear, id: \.year) { group in
                    StickySection(space: "scroll", pinLine: pinLine) {
                        SectionHeader(title: String(group.year), color: .appAccent)
                    } content: {
                        FilmographyRows(entries: group.entries, lists: lists)
                    }
                }
            }
            // Declared here so every route into the filter animates alike. A `withAnimation` around the
            // mutation misses, since `@AppStorage` publishes outside it.
            .animation(.easeInOut, value: filter.active)
        }
    }

    private func header(_ credits: Credits) -> some View {
        HStack {
            Text("Credits")
                .font(.headline)
                .foregroundStyle(.white)

            Spacer(minLength: 8)

            if onSearchRequest == nil {
                DetailSearchButton(request: searchRequest(credits))
            }

            if !credits.filterKinds.isEmpty {
                CreditFilterMenu(kinds: credits.filterKinds, filter: $filter) {
                    SectionHeaderFilterGlyph(isOn: credits.isFiltering)
                }
                .buttonStyle(.plain)
                // Hidden rather than removed: the pinned copy draws at the same position, and the
                // row keeps its layout.
                .opacity(isFilterPinned ? 0 : 1)
                .accessibilityHidden(isFilterPinned)
            }
        }
        .sectionHeaderInsets()
        .onChange(of: signature(credits), initial: true) { _, _ in
            onSearchRequest?(isResolving ? nil : searchRequest(credits))
        }
        // Reports the crossing, not the offset: the value only changes as the header meets the line.
        .onGeometryChange(for: Bool.self) { proxy in
            pinLine > 0 && proxy.frame(in: .named("scroll")).minY <= pinLine
        } action: { onFilterPinned?($0) }
    }

    // The request is rebuilt off this rather than diffed: a filmography runs to hundreds of entries.
    private func signature(_ credits: Credits) -> [Int] {
        [entries.count, credits.visible.count, credits.filterKinds.count, isResolving ? 1 : 0]
    }

    private func searchRequest(_ credits: Credits) -> DetailSearchRequest {
        // Every entry once the filter travels with search, so turning it off there reveals the
        // rest; only the visible ones when there is no filter to turn off.
        let rows = credits.filterKinds.isEmpty ? credits.visible : entries
        return DetailSearchRequest(prompt: "Search Credits",
                                   groups: [DetailSearchGroup(title: "Credits",
                                                              content: .credits(rows))],
                                   filterKinds: credits.filterKinds)
    }
}

/// One sweep of the credits per body pass. Read as separate computed properties, the same scans
/// ran a dozen times over hundreds of entries and cost more than a frame.
private struct Credits {
    let availableKinds: [CreditKind]
    let resolved: CreditFilter
    let visible: [FilmographyEntry]
    let upcoming: [FilmographyEntry]
    let byYear: [(year: Int, entries: [FilmographyEntry])]

    init(entries: [FilmographyEntry], filter: CreditFilter) {
        let kinds = CreditKind.present(in: entries.map(\.ref))
        let resolvedFilter = filter.resolved(for: kinds)
        let shown = entries.filter { !resolvedFilter.hides($0.ref.creditKind) }
        availableKinds = kinds
        resolved = resolvedFilter
        visible = shown
        upcoming = FilmographyEntry.upcoming(in: shown)
        byYear = FilmographyEntry.byYear(in: shown)
    }

    var isFiltering: Bool { availableKinds.contains(where: resolved.hides) }

    var filterKinds: [CreditKind] { availableKinds.count > 1 ? availableKinds : [] }
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
