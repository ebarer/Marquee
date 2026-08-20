//
//  DetailChrome.swift
//  MovieTracker
//

import SwiftUI

/// The navigation bar every detail screen shares: title, the search button a section hands up, then Close.
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
    func detailChrome<Principal: View, Extra: ToolbarContent>(
        title: String,
        search: DetailSearchRequest?,
        @ViewBuilder principal: @escaping () -> Principal = { Text("") },
        @ToolbarContentBuilder extra: @escaping () -> Extra
    ) -> some View {
        modifier(DetailChrome(title: title, search: search,
                              principal: principal, extra: extra))
    }

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
