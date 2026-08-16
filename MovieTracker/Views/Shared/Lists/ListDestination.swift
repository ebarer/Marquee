//
//  ListDestination.swift
//  MovieTracker
//

import SwiftUI

/// A real `MediaList` (Watch List or custom) or the derived Watched / Viewed queries.
enum ListSelection: Hashable {
    case list(UUID)
    case watched
    case viewed
}

/// A `ListSelection` resolved to the identity and contents the Lists screen needs.
struct ListDestination {
    let selection: ListSelection
    let name: String
    let color: Color
    let symbol: String
    let emptyDescription: String
    let list: MediaList?

    static let watchedColor = Color(red255: 90, green255: 200, blue255: 250)
    static let viewedColor = Color.gray

    static func resolve(_ selection: ListSelection, lists: [MediaList]) -> ListDestination {
        switch selection {
        case .list(let uuid):
            let list = lists.first { $0.uuid == uuid }
            return ListDestination(
                selection: selection,
                name: list?.name ?? "Lists",
                color: list?.color ?? .appAccent,
                symbol: list?.symbol ?? "list.bullet",
                emptyDescription: list.map {
                    $0.isWatchList ? "Movies & TV you want to watch will appear here."
                                   : "Movies & TV you add to “\($0.name)” will appear here."
                } ?? "",
                list: list)
        case .watched:
            return ListDestination(
                selection: selection, name: "Watched", color: watchedColor,
                symbol: "checkmark.rectangle.stack",
                emptyDescription: "Movies & TV you mark watched will appear here.", list: nil)
        case .viewed:
            return ListDestination(
                selection: selection, name: "Viewed", color: viewedColor,
                symbol: "clock.arrow.circlepath",
                emptyDescription: "Movies & TV you browse will appear here.", list: nil)
        }
    }

    /// Rows this destination holds — movies, shows and tracked seasons alike.
    @MainActor
    func mediaCount(using store: PersistenceCoordinator?) -> Int {
        switch selection {
        case .list: return (list?.entries ?? []).count
        case .watched: return store?.watchedCount ?? 0
        case .viewed: return store?.viewedCount ?? 0
        }
    }

    func listRequest(watchedSort: WatchedSortKey, listSort: ListSortKey, listFoldOlder: Bool) -> ListRequest? {
        switch selection {
        case .list(let uuid): return list != nil ? .list(uuid, sort: listSort, foldOlder: listFoldOlder) : nil
        case .watched: return .watched(sort: watchedSort)
        case .viewed: return .viewed
        }
    }
}
