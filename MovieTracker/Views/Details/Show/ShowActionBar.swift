//
//  ShowActionBar.swift
//  MovieTracker
//

import SwiftUI
import SwiftData

/// The Liquid Glass controls beside the show poster, mirroring `MovieActionBar`.
struct ShowActionBar: View {
    let show: Show
    let lists: [MediaList]
    let tint: Color
    var episodesBySeason: [Int: [Episode]] = [:]
    // Owned by the detail screen: seeding it here would draw an untracked bar for a frame and then flip.
    @Binding var progress: ShowProgress
    var onChange: () -> Void = {}

    @Environment(PersistenceCoordinator.self) private var store: PersistenceCoordinator?
    @Namespace private var glassNamespace
    @State private var wasOnWatchList = false
    @State private var showRemoveConfirm = false
    // Only changes after the first frame animate the bookmark-to-checkmark transition.
    @State private var didAppear = false

    private var isSeen: Bool { progress.isWatched }

    private var canonical: [MediaList] { store?.canonicalLists(lists) ?? lists }
    private var watchList: MediaList? { canonical.first { $0.isWatchList } }
    private var customLists: [MediaList] { canonical.filter { !$0.isWatchList } }

    var body: some View {
        GlassEffectContainer(spacing: ActionBarMetrics.spacing) {
            HStack(spacing: ActionBarMetrics.spacing) {
                if !isSeen {
                    bookmarkButton
                }
                ShowWatchedButton(isSeen: isSeen, isCaughtUp: progress.isCaughtUp,
                                  isOngoing: show.isOngoing, tint: tint,
                                  glassNamespace: glassNamespace, onApply: applyWatched)
                customListsControl
                TrailerButton(trailers: show.rankedTrailers, tint: tint)
            }
        }
        .animation(didAppear ? .spring(response: 0.4, dampingFraction: 0.8) : nil, value: isSeen)
        .animation(didAppear ? .easeInOut : nil, value: progress.isCaughtUp)
        .onAppear { didAppear = true }
    }

    private var bookmarkButton: some View {
        GlassActionButton(systemName: progress.isTracked ? "bookmark.fill" : "bookmark",
                          isOn: progress.isTracked, shape: Circle(), tint: tint) {
            handleBookmarkTap()
        }
        .glassEffectID("bookmark", in: glassNamespace)
        .glassEffectTransition(.matchedGeometry)
        .confirmationDialog("Remove from Watch List?", isPresented: $showRemoveConfirm,
                            titleVisibility: .visible) {
            Button("Remove", role: .destructive) {
                store?.afterCommit { store?.dismissFromWatchList(show); refresh(); onChange() }
            }
        } message: {
            Text("You've watched some episodes, so it stays on your Watch List automatically. Removing keeps it off until you add it back.")
        }
    }

    // An in-progress show is auto-kept on the Watch List, so removing it takes a confirmation and
    // sticks. Adding it back is a plain tap that re-tracks the next-episode season.
    private func handleBookmarkTap() {
        guard let store else { return }
        if progress.isTracked, progress.hasProgress {
            showRemoveConfirm = true
            return
        }
        let wasTracked = progress.isTracked
        let hasProgress = progress.hasProgress
        progress.isTracked.toggle()
        store.afterCommit {
            if wasTracked {
                store.toggleWatchList(show)
            } else if hasProgress {
                store.restoreToWatchList(show)
            } else {
                store.addToWatchList(show)
            }
            refresh()
            onChange()
        }
    }

    private func applyWatched(_ watched: Bool) {
        Task { @MainActor in
            if watched {
                wasOnWatchList = progress.isTracked
                await store?.setShowWatched(true, show: show, episodesBySeason: episodesBySeason)
            } else {
                await store?.setShowWatched(false, show: show)
                if wasOnWatchList { store?.addToWatchList(show) }
            }
            refresh()
            onChange()
        }
    }

    @ViewBuilder
    private var customListsControl: some View {
        if customLists.count == 1, let list = customLists.first {
            let member = list.contains(show.id, .tv)
            GlassActionButton(systemName: member ? filledSymbol(list.symbol) : list.symbol,
                              isOn: member, shape: Circle(), tint: tint) {
                store?.toggle(show, in: list)
                refresh()
                onChange()
            }
            .glassEffectID("plus", in: glassNamespace)
        } else if !customLists.isEmpty {
            let anyMember = customLists.contains { $0.contains(show.id, .tv) }
            GlassActionMenu(systemName: "plus", isOn: anyMember, shape: Circle(), tint: tint) {
                ListMembershipToggles(lists: customLists,
                                      isMember: { $0.contains(show.id, .tv) },
                                      toggle: { list in
                                          store?.afterCommit {
                                              store?.toggle(show, in: list); refresh(); onChange()
                                          }
                                      })
            }
            // Stays open so several lists can be toggled in one go.
            .menuActionDismissBehavior(.disabled)
            .glassEffectID("plus", in: glassNamespace)
        }
    }

    // Persisted facts only. Deriving these from `show.regularSeasons` made a stub payload read as
    // unwatched, so the controls flipped once detail loaded, and it cost a fetch per season.
    private func refresh() {
        progress = store?.showProgress(showID: show.id) ?? ShowProgress()
    }
}

#Preview {
    @Previewable @State var progress = ShowProgress()
    let context = previewModelContainer.mainContext
    let watch = MediaList(name: "Watch List", symbol: "bookmark", sortOrder: 0, isWatchList: true)
    let favorites = MediaList(name: "Favorites", symbol: "heart", sortOrder: 1, colorIndex: 2)
    let queued = MediaList(name: "Queued", symbol: "clock", sortOrder: 2, colorIndex: 3)
    context.insert(watch); context.insert(favorites); context.insert(queued)

    return ShowActionBar(show: .preview, lists: [watch, favorites, queued],
                         tint: .appAccent, progress: $progress)
        .padding()
        .background(Color.appBackground)
        .modelContainer(previewModelContainer)
        .environment(PersistenceCoordinator(context))
        .preferredColorScheme(.dark)
}
