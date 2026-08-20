//
//  ListMembershipToggles.swift
//  MovieTracker
//

import SwiftUI
import SwiftData

/// Toggle rows for a set of lists. Membership and toggling arrive as closures so movies and shows share them.
struct ListMembershipToggles: View {
    let lists: [MediaList]
    let isMember: (MediaList) -> Bool
    let toggle: (MediaList) -> Void

    var body: some View {
        ForEach(lists) { list in
            Toggle(isOn: Binding(get: { isMember(list) }, set: { _ in toggle(list) })) {
                Label {
                    Text(list.name)
                } icon: {
                    // Tinted per list, matching the list switcher in ``ListTitleMenu``.
                    if let image = ListSymbol.menuImage(list.symbol) {
                        Image(uiImage: image)
                            .tint(list.color)
                    } else {
                        Image(systemName: ListSymbol.outline(list.symbol))
                            .tint(list.color)
                    }
                }
            }
        }
    }
}

#Preview {
    let context = previewModelContainer.mainContext
    let favorites = MediaList(name: "Favorites", symbol: "heart", sortOrder: 1, colorIndex: 2)
    let queued = MediaList(name: "Queued", symbol: "clock", sortOrder: 2, colorIndex: 3)
    context.insert(favorites); context.insert(queued)

    return Menu("Add to List") {
        ListMembershipToggles(lists: [favorites, queued],
                              isMember: { $0.uuid == favorites.uuid }, toggle: { _ in })
    }
    .padding()
    .modelContainer(previewModelContainer)
    .environment(PersistenceCoordinator(context))
    .preferredColorScheme(.dark)
}
