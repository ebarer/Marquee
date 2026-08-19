//
//  DetailSearchHost.swift
//  MovieTracker
//

import SwiftUI

/// The shared rules for searching a list on a detail screen.
enum DetailSearch {
    static let minimumRows = 8
    static let duration = 0.25
    static let entry = Animation.easeOut(duration: duration)
    /// The rows arriving after the field has landed.
    static let reveal = Animation.easeOut(duration: 0.15)
    /// A control moving between a section header and the navigation bar.
    static let barHandoff = Animation.easeInOut(duration: 0.2)
}

/// What a section needs to open ``DetailSearchScreen``. `open` takes the frame of the control that
/// was tapped, which the field grows out of.
struct DetailSearchAction {
    let isPresented: Bool
    let open: (DetailSearchRequest, CGRect?) -> Void
}

private struct DetailSearchKey: EnvironmentKey {
    static let defaultValue: DetailSearchAction? = nil
}

extension EnvironmentValues {
    var detailSearch: DetailSearchAction? {
        get { self[DetailSearchKey.self] }
        set { self[DetailSearchKey.self] = newValue }
    }
}

private struct DetailSearchHost: ViewModifier {
    @State private var request: DetailSearchRequest?
    // True while search closes. Clearing `request` outright skips the field's return trip.
    @State private var isClosing = false
    @State private var sourceFrame: CGRect?

    // The field is positioned from these: the content region below the bar, and the trailing bar
    // slot when a page has an item there to measure.
    @State private var contentFrame: CGRect = .zero
    @State private var barSlot: CGRect?
    // The trailing items only exist while searching, so what they report is kept for next time.
    @State private var cancelSlot: CGRect?
    @State private var countsSlot: CGRect?

    @State private var pageHidden = false
    // Separate from `isSearching` so the cancel button's arrival can animate without an animated
    // transaction reaching the screen, which draws itself.
    @State private var barSearching = false

    @State private var query = ""
    @State private var landed = false
    @State private var fieldFocused = false
    @State private var fieldFrame: CGRect = .zero

    @AppStorage("castEpisodeCounts") private var showsEpisodeCounts = true
    @Environment(\.closeModal) private var closeModal

    private var isSearching: Bool { request != nil && !isClosing }

    /// A view over the navigation bar takes no touches, so the settled field is a bar item. A
    /// modal's bar leaves with the keyboard and would take the field with it, so there it stays.
    private var fieldInBar: Bool { landed && closeModal == nil }

    func body(content: Content) -> some View {
        ZStack {
            // Kept mounted: unmounting the page loses its scroll position. Stops being drawn once
            // search has faded in over it, so the field's glass isn't re-blurring it after that.
            content
                .opacity(pageHidden ? 0 : 1)
                .animation(nil, value: pageHidden)
                .allowsHitTesting(request == nil)
                .accessibilityHidden(request != nil)

            if let request {
                DetailSearchScreen(request: request, sourceFrame: sourceFrame, barSlot: barSlot,
                                   trailingItems: request.countsEpisodes ? 2 : 1,
                                   contentFrame: contentFrame, isClosing: isClosing,
                                   query: $query, fieldInBar: fieldInBar,
                                   focused: !fieldInBar && fieldFocused,
                                   onFieldFrame: { fieldFrame = $0 },
                                   onLanded: { landed = true }, onClose: close)
                    // Search animates its own arrival. A transition here would fade the whole
                    // screen in over the page, drawing both at once.
                    .transition(.identity)
                    // Also fires when a result is pushed over this, which ends the search. The
                    // cancel button has to go with it, or the page keeps it after coming back.
                    .onDisappear {
                        self.request = nil
                        isClosing = false
                        landed = false
                        withAnimation(DetailSearch.barHandoff) { barSearching = false }
                    }
            }
        }
        .onGeometryChange(for: CGRect.self) { proxy in
            proxy.frame(in: .global)
        } action: { contentFrame = $0 }
        .task(id: isSearching) {
            guard isSearching else { pageHidden = false; return }
            try? await Task.sleep(for: .seconds(DetailSearch.duration))
            pageHidden = true
        }
        // A focus request made in the same pass that installs the item in the bar is dropped.
        .task(id: landed) {
            guard landed else { fieldFocused = false; return }
            try? await Task.sleep(for: .milliseconds(50))
            fieldFocused = true
        }
        // Don't hide the bar. That shrinks the safe area, and the movie and show headers lay
        // themselves out from it, so they jump 44pt.
        .navigationBarBackButtonHidden(isSearching)
        .toolbarBackgroundVisibility(isSearching ? .hidden : .automatic, for: .navigationBar)
        .toolbar {
            if barSearching, let request {
                // Sized rather than expanded: a principal item that asks for infinite width is
                // still given only its content's.
                ToolbarItem(placement: .principal) {
                    DetailSearchBar(text: $query, prompt: request.prompt, tint: request.tint,
                                    focused: fieldInBar && fieldFocused)
                        .frame(width: max(1, fieldFrame.width))
                        .opacity(fieldInBar ? 1 : 0)
                }
                // Declared first, so it sits to the left of the button that closes search.
                if request.countsEpisodes {
                    ToolbarItem(placement: .topBarTrailing) {
                        CastCountsMenu(showsCounts: $showsEpisodeCounts, style: .bar,
                                       tint: request.tint)
                            .onGeometryChange(for: CGRect.self) { proxy in
                                DetailSearchBar.barCircle(around: proxy.frame(in: .global))
                            } action: { countsSlot = $0; syncBarSlot() }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: close) {
                        Image(systemName: "xmark")
                            .font(.system(size: 17, weight: .medium))
                    }
                    .tint(.white)
                    .accessibilityLabel("Close Search")
                    .onGeometryChange(for: CGRect.self) { proxy in
                        DetailSearchBar.barCircle(around: proxy.frame(in: .global))
                    } action: { cancelSlot = $0; syncBarSlot() }
                }
            }
        }
        .environment(\.detailSearch, action)
    }

