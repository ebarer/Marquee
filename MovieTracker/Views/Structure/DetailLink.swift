//
//  DetailLink.swift
//  MovieTracker
//

import SwiftUI

/// Pushes within a `NavigationStack`, or opens the detail modal when `openDetail` is set
/// (the iPad shell). Callers use it just like a `NavigationLink`.
struct DetailLink<Value: Hashable, Label: View>: View {
    let value: Value
    @ViewBuilder var label: () -> Label

    @Environment(\.openDetail) private var openDetail

    var body: some View {
        if let openDetail {
            Button {
                openDetail(AnyHashable(value))
            } label: {
                label()
            }
            .buttonStyle(.plain)
        } else {
            NavigationLink(value: value) {
                label()
            }
        }
    }
}
