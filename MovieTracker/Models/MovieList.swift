//
//  MovieList.swift
//  MovieTracker
//
//  A user-facing list of movies, synced via CloudKit. Two lists always exist
//  and can't be deleted or renamed — "To Watch" and "Watched" — and the user
//  can create any number of custom lists alongside them.
//
//  CloudKit rules: every stored property has a default or is optional, no
//  unique constraints, and relationships are optional with an inverse.
//

import SwiftUI
import SwiftData

/// Distinguishes the built-in lists from user-created ones.
enum ListKind: Int {
    case custom = 0
    case toWatch = 1
    case watched = 2
    /// A rotating history of recently browsed movies (see `WatchListStore.recordView`).
    case viewed = 3
}

@Model
final class MovieList {
    var uuid: UUID = UUID()
    var name: String = ""
    var symbol: String = "list.bullet"
    /// Index into `Color.listPalette` for the list's tint.
    var colorIndex: Int = 0
    var kindRaw: Int = ListKind.custom.rawValue
    var sortOrder: Int = 0
    var createdAt: Date = Date()

    /// Set when this list has been identified as a duplicate built-in list and its
    /// entries have been moved to the surviving copy (see
    /// `WatchListStore.deduplicateBuiltInLists`). Such a list is hidden from the UI
    /// and deleted on a later pass, once the entry moves have had time to sync —
    /// deferring the delete keeps CloudKit from racing it against the re-parent.
    var deduplicatedDate: Date?

    /// Entries belonging to this list. Deleting the list removes its entries.
    @Relationship(deleteRule: .cascade, inverse: \WatchListEntry.list)
    var entries: [WatchListEntry]? = []

    /// A duplicate built-in list awaiting cleanup — hidden from the UI.
    var isDeduplicated: Bool { deduplicatedDate != nil }

    init(name: String, symbol: String, kind: ListKind = .custom, sortOrder: Int = 0, colorIndex: Int = 0) {
        self.uuid = UUID()
        self.name = name
        self.symbol = symbol
        self.colorIndex = colorIndex
        self.kindRaw = kind.rawValue
        self.sortOrder = sortOrder
        self.createdAt = Date()
    }

    var kind: ListKind { ListKind(rawValue: kindRaw) ?? .custom }

    /// The list's tint. Built-in lists have fixed brand colors; custom lists use
    /// their chosen palette color.
    var color: Color {
        switch kind {
        case .toWatch: return .appAccent
        case .watched: return Color(red255: 90, green255: 200, blue255: 250)
        case .viewed: return .gray
        case .custom: return Color.listColor(colorIndex)
        }
    }

    /// Built-in lists (To Watch / Watched) can't be renamed or deleted.
    var isEditable: Bool { kind == .custom }

    /// The Watched list records when each movie was seen and can sort by it.
    var tracksWatchedDate: Bool { kind == .watched }
}
