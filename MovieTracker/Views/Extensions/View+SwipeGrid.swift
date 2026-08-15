//
//  View+SwipeGrid.swift
//  MovieTracker
//

import SwiftUI

extension View {
    /// iOS 27+ enables `swipeActions` outside a `List`; a no-op (no swipe) on earlier systems.
    @ViewBuilder
    func swipeGridContainer() -> some View {
        if #available(iOS 27, *) {
            swipeActionsContainer()
        } else {
            self
        }
    }
}
