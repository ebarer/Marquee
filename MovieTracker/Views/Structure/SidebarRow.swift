//
//  SidebarRow.swift
//  MovieTracker
//

import SwiftUI

/// A sidebar list row: icon, title, and a trailing count badge. `.tag` is applied last so
/// `List(selection:)` sees it — a trailing `.badge` shadows it and kills selection.
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
