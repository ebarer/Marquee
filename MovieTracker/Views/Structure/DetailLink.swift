//
//  DetailLink.swift
//  MovieTracker
//

import SwiftUI

/// Pushes within a `NavigationStack`, or opens the detail modal when `openDetail` is set.
struct DetailLink<Value: Hashable, Label: View>: View {
    let value: Value
    @ViewBuilder var label: () -> Label

    @Environment(\.openDetail) private var openDetail
    @Environment(\.searchPush) private var searchPush

    var body: some View {
        if let openDetail {
            Button {
                openDetail(AnyHashable(value))
            } label: {
                label()
            }
            .buttonStyle(.plain)
        } else if let searchPush {
            // No style of its own: a list row still takes the press highlight, and the people
            // strip sets `.plain` itself.
            Button {
                searchPush(AnyHashable(value))
            } label: {
                label()
            }
        } else {
            NavigationLink(value: value) {
                label()
            }
        }
    }
}
