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
    // The cancel button only exists while searching, so what it reports is kept for next time.
    @State private var learnedSlot: CGRect?

    @State private var pageHidden = false
    // Separate from `isSearching` so the cancel button's arrival can animate without an animated
    // transaction reaching the screen, which draws itself.
    @State private var barSearching = false

    private var isSearching: Bool { request != nil && !isClosing }

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
                                   contentFrame: contentFrame,
                                   isClosing: isClosing, onClose: close)
                    // Search animates its own arrival. A transition here would fade the whole
                    // screen in over the page, drawing both at once.
                    .transition(.identity)
                    // Also fires when a result is pushed over this, which ends the search. The
                    // cancel button has to go with it, or the page keeps it after coming back.
                    .onDisappear {
                        self.request = nil
                        isClosing = false
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
        // Don't hide the bar. That shrinks the safe area, and the movie and show headers lay
        // themselves out from it, so they jump 44pt.
        .navigationBarBackButtonHidden(isSearching)
        .toolbarBackgroundVisibility(isSearching ? .hidden : .automatic, for: .navigationBar)
        .toolbar {
            if barSearching, request != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: close) {
                        Image(systemName: "xmark")
                            .font(.system(size: 17, weight: .medium))
                    }
                    .tint(.white)
                    .accessibilityLabel("Close Search")
                    .onGeometryChange(for: CGRect.self) { proxy in
                        DetailSearchBar.barCircle(around: proxy.frame(in: .global))
                    } action: { report($0) }
                }
            }
        }
        .environment(\.detailSearch, action)
    }

    private var action: DetailSearchAction {
        DetailSearchAction(isPresented: isSearching) { opened, from in
            isClosing = false
            sourceFrame = from
            request = opened
            withAnimation(DetailSearch.barHandoff) { barSearching = true }
        }
    }

    /// Only the cancel button decides this. A page's own bar items aren't necessarily the trailing
    /// one — the person page has a filter beside its search button — so their frames don't apply.
    private func report(_ slot: CGRect) {
        learnedSlot = slot
        // Not while searching: moving it then drags the field mid-flight.
        if !isSearching { barSlot = slot }
    }

    private func close() {
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
