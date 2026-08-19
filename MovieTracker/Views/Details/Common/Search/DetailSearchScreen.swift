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

    var peopleIDs: [Int] {
        guard case .people(let people) = content else { return [] }
        return people.map(\.id)
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
    /// TV rosters carry an episode count, so only they offer the control that hides it.
    var countsEpisodes = false
    /// The credit kinds this list has. Set, the credits filter travels into search and the rows
    /// carry every kind, so turning it off there reveals the rest.
    var filterKinds: [CreditKind] = []
    /// The show these credits belong to. A hit then opens the episodes they are in rather than
    /// their own page, which is what someone hunting a guest spot is after.
    var creditedShow: Show?

    var rowCount: Int { groups.reduce(0) { $0 + $1.rowCount } }
    var isSearchable: Bool { rowCount > 0 }

    /// What search puts in the bar's trailing group: its own close button, plus the controls the
    /// request brings with it.
    var trailingItems: Int {
        1 + (countsEpisodes ? 1 : 0) + (filterKinds.isEmpty ? 0 : 1)
    }
}

/// Searches one detail section's list, covering the page it was opened from.
struct DetailSearchScreen: View {
    let request: DetailSearchRequest
    /// The control that opened search, in global coordinates. The field flies out of it.
    var sourceFrame: CGRect?
    var barSlot: CGRect?
    /// How many items search puts in the trailing group, which is what the field stops short of.
    var trailingItems: Int = 1
    var contentFrame: CGRect = .zero
    let isClosing: Bool
    @Binding var query: String
    /// True once the interactive field has taken over in the navigation bar.
    var fieldInBar = false
    var focused = false
    /// Reports where the field comes to rest, which is the width the bar's copy is given.
    var onFieldFrame: (CGRect) -> Void = { _ in }
    var onLanded: () -> Void = {}
    let onClose: () -> Void

    @State private var hasFlown = false
    @State private var showsResults = false
    @State private var revealsResults = false
    // Latched when search opens: a placement that changes mid-flight moves the field under it.
    @State private var placedAt: CGRect?
    /// Where the results' own top edge sits, measured the way they are laid out.
    @State private var resultsTop: CGFloat = 0
    @State private var fieldGlass = false

    @Environment(\.horizontalSizeClass) private var sizeClass

    private var trimmedQuery: String { query.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        ZStack(alignment: .top) {
            // Fades with the field, so the page recedes as it arrives. Only the colour fades: the
            // rows would have to be drawn over the page for the whole animation.
            Color.appBackground
                .ignoresSafeArea()
                .opacity(hasFlown && !isClosing ? 1 : 0)

            if showsResults, !isClosing {
                DetailSearchResults(request: request, query: trimmedQuery, barHeight: barHeight,
                                    onFieldGlassChange: { fieldGlass = $0 },
                                    onTopChange: { resultsTop = $0 })
                    .ignoresSafeArea(.container, edges: .top)
                    .opacity(revealsResults ? 1 : 0)
                    // Built first, faded on the following pass: building them costs a frame, and
                    // starting the fade in the same one means it begins part-way through.
                    .task {
                        withAnimation(DetailSearch.reveal) {
                            revealsResults = true
                        } completion: {
                            onLanded()
                        }
                    }
            }

            fieldBackdrop
            field
        }
        .onAppear {
            placedAt = trailingSlot
            // Rows arrive after the field lands. Building them first spends the flight's frames on
            // layout, and the first half of it never gets drawn.
            withAnimation(DetailSearch.entry) {
                hasFlown = true
            } completion: {
                showsResults = true
            }
        }
    }

    /// The glass circles of search's trailing items, as one rect.
    private var trailingSlot: CGRect? {
        guard contentFrame != .zero else { return nil }
        if let barSlot, inBarRow(barSlot), barSlot.midX > contentFrame.midX {
            return barSlot
        }
        let inset = DetailSearchBar.barItemInset(compact: sizeClass == .compact)
        let width = DetailSearchBar.rowHeight * CGFloat(trailingItems)
            + DetailSearchBar.barItemGap * CGFloat(trailingItems - 1)
        return CGRect(x: contentFrame.maxX - inset - width,
                      y: contentFrame.minY - DetailSearchBar.barHeight,
                      width: width, height: DetailSearchBar.rowHeight)
    }

