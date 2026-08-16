//
//  MovieActionBar.swift
//  MovieTracker
//

import SwiftUI
import SwiftData

/// The Liquid Glass controls beside the poster: bookmark, checkmark, custom lists, trailer.
/// Marking Watched absorbs the bookmark into a pill spanning both slots.
struct MovieActionBar: View {
    let movie: Movie
    let lists: [MediaList]
    let tint: Color
    @Binding var isSeen: Bool

    @Environment(PersistenceCoordinator.self) private var store: PersistenceCoordinator?
    @Namespace private var glassNamespace
    @State private var tracked = false
    @State private var wasOnWatchList = false

    private var canonical: [MediaList] { store?.canonicalLists(lists) ?? lists }
    private var watchList: MediaList? { canonical.first { $0.isWatchList } }
    private var customLists: [MediaList] { canonical.filter { !$0.isWatchList } }

    var body: some View {
        GlassEffectContainer(spacing: ActionBarMetrics.spacing) {
            HStack(spacing: ActionBarMetrics.spacing) {
                if !isSeen {
                    bookmarkButton
                }
                watchedButton
                customListsControl
                TrailerButton(trailer: movie.primaryTrailer, tint: tint)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isSeen)
        .onAppear(perform: refresh)
    }

    private var bookmarkButton: some View {
        GlassActionButton(systemName: tracked ? "bookmark.fill" : "bookmark", isOn: tracked,
                          shape: Circle(), tint: tint) {
            tracked.toggle()
            store?.afterCommit { store?.toggleWatchList(movie); refresh() }
        }
        .glassEffectID("bookmark", in: glassNamespace)
        .glassEffectTransition(.matchedGeometry)
    }

    private var watchedButton: some View {
        // Unmarking Watched restores the movie to the Watch List only if it was
        // there beforehand.
        GlassActionButton(systemName: "checkmark", isOn: isSeen,
                          width: isSeen ? ActionBarMetrics.size * 2 + ActionBarMetrics.spacing : ActionBarMetrics.size,
                          shape: Capsule(), tint: tint) {
            let watched = !isSeen
            if watched { wasOnWatchList = tracked }
            // Flip the glass now, persist on the next turn: the write and the store tick it
            // raises would otherwise run inside the tap and cost the morph its opening frames.
            isSeen = watched
            tracked = watched ? false : wasOnWatchList
            store?.afterCommit {
                store?.setWatched(watched, for: movie)
                if !watched, wasOnWatchList { store?.addToWatchList(movie) }
                refresh()
            }
        }
        .glassEffectID("watched", in: glassNamespace)
    }

    @ViewBuilder
    private var customListsControl: some View {
        if customLists.count == 1, let list = customLists.first {
            let member = list.contains(movie.id)
            GlassActionButton(systemName: member ? filledSymbol(list.symbol) : list.symbol,
                              isOn: member, shape: Circle(), tint: tint) {
                store?.afterCommit { store?.toggle(movie, in: list); refresh() }
            }
            .glassEffectID("plus", in: glassNamespace)
        } else if !customLists.isEmpty {
            let anyMember = customLists.contains { $0.contains(movie.id) }
            GlassActionMenu(systemName: "plus", isOn: anyMember, shape: Circle(), tint: tint) {
                ListMembershipToggles(lists: customLists,
                                      isMember: { $0.contains(movie.id) },
                                      toggle: { list in
                                          store?.afterCommit { store?.toggle(movie, in: list); refresh() }
                                      })
            }
            // Stays open so several lists can be toggled in one go.
            .menuActionDismissBehavior(.disabled)
            .glassEffectID("plus", in: glassNamespace)
        }
    }

    private func refresh() {
        tracked = watchList?.contains(movie.id) ?? false
        isSeen = store?.isWatched(movie) ?? false
    }
}

// Interactive (tap bookmark/watched/list to drive the glass morph live, backed by the
// in-memory store) plus a resting Seen state showing the spanning pill.
#Preview {
    @Previewable @State var isSeen = false
    let context = previewModelContainer.mainContext
    let seen = MediaList(name: "Seen It", symbol: "eye", sortOrder: 2, colorIndex: 1)
    let queued = MediaList(name: "Queued", symbol: "clock", sortOrder: 3, colorIndex: 3)
    context.insert(seen); context.insert(queued)
    let entry = ListEntry(movie: .preview); entry.list = seen; context.insert(entry)

    return VStack(spacing: 24) {
        MovieActionBar(movie: .preview, lists: [seen, queued], tint: .appAccent, isSeen: $isSeen)
        MovieActionBar(movie: .previewList[2], lists: [], tint: .appAccent, isSeen: .constant(true))
    }
    .padding()
    .background(Color.appBackground)
    .modelContainer(previewModelContainer)
    .environment(PersistenceCoordinator(context))
}
