//
//  ExternalLinksMenu.swift
//  MovieTracker
//

import SwiftUI

/// Links to a title's pages on other sites, each opened in-app.
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

/// The menu as a bar item, inert until the links resolve.
struct ExternalLinksToolbarItem: ToolbarContent {
    let links: [ExternalLink]
    var onSelect: (ExternalLink) -> Void

    var body: some ToolbarContent {
        // A title always resolves to at least the Rotten Tomatoes search, so the item is
        // unconditional: appearing once Wikidata answers would refill the bar's glass.
        ToolbarItem(placement: .topBarTrailing) {
            ExternalLinksMenu(links: links, onSelect: onSelect)
                .tint(.white)
                .disabled(links.isEmpty)
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
