//
//  DetailSearchScreen.swift
//  MovieTracker
//

import SwiftUI
import SwiftData

/// One titled group of a detail search.
struct DetailSearchGroup: Hashable, Identifiable {
    let title: String
    let content: Content

    var id: String { title }

    enum Content: Hashable {
        case people([Person])
        case credits([FilmographyEntry])
    }

    var rowCount: Int {
        switch content {
        case .people(let people): return people.count
        case .credits(let entries): return entries.count
        }
    }

    func filtered(by query: String) -> DetailSearchGroup? {
        guard !query.isEmpty else { return self }
        switch content {
        case .people(let people):
            let matches = people.filter { $0.matches(query: query) }
            return matches.isEmpty ? nil : DetailSearchGroup(title: title, content: .people(matches))
        case .credits(let entries):
            let matches = entries.filter { $0.matches(query: query) }
            return matches.isEmpty ? nil : DetailSearchGroup(title: title, content: .credits(matches))
        }
    }
}

/// What a section hands over when its search button is tapped.
struct DetailSearchRequest: Hashable {
    let prompt: String
    let groups: [DetailSearchGroup]
    var tint: Color = .appAccent

    var rowCount: Int { groups.reduce(0) { $0 + $1.rowCount } }
    var isSearchable: Bool { rowCount >= DetailSearch.minimumRows }
}

/// Searches one detail section's list, covering the page it was opened from.
struct DetailSearchScreen: View {
    let request: DetailSearchRequest
    let namespace: Namespace.ID
    var cancelFrame: CGRect?
    let isClosing: Bool
    let onClose: () -> Void

    @Query(sort: [SortDescriptor(\MediaList.sortOrder), SortDescriptor(\MediaList.createdAt)])
    private var lists: [MediaList]

    @State private var query: String

    init(request: DetailSearchRequest, namespace: Namespace.ID, cancelFrame: CGRect? = nil,
         isClosing: Bool = false, query: String = "", onClose: @escaping () -> Void) {
        self.request = request
        self.namespace = namespace
        self.cancelFrame = cancelFrame
        self.isClosing = isClosing
        self.onClose = onClose
        _query = State(initialValue: query)
    }

    private var trimmedQuery: String { query.trimmingCharacters(in: .whitespaces) }

    private var matches: [DetailSearchGroup] {
        request.groups.compactMap { $0.filtered(by: trimmedQuery) }
    }

    var body: some View {
        ZStack {
            // Opaque immediately. A background that fades in lets the page show through the
            // results, doubling every row.
            Color.appBackground
                .ignoresSafeArea()
                .transition(.identity)

            placedStack
                .transition(.opacity)
        }
    }

    @ViewBuilder
    private var placedStack: some View {
        if let cancelFrame {
            // Measured from the button's centre out: the frame reported is its glyph's, inside
            // a glass circle the bar draws several points wider on every side.
            GeometryReader { proxy in
                let container = proxy.frame(in: .global)
                let radius = DetailSearchBar.rowHeight / 2
                stack(leading: max(0, container.maxX - cancelFrame.midX - radius),
                      trailing: max(0, container.maxX - cancelFrame.midX + radius
                                     + DetailSearchBar.cancelGap))
                    .padding(.top, max(0, cancelFrame.midY - container.minY - radius))
            }
            .ignoresSafeArea(.container, edges: .top)
        } else {
            stack(leading: 16, trailing: 16)
        }
    }

    private func stack(leading: CGFloat, trailing: CGFloat) -> some View {
        VStack(spacing: 0) {
            searchBar(leading: leading, trailing: trailing)
                // The field flies in across the results; without this it passes behind them.
                .zIndex(1)
            results
        }
    }

    private func searchBar(leading: CGFloat, trailing: CGFloat) -> some View {
        DetailSearchBar(text: $query, prompt: request.prompt,
                        tint: request.tint, autofocus: true)
            // The field leads on the way in and follows the button out, so the return trip
            // happens over the page rather than under its header.
            .matchedGeometryEffect(id: DetailSearch.morphID, in: namespace, isSource: !isClosing)
            .padding(.leading, leading)
            .padding(.trailing, trailing)
            .padding(.bottom, 9)
    }

    private var results: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                if matches.isEmpty {
                    DetailSearchNoResults(query: trimmedQuery)
                } else {
                    ForEach(matches) { group in
                        if request.groups.count > 1 {
                            SectionHeader(title: group.title)
                        }
                        rows(for: group)
                    }
                }
            }
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        // Otherwise the bar shows its glass edge effect as the results scroll under it.
        .scrollEdgeEffectHidden(true, for: .top)
    }

    @ViewBuilder
    private func rows(for group: DetailSearchGroup) -> some View {
        switch group.content {
        case .people(let people):
            CastPersonList(people: people)
        case .credits(let entries):
            creditSections(entries)
        }
    }

    @ViewBuilder
    private func creditSections(_ entries: [FilmographyEntry]) -> some View {
        let upcoming = FilmographyEntry.upcoming(in: entries)
        let byYear = FilmographyEntry.byYear(in: entries)
        if upcoming.isEmpty, byYear.isEmpty {
            // No year section would show these.
            FilmographyRows(entries: entries, lists: lists)
        } else {
            if !upcoming.isEmpty {
                Section {
                    FilmographyRows(entries: upcoming, lists: lists)
                } header: {
                    yearHeader("Upcoming")
                }
            }
            ForEach(byYear, id: \.year) { group in
                Section {
                    FilmographyRows(entries: group.entries, lists: lists)
                } header: {
                    yearHeader(String(group.year))
                }
            }
        }
    }

    private func yearHeader(_ title: String) -> some View {
        SectionHeader(title: title, color: .appAccent)
            .background(Color.appBackground)
    }
}

#Preview("People") {
    DetailSearchPreview(request: .previewCast)
}

#Preview("People, matches") {
    DetailSearchPreview(request: .previewCast, query: "an")
}

#Preview("Credits") {
    DetailSearchPreview(request: .previewCredits)
}

#Preview("No matches") {
    DetailSearchPreview(request: .previewCast, query: "qqq")
}

private struct DetailSearchPreview: View {
    let request: DetailSearchRequest
    var query: String = ""

    @Namespace private var namespace

    var body: some View {
        NavigationStack {
            DetailSearchScreen(request: request, namespace: namespace,
                               query: query, onClose: {})
                .detailDestinations()
                // No host here, so no cancel button to measure: the field sits below the bar
                // rather than in it. This previews the row, not its placement.
                .navigationBarBackButtonHidden()
                .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
        }
        .modelContainer(previewModelContainer)
        .environment(PersistenceCoordinator(previewModelContainer.mainContext))
        .preferredColorScheme(.dark)
    }
}

extension DetailSearchRequest {
    static var previewCast: DetailSearchRequest {
        let team = Person.previewTeam
        return DetailSearchRequest(
            prompt: "Search Cast & Crew",
            groups: [
                DetailSearchGroup(title: "Director",
                                  content: .people(team.filter { $0.role == "Director" })),
                DetailSearchGroup(title: "Cast",
                                  content: .people(team.filter { $0.type == .Cast })),
                DetailSearchGroup(title: "Crew",
                                  content: .people(team.filter {
                                      $0.type == .Crew && $0.role != "Director"
                                  })),
            ]
        )
    }

    static var previewCredits: DetailSearchRequest {
        let entries = FilmographyEntry.entries(for: Person.preview.allCredits, episodeCredits: [:])
        return DetailSearchRequest(prompt: "Search Credits",
                                   groups: [DetailSearchGroup(title: "Credits",
                                                              content: .credits(entries))])
    }
}
