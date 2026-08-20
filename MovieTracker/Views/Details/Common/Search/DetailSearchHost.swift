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
    @State private var filterSlot: CGRect?

    @State private var pageHidden = false
    // Separate from `isSearching` so the cancel button's arrival can animate without an animated
    // transaction reaching the screen, which draws itself.
    @State private var barSearching = false

    @State private var query = ""
    @State private var landed = false
    @State private var fieldFocused = false
    @State private var fieldWidth: CGFloat = 0

    @AppStorage("castEpisodeCounts") private var showsEpisodeCounts = true
    @AppStorage("personCreditFilter") private var creditFilter = CreditFilter()
    @Environment(\.closeModal) private var closeModal

    private var isSearching: Bool { request != nil && !isClosing }

    /// Whether a kind these rows actually have is hidden — what the filter glyph reflects.
    private var hidesCredits: Bool {
        request?.filterKinds.contains(where: creditFilter.hides) == true
    }

    /// A modal's bar leaves with the keyboard and would take the field with it, so the flying copy
    /// is the real field there and the only one that ever takes focus.
    private var fieldStaysInPlace: Bool { closeModal != nil }

    /// A view over the navigation bar takes no touches, so elsewhere the settled field is a bar item.
    private var fieldInBar: Bool { landed && !fieldStaysInPlace }

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
                                   trailingItems: request.trailingItems,
                                   contentFrame: contentFrame, isClosing: isClosing,
                                   query: $query, fieldInBar: fieldInBar,
                                   focused: fieldStaysInPlace && fieldFocused,
                                   onFieldWidth: { fieldWidth = $0 },
                                   onLanded: { landed = true }, onClose: close)
                    // Search animates its own arrival. A transition here would fade the whole
                    // screen in over the page, drawing both at once.
                    .transition(.identity)
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
                        .frame(width: max(1, fieldWidth))
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
                if !request.filterKinds.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        CreditFilterMenu(kinds: request.filterKinds, filter: $creditFilter) {
                            Image(systemName: "line.3.horizontal.decrease")
                                .foregroundStyle(hidesCredits ? Color.black : .white)
                        }
                        // On the menu rather than its label, so the fill is centred on the item
                        // the bar lays out.
                        .filterOnBadge(hidesCredits, size: DetailSearchBar.barItemFill)
                        .tint(.white)
                        .onGeometryChange(for: CGRect.self) { proxy in
                            DetailSearchBar.barCircle(around: proxy.frame(in: .global))
                        } action: { filterSlot = $0; syncBarSlot() }
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
            // A slot measured with a control this request doesn't bring is too wide for it.
            if !opened.countsEpisodes { countsSlot = nil }
            if opened.filterKinds.isEmpty { filterSlot = nil }
            barSlot = learnedSlot ?? barSlot
            request = opened
            withAnimation(DetailSearch.barHandoff) { barSearching = true }
        }
    }

    /// Where search's own trailing items sit. A page's bar items aren't necessarily the trailing
    /// ones — a detail screen adds its own beside the search button — so their frames don't apply.
    private var learnedSlot: CGRect? {
        [cancelSlot, countsSlot, filterSlot].compactMap { $0 }
            .reduce(into: CGRect?.none) { union, slot in
                union = union?.union(slot) ?? slot
            }
    }

    private func syncBarSlot() {
        // Not while searching: moving the slot then drags the field mid-flight.
        if !isSearching { barSlot = learnedSlot }
    }

    private func close() {
        // Cleared before the animation, so the keyboard leaves with the tap, not after the flight.
        fieldFocused = false
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
