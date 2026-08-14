//
//  ListEntryConfirmation.swift
//  MovieTracker
//

import SwiftUI

/// A confirmation a swipe is waiting on, and the entry that raised it.
enum ListEntryConfirmation: Identifiable {
    /// Removing an in-progress show whose watched episodes would otherwise re-add it.
    case removeFromWatchList(MediaSnapshot)
    /// Marking a whole show, which sweeps every episode of every season.
    case showWatched(MediaSnapshot, watched: Bool)

    var entry: MediaSnapshot {
        switch self {
        case .removeFromWatchList(let entry): return entry
        case .showWatched(let entry, _): return entry
        }
    }

    var id: MediaSnapshot.ID { entry.id }

    var title: String {
        switch self {
        case .removeFromWatchList: return "Remove from Watch List?"
        case .showWatched(_, let watched): return watched ? "Mark Show Watched?" : "Mark Show Unwatched?"
        }
    }

    var message: String {
        switch self {
        case .removeFromWatchList:
            return "You've watched some episodes, so it stays on your Watch List automatically. Removing keeps it off until you add it back."
        case .showWatched(let entry, let watched):
            return watched
                ? "This marks every episode of every season of \(entry.title) as watched."
                : "This clears the watched date for every episode of every season of \(entry.title)."
        }
    }

    var confirmLabel: String {
        switch self {
        case .removeFromWatchList: return "Remove"
        case .showWatched(_, let watched): return watched ? "Mark Watched" : "Mark Unwatched"
        }
    }

    /// Removing and un-watching both discard something the person recorded.
    var isDestructive: Bool {
        switch self {
        case .removeFromWatchList: return true
        case .showWatched(_, let watched): return !watched
        }
    }
}

private struct EntryConfirmationDialog: ViewModifier {
    let entry: MediaSnapshot
    let actions: ListEntryActions

    /// Non-nil only for the entry that raised the confirmation, so the dialog presents from it.
    private var item: Binding<ListEntryConfirmation?> {
        Binding(get: { actions.pending.wrappedValue?.entry.id == entry.id ? actions.pending.wrappedValue : nil },
                set: { actions.pending.wrappedValue = $0 })
    }

    func body(content: Content) -> some View {
        content.confirmationDialog(Text(item.wrappedValue?.title ?? ""),
                                   item: item,
                                   titleVisibility: .visible) { confirmation in
            Button(confirmation.confirmLabel,
                   role: confirmation.isDestructive ? .destructive : nil) {
                actions.confirm(confirmation)
            }
        } message: { confirmation in
            Text(confirmation.message)
        }
    }
}

extension View {
    /// Anchored to the entry it's asking about. The item-based dialog holds the change: nothing
    /// is written until an action here runs.
    func listEntryConfirmation(for entry: MediaSnapshot, actions: ListEntryActions) -> some View {
        modifier(EntryConfirmationDialog(entry: entry, actions: actions))
    }
}

#Preview("Confirmations") {
    @Previewable @State var pending: ListEntryConfirmation?
    let context = ListEntryContext(selection: .watched, isWatchList: false,
                                   watchListIDs: [], listColor: .appAccent)
    let entry = MediaSnapshot.preview(id: 1, title: "Severance", mediaType: .tv)
    let actions = ListEntryActions(store: nil, context: context, pending: $pending)

    List {
        Button("Remove from Watch List") { pending = .removeFromWatchList(entry) }
        Button("Mark Show Watched") { pending = .showWatched(entry, watched: true) }
        Button("Mark Show Unwatched") { pending = .showWatched(entry, watched: false) }
    }
    .listEntryConfirmation(for: entry, actions: actions)
    .preferredColorScheme(.dark)
}
