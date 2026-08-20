//
//  View+SwipeGrid.swift
//  MovieTracker
//

import SwiftUI

extension View {
    /// iOS 27+ enables `swipeActions` outside a `List`; a no-op on earlier systems.
    @ViewBuilder
    func swipeGridContainer() -> some View {
        if #available(iOS 27, *) {
            swipeActionsContainer()
        } else {
            self
        }
    }
}
