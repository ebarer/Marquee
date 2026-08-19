//
//  DetailChrome.swift
//  MovieTracker
//

import SwiftUI

/// The navigation bar every detail screen shares: the page's title, the search button a section
/// hands up, and the modal's Close after it.
private struct DetailChrome<Principal: View, Extra: ToolbarContent>: ViewModifier {
    let title: String
    let search: DetailSearchRequest?
    @ViewBuilder let principal: () -> Principal
    @ToolbarContentBuilder let extra: () -> Extra

    @Environment(\.closeModal) private var closeModal
    @Environment(\.isModalRoot) private var isModalRoot
    @Environment(\.detailSearch) private var detailSearch

    private var isSearching: Bool { detailSearch?.isPresented == true }

    func body(content: Content) -> some View {
        content
            .navigationTitle(title)
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                // Two principal items resolve unpredictably: searching, the slot is the field's.
                if !isSearching {
                    ToolbarItem(placement: .principal) { principal() }
                }
                // All of these would sit over the search field and take the taps meant for its
                // cancel, so they stand down while it holds the bar's row.
                if !isSearching {
                    // Only the search button is contingent on a section hoisting one; `extra`
                    // is the screen's own and must not wait on that.
                    if let search {
                        DetailSearchToolbarItem(request: search)
                    }
                    extra()
                    // Placement spelled out: an automatic spacer doesn't land in the trailing
                    // group, so Close would share its glass with the items before it.
                    ToolbarSpacer(.fixed, placement: .topBarTrailing)
                }
                // Declared last, so Close stays the rightmost item.
                if let closeModal, !isSearching {
                    ModalCloseItem(close: closeModal, isRoot: isModalRoot)
                }
            }
    }
}

extension View {
    /// Applied by every detail screen, so none of them has to re-derive the bar's contents or the
    /// order they sit in. `extra` lands between the search button and Close.
    func detailChrome<Principal: View, Extra: ToolbarContent>(
        title: String,
        search: DetailSearchRequest?,
        @ViewBuilder principal: @escaping () -> Principal = { Text("") },
        @ToolbarContentBuilder extra: @escaping () -> Extra
    ) -> some View {
        modifier(DetailChrome(title: title, search: search,
                              principal: principal, extra: extra))
    }

    /// For a screen with no bar items of its own beside the search button.
    func detailChrome<Principal: View>(
        title: String,
        search: DetailSearchRequest?,
        @ViewBuilder principal: @escaping () -> Principal = { Text("") }
    ) -> some View {
        detailChrome(title: title, search: search, principal: principal) {
            ToolbarSpacer(.fixed, placement: .topBarTrailing)
        }
    }
}
