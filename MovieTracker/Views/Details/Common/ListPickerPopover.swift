//
//  ListPickerPopover.swift
//  MovieTracker
//

import SwiftUI
import SwiftData

/// A tap-anywhere-to-toggle list of custom lists shown as a popover. Unlike a `Menu`
/// it stays open so several lists can be toggled in a row. Membership + toggling are
/// supplied as closures so movies and shows share one popover.
struct ListPickerPopover: View {
    let lists: [MediaList]
    let tint: Color
    let isMember: (MediaList) -> Bool
    let toggle: (MediaList) -> Void

    @State private var contentHeight: CGFloat = 0
    private static let maxHeight: CGFloat = 320

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(lists) { list in
                    let member = isMember(list)
                    Button {
                        toggle(list)
                    } label: {
                        HStack(spacing: 12) {
                            ListIcon(list, size: 28)
                            Text(list.name)
                                .foregroundStyle(.primary)
                            Spacer(minLength: 24)
                            Image(systemName: "checkmark")
                                .fontWeight(.semibold)
                                .foregroundStyle(tint)
                                .opacity(member ? 1 : 0)
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 14)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if list.uuid != lists.last?.uuid {
                        Divider().padding(.leading, 58)
                    }
                }
            }
            .padding(.vertical, 6)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
        }
        .scrollBounceBehavior(.always)
        .frame(minWidth: 250)
        .frame(height: min(max(contentHeight, 1), Self.maxHeight))
        .presentationCompactAdaptation(.popover)
    }
}

#Preview {
    let context = previewModelContainer.mainContext
    let favorites = MediaList(name: "Favorites", symbol: "heart", sortOrder: 1, colorIndex: 2)
    let queued = MediaList(name: "Queued", symbol: "clock", sortOrder: 2, colorIndex: 3)
    context.insert(favorites); context.insert(queued)

    return ListPickerPopover(lists: [favorites, queued], tint: .appAccent,
                             isMember: { $0.uuid == favorites.uuid }, toggle: { _ in })
        .modelContainer(previewModelContainer)
        .environment(PersistenceCoordinator(context))
        .preferredColorScheme(.dark)
}
