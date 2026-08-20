//
//  SidebarRow.swift
//  MovieTracker
//

import SwiftUI

/// A sidebar list row. `.tag` is applied last: a trailing `.badge` shadows it and kills selection.
struct SidebarRow<Icon: View>: View {
    let title: String
    let tag: SidebarItem
    let selected: Bool
    let badge: Int
    @ViewBuilder var icon: Icon

    var body: some View {
        Label {
            Text(title)
                .foregroundStyle(selected ? Color.white : Color.primary)
        } icon: {
            icon
        }
        .badge(badge)
        .tag(tag)
    }
}
