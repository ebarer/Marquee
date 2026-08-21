//
//  RecentSearchRow.swift
//  MovieTracker
//

import SwiftUI

/// A row in the search screen's Recent section, pushing straight to what was opened before.
struct RecentSearchRow: View {
    let item: RecentSearch

    var body: some View {
        switch item.destination {
        case .movie(let movie):
            link(value: movie) { MovieRow(movie: movie, derivesStatus: true) }
        case .show(let show):
            link(value: show) { ShowRow(show: show, derivesStatus: true) }
        case .person(let person):
            link(value: person) { PersonRow(person: person, showRole: false) }
        }
    }

    // The chevron is drawn here rather than by the list: a recent pushes as a button, so no
    // disclosure indicator comes for free. See ``DetailLink``.
    private func link<Value: Hashable, Content: View>(
        value: Value,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        DetailLink(value: value) {
            HStack(spacing: 8) {
                content()
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        // Opt out of selection so a value already on the path doesn't stray-highlight.
        .selectionDisabled()
    }
}

#Preview {
    NavigationStack {
        List {
            ForEach(RecentSearch.previewList) { item in
                RecentSearchRow(item: item)
            }
        }
        .listStyle(.plain)
        .detailDestinations()
    }
    .modelContainer(previewModelContainer)
    .environment(PersistenceCoordinator(previewModelContainer.mainContext))
    .preferredColorScheme(.dark)
}
