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
    var countsEpisodes = false
    var filterKinds: [CreditKind] = []
    var creditedShow: Show?

    var rowCount: Int { groups.reduce(0) { $0 + $1.rowCount } }
    var isSearchable: Bool { rowCount > 0 }

    var trailingItems: Int {
        1 + (countsEpisodes ? 1 : 0) + (filterKinds.isEmpty ? 0 : 1)
    }
}

/// Where the field sits inside its container, as insets rather than a frame.
private struct FieldPlacement: Equatable {
    var leading: CGFloat
    var trailing: CGFloat
    var top: CGFloat

    init(of slot: CGRect, in container: CGRect) {
        leading = max(0, container.maxX - slot.maxX)
        trailing = max(0, container.maxX - slot.minX + DetailSearchBar.cancelGap)
        top = max(0, slot.minY - container.minY)
    }
}

/// Searches one detail section's list, covering the page it was opened from.
struct DetailSearchScreen: View {
    let request: DetailSearchRequest
    var sourceFrame: CGRect?
    var barSlot: CGRect?
    var trailingItems: Int = 1
    var contentFrame: CGRect = .zero
    let isClosing: Bool
    @Binding var query: String
    var fieldInBar = false
    var focused = false
    var onFieldWidth: (CGFloat) -> Void = { _ in }
    var onLanded: () -> Void = {}
    let onClose: () -> Void

    @State private var hasFlown = false
    @State private var showsResults = false
    @State private var revealsResults = false
    // Latched when search opens: a placement that changes mid-flight moves the field under it.
    @State private var placedAt: CGRect?
    @State private var hasPlaced = false
    @State private var placement: FieldPlacement?
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
            // Once only: popping a pushed screen fires this again, with the page still off-window,
            // where the slot measures off-screen and takes the field with it.
            if !hasPlaced, let slot = trailingSlot {
                hasPlaced = true
                placedAt = slot
            }
            // Rows arrive after the field lands. Building them first spends the flight's frames on
            // layout, and the first half of it never gets drawn.
            withAnimation(DetailSearch.entry) {
                hasFlown = true
            } completion: {
                showsResults = true
            }
        }
    }

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

    // Toolbar items report a placeholder frame near the origin before they are laid out.
    private func inBarRow(_ rect: CGRect) -> Bool {
        rect.minX >= contentFrame.minX && rect.maxX <= contentFrame.maxX + 1
            && rect.midY < contentFrame.minY
    }

    private static let fieldGap: CGFloat = 19

    private var fieldBackdrop: some View {
        Color.clear
            .frame(height: barHeight)
            .background { SectionHeaderGlass() }
            .clipped()
            .ignoresSafeArea(.container, edges: .top)
            .opacity(hasFlown && !isClosing && fieldGlass ? 1 : 0)
            .animation(.easeOut(duration: 0.15), value: fieldGlass)
    }

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
                // Latched, not read live: a push or pop slides the container while the slot stays where it was
                // measured, and a mid-transition size shoves the trailing items off the edge.
                let place = placement ?? FieldPlacement(of: slot, in: container)
                let target = CGRect(x: container.minX + place.leading,
                                    y: container.minY + place.top,
                                    width: max(1, container.width - place.leading - place.trailing),
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
                .padding(.leading, place.leading)
                .padding(.trailing, place.trailing)
                .padding(.top, place.top)
                // Keyed off the container's size, never its origin, so only a real layout change
                // re-measures. A rotation lands here; a transition does not.
                .task(id: [container.width, container.height,
                           slot.minX, slot.maxX, slot.minY]) {
                    placement = FieldPlacement(of: slot, in: container)
                }
                .task(id: target.width) { onFieldWidth(target.width) }
            }
            .ignoresSafeArea(.container, edges: .top)
        } else {
            bar.padding(.horizontal, DetailSearchBar.barMargin)
        }
    }

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
