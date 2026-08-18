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
    /// The control that opened search, in global coordinates. The field flies out of it.
    var sourceFrame: CGRect?
    var barSlot: CGRect?
    var contentFrame: CGRect = .zero
    let isClosing: Bool
    let onClose: () -> Void

    @State private var query: String
    @State private var hasFlown = false
    @State private var showsResults = false
    @State private var revealsResults = false
    @State private var acceptsTyping = false
    // Latched when search opens: a placement that changes mid-flight moves the field under it.
    @State private var placedAt: CGPoint?
    @State private var safeTop: CGFloat = 0
    @State private var fieldGlass = false

    @Environment(\.horizontalSizeClass) private var sizeClass

    init(request: DetailSearchRequest, sourceFrame: CGRect? = nil, barSlot: CGRect? = nil,
         contentFrame: CGRect = .zero, isClosing: Bool = false,
         query: String = "", onClose: @escaping () -> Void) {
        self.request = request
        self.sourceFrame = sourceFrame
        self.barSlot = barSlot
        self.contentFrame = contentFrame
        self.isClosing = isClosing
        self.onClose = onClose
        _query = State(initialValue: query)
    }

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
                                    onFieldGlassChange: { fieldGlass = $0 })
                    .ignoresSafeArea(.container, edges: .top)
                    .opacity(revealsResults ? 1 : 0)
                    // Built first, faded on the following pass: building them costs a frame, and
                    // starting the fade in the same one means it begins part-way through.
                    .task {
                        withAnimation(DetailSearch.reveal) {
                            revealsResults = true
                        } completion: {
                            acceptsTyping = true
                        }
                    }
            }

            fieldBackdrop
            field
        }
        // The screen's top edge, from which the results' top inset is measured.
        .background(alignment: .top) {
            Color.clear
                .frame(height: 0)
                .onGeometryChange(for: CGFloat.self) { proxy in
                    proxy.frame(in: .global).minY
                } action: { safeTop = $0 }
        }
        .onAppear {
            placedAt = cancelCenter
            // Rows arrive after the field lands. Building them first spends the flight's frames on
            // layout, and the first half of it never gets drawn.
            withAnimation(DetailSearch.entry) {
                hasFlown = true
            } completion: {
                showsResults = true
            }
        }
    }

    /// Where the cancel button's glass circle sits.
    private var cancelCenter: CGPoint? {
        guard contentFrame != .zero else { return nil }
        if let barSlot, inBarRow(barSlot), barSlot.midX > contentFrame.midX {
            return CGPoint(x: barSlot.midX, y: barSlot.midY)
        }
        let inset = DetailSearchBar.barItemInset(compact: sizeClass == .compact)
        return CGPoint(x: contentFrame.maxX - inset - DetailSearchBar.rowHeight / 2,
                       y: contentFrame.minY - DetailSearchBar.barHeight
                          + DetailSearchBar.rowHeight / 2)
    }

    /// Toolbar items report a placeholder frame near the origin before they are laid out.
    private func inBarRow(_ rect: CGRect) -> Bool {
        rect.minX >= contentFrame.minX && rect.maxX <= contentFrame.maxX + 1
            && rect.midY < contentFrame.minY
    }

    /// The gap between the field and the first row.
    private static let fieldGap: CGFloat = 9

    private var resultsTop: CGFloat {
        // The field sits in the bar row and ends just above the content, so the rows start a little
        // below its top edge. With no content region measured the field is in flow instead.
        guard contentFrame != .zero else { return DetailSearchBar.capsuleHeight + Self.fieldGap }
        return DetailSearchBar.capsuleHeight - DetailSearchBar.rowHeight + Self.fieldGap
    }

    /// Glass behind the field, for lists with no section header to draw it.
    private var fieldBackdrop: some View {
        Color.clear
            .frame(height: barHeight)
            .background { DetailSearchGlass() }
            .clipped()
            .ignoresSafeArea(.container, edges: .top)
            .opacity(hasFlown && !isClosing && fieldGlass ? 1 : 0)
            .animation(.easeOut(duration: 0.15), value: fieldGlass)
    }

    private var barHeight: CGFloat { safeTop + resultsTop }

    // Not stacked above the results, whose size would then depend on this GeometryReader: the
    // keyboard resizes it, and every row would be rebuilt as the keyboard animated.
    @ViewBuilder
    private var field: some View {
        if let cancelCenter = placedAt ?? cancelCenter {
            // The leading margin mirrors the cancel button's own inset, so the field is concentric
            // with the corner it sits in.
            GeometryReader { proxy in
                let container = proxy.frame(in: .global)
                let radius = DetailSearchBar.rowHeight / 2
                let leading = max(0, container.maxX - cancelCenter.x - radius)
                let trailing = max(0, container.maxX - cancelCenter.x + radius
                                    + DetailSearchBar.cancelGap)
                let top = max(0, cancelCenter.y - radius - container.minY)
                bar
                    .flying(from: sourceFrame,
                            to: CGRect(x: container.minX + leading, y: container.minY + top,
                                       width: max(1, container.width - leading - trailing),
                                       height: DetailSearchBar.capsuleHeight),
                            collapsed: !hasFlown || isClosing)
                    .padding(.leading, leading)
                    .padding(.trailing, trailing)
                    .padding(.top, top)
            }
            .ignoresSafeArea(.container, edges: .top)
        } else {
            bar.padding(.horizontal, DetailSearchBar.barMargin)
        }
    }

    private var bar: some View {
        DetailSearchBar(text: $query, prompt: request.prompt, tint: request.tint,
                        autofocus: acceptsTyping, showsPrompt: hasFlown && !isClosing)
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

    var body: some View {
        NavigationStack {
            DetailSearchScreen(request: request, query: query, onClose: {})
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
                                                              content: .credits(entries))])
    }
}