    /// Toolbar items report a placeholder frame near the origin before they are laid out.
    private func inBarRow(_ rect: CGRect) -> Bool {
        rect.minX >= contentFrame.minX && rect.maxX <= contentFrame.maxX + 1
            && rect.midY < contentFrame.minY
    }

    /// The gap between the field's bottom edge and the first row.
    private static let fieldGap: CGFloat = 19

    /// Glass behind the field, for lists with no section header to draw it.
    private var fieldBackdrop: some View {
        Color.clear
            .frame(height: barHeight)
            .background { SectionHeaderGlass() }
            .clipped()
            .ignoresSafeArea(.container, edges: .top)
            .opacity(hasFlown && !isClosing && fieldGlass ? 1 : 0)
            .animation(.easeOut(duration: 0.15), value: fieldGlass)
    }

    /// The rows start below the field, wherever the field was placed. With no content region
    /// measured it sits in flow at the top instead.
    private var barHeight: CGFloat {
        guard let slot = placedAt ?? trailingSlot else {
            return DetailSearchBar.capsuleHeight + Self.fieldGap
        }
        let fieldBottom = slot.minY + DetailSearchBar.capsuleHeight
        return max(0, fieldBottom - resultsTop + Self.fieldGap)
    }

    // Not stacked above the results, whose size would then depend on this GeometryReader: the
    // keyboard resizes it, and every row would be rebuilt as the keyboard animated.
    @ViewBuilder
    private var field: some View {
        if let slot = placedAt ?? trailingSlot {
            // The leading margin mirrors the trailing items' own inset, so the field is concentric
            // with the corner it sits in.
            GeometryReader { proxy in
                let container = proxy.frame(in: .global)
                let leading = max(0, container.maxX - slot.maxX)
                let trailing = max(0, container.maxX - slot.minX + DetailSearchBar.cancelGap)
                let top = max(0, slot.minY - container.minY)
                let target = CGRect(x: container.minX + leading, y: container.minY + top,
                                    width: max(1, container.width - leading - trailing),
                                    height: DetailSearchBar.capsuleHeight)
                Group {
                    // Unmounted once the bar has its own copy, rather than merely hidden: a
                    // representable's field stays in the accessibility tree either way.
                    if !fieldInBar {
                        bar.flying(from: sourceFrame, to: target,
                                   collapsed: !hasFlown || isClosing)
                    }
                }
                .frame(height: DetailSearchBar.capsuleHeight)
                .padding(.leading, leading)
                .padding(.trailing, trailing)
                .padding(.top, top)
                .task(id: target) { onFieldFrame(target) }
            }
            .ignoresSafeArea(.container, edges: .top)
        } else {
            bar.padding(.horizontal, DetailSearchBar.barMargin)
        }
    }

    /// The flying copy. It only takes focus where there is no bar to hand the field to.
    private var bar: some View {
        DetailSearchBar(text: $query, prompt: request.prompt, tint: request.tint,
                        focused: focused, showsPrompt: hasFlown && !isClosing)
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

#Preview("Scrolled") {
    DetailSearchPreview(request: .previewCast, scrolled: true)
}

private struct DetailSearchPreview: View {
    let request: DetailSearchRequest
    var query: String = ""
    var scrolled = false

    @State private var typed = ""

    var body: some View {
        NavigationStack {
            DetailSearchScreen(request: request, isClosing: false, query: $typed, onClose: {})
                .onAppear { typed = query }
                .defaultScrollAnchor(scrolled ? .bottom : .top)
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
                                                              content: .credits(entries))],
                                   filterKinds: CreditKind.present(in: entries.map(\.ref)))
    }
}