    private var action: DetailSearchAction {
        DetailSearchAction(isPresented: isSearching) { opened, from in
            isClosing = false
            sourceFrame = from
            query = ""
            landed = false
            // Without a filter beside the close button, the slot measured with one is too wide.
            if !opened.countsEpisodes {
                countsSlot = nil
                barSlot = cancelSlot
            }
            request = opened
            withAnimation(DetailSearch.barHandoff) { barSearching = true }
        }
    }

    /// Where search's own trailing items sit. A page's bar items aren't necessarily the trailing
    /// ones — the person page has a filter beside its search button — so their frames don't apply.
    private var learnedSlot: CGRect? {
        guard let cancelSlot else { return countsSlot }
        return countsSlot.map { cancelSlot.union($0) } ?? cancelSlot
    }

    private func syncBarSlot() {
        // Not while searching: moving the slot then drags the field mid-flight.
        if !isSearching { barSlot = learnedSlot }
    }

    private func close() {
        // Before the animation, so the keyboard leaves with the tap rather than after the flight.
        landed = false
        // A pass later, or the bar's copy is still drawn when its removal is snapshotted and the
        // flying copy has a ghost alongside it.
        Task { @MainActor in
            withAnimation(DetailSearch.entry) {
                isClosing = true
                barSearching = false
            } completion: {
                request = nil
                isClosing = false
                barSlot = learnedSlot ?? barSlot
            }
        }
    }
}

extension View {
    func detailSearchHost() -> some View {
        modifier(DetailSearchHost())
    }
}

/// The search control a section puts opposite its header.
struct DetailSearchButton: View {
    let request: DetailSearchRequest

    @Environment(\.detailSearch) private var detailSearch
    @State private var frame: CGRect?

    var body: some View {
        if let detailSearch, !detailSearch.isPresented, request.isSearchable {
            Button {
                detailSearch.open(request, frame)
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(request.tint)
                    .sectionHeaderControl()
            }
            .buttonStyle(.plain)
            // The field grows out of this frame, so it has to be measured before the tap.
            .onGeometryChange(for: CGRect.self) { proxy in
                proxy.frame(in: .global)
            } action: { frame = $0 }
            .accessibilityLabel(request.prompt)
        }
    }
}

/// The same control for a navigation bar, which supplies its own glass.
struct DetailSearchToolbarItem: ToolbarContent {
    let request: DetailSearchRequest

    @Environment(\.detailSearch) private var detailSearch
    @State private var frame: CGRect?

    var body: some ToolbarContent {
        if let detailSearch, !detailSearch.isPresented, request.isSearchable {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    detailSearch.open(request, frame)
                } label: {
                    Image(systemName: "magnifyingglass")
                }
                .tint(.white)
                // The frame reported is the glyph's; the bar draws a `rowHeight` glass circle
                // around it, which is what the field has to come out of.
                .onGeometryChange(for: CGRect.self) { proxy in
                    DetailSearchBar.barCircle(around: proxy.frame(in: .global))
                } action: { frame = $0 }
                .accessibilityLabel(request.prompt)
            }
        }
    }
}
