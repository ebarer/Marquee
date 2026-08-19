//
//  ExternalLinksMenu.swift
//  MovieTracker
//

import SwiftUI

/// The nav bar's way out to a title's pages on other sites, each opened in-app.
struct ExternalLinksMenu: View {
    let links: [ExternalLink]
    var onSelect: (ExternalLink) -> Void

    var body: some View {
        Menu {
            ForEach(links) { link in
                Button { onSelect(link) } label: {
                    Label(link.site.rawValue, systemImage: link.site.symbol)
                }
            }
        } label: {
            Image(systemName: "arrow.up.right").foregroundStyle(.white)
        }
        .accessibilityLabel("Open on another site")
    }
}

/// Wraps the menu as a bar item, and stands down when there's nowhere to go.
struct ExternalLinksToolbarItem: ToolbarContent {
    let links: [ExternalLink]
    var onSelect: (ExternalLink) -> Void

    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            if !links.isEmpty {
                ExternalLinksMenu(links: links, onSelect: onSelect)
                    .tint(.white)
            }
        }
    }
}

#Preview {
    NavigationStack {
        Color.appBackground.ignoresSafeArea()
            .toolbar {
                ExternalLinksToolbarItem(links: TitleExtras.preview.links) { _ in }
            }
            .navigationTitle("Inception")
            .toolbarTitleDisplayMode(.inline)
    }
    .preferredColorScheme(.dark)
}
