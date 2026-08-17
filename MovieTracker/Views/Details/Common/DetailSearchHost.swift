//
//  DetailSearchHost.swift
//  MovieTracker
//

import SwiftUI

/// The shared rules for searching a list on a detail screen.
enum DetailSearch {
    static let minimumRows = 8
    static let morphID = "detailSearchField"
    static let crossfade = Animation.easeOut(duration: 0.22)

}

/// Where a search was opened from, which decides how the field arrives.
enum DetailSearchOrigin {
    case body, toolbar
}

/// What a section needs to open ``DetailSearchScreen``.
struct DetailSearchAction {
    let namespace: Namespace.ID
    let isPresented: Bool
    let open: (DetailSearchRequest, DetailSearchOrigin) -> Void
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
    @Namespace private var namespace
    @State private var request: DetailSearchRequest?
    // True while search fades out. Clearing `request` outright skips the transition entirely.
    @State private var isClosing = false
    @State private var origin = DetailSearchOrigin.body

    // The field is positioned from this. Bar margins differ between a full screen and a sheet.
    @State private var cancelFrame: CGRect?

    private var isSearching: Bool { request != nil && !isClosing }

    func body(content: Content) -> some View {
        ZStack {
            // Kept mounted: unmounting the page loses its scroll position.
            content
                .allowsHitTesting(request == nil)
                .accessibilityHidden(request != nil)

            if let request {
                DetailSearchScreen(request: request, namespace: namespace, origin: origin,
                                   cancelFrame: cancelFrame, isClosing: isClosing, onClose: close)
                    .opacity(isClosing ? 0 : 1)
                    // Also fires when a result is pushed over this, which ends the search.
                    .onDisappear { self.request = nil; isClosing = false }
            }
        }
        // Don't hide the bar. That shrinks the safe area, and the movie and show headers lay
        // themselves out from it, so they jump 44pt.
        .navigationBarBackButtonHidden(isSearching)
        .toolbarBackgroundVisibility(isSearching ? .hidden : .automatic, for: .navigationBar)
        .toolbar {
            if isSearching {
                // Ours rather than a system item because the field's position is measured
                // from it, which needs a glyph size we set.
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: close) {
                        Image(systemName: "xmark")
                            .font(.system(size: 17, weight: .medium))
                    }
                    .tint(.white)
                    .accessibilityLabel("Close Search")
                    .onGeometryChange(for: CGRect.self) { proxy in
                        proxy.frame(in: .global)
                    } action: { cancelFrame = $0 }
                }
            }
        }
        .environment(\.detailSearch, action)
    }

    private var action: DetailSearchAction {
        DetailSearchAction(namespace: namespace, isPresented: isSearching) { opened, from in
            isClosing = false
            origin = from
            withAnimation(DetailSearch.crossfade) { request = opened }
        }
    }

    private func close() {
        withAnimation(DetailSearch.crossfade) {
            isClosing = true
        } completion: {
            request = nil
            isClosing = false
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

    var body: some View {
        // Unmounted while search is up: matchedGeometryEffect needs one view per ID.
        if let detailSearch, !detailSearch.isPresented, request.isSearchable {
            Button {
                detailSearch.open(request, .body)
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(request.tint)
                    .sectionHeaderControl()
            }
            .buttonStyle(.plain)
            .matchedGeometryEffect(id: DetailSearch.morphID, in: detailSearch.namespace)
            .accessibilityLabel(request.prompt)
        }
    }
}

/// The same control for a navigation bar, which supplies its own glass.
struct DetailSearchToolbarItem: ToolbarContent {
    let request: DetailSearchRequest

    @Environment(\.detailSearch) private var detailSearch

    var body: some ToolbarContent {
        if let detailSearch, !detailSearch.isPresented, request.isSearchable {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    detailSearch.open(request, .toolbar)
                } label: {
                    Image(systemName: "magnifyingglass")
                }
                .tint(request.tint)
                .accessibilityLabel(request.prompt)
            }
        }
    }
}
