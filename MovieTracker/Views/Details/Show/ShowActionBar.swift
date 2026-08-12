//
//  ShowActionBar.swift
//  MovieTracker
//

import SwiftUI
import SwiftData

/// The Liquid Glass controls beside the show poster: bookmark, checkmark (confirm-first),
/// custom lists, trailer. Mirrors ``MovieActionBar`` over the coordinator's Show overloads.
struct ShowActionBar: View {
    let show: Show
    let lists: [MediaList]
    let tint: Color
    /// Loaded episodes per season number, so marking the whole show watched can date each
    /// season to its finale rather than today.
    var episodesBySeason: [Int: [Episode]] = [:]
    @Binding var isSeen: Bool
    /// Refine list membership after a mutation (advance the tracked season, precise
    /// next-episode date) — supplied by the detail screen, which can load episodes.
    var onChange: () -> Void = {}

    @Environment(PersistenceCoordinator.self) private var store: PersistenceCoordinator?
    @Namespace private var glassNamespace
    @State private var tracked = false
    @State private var hasProgress = false
    @State private var caughtUp = false
    @State private var wasOnWatchList = false
    @State private var showRemoveConfirm = false
    // Gate the watched animation so the first sync (entry) settles instantly; only
    // user-driven changes after appearance animate the bookmark↔checkmark transition.
    @State private var didAppear = false

    private var canonical: [MediaList] { store?.canonicalLists(lists) ?? lists }
    private var watchList: MediaList? { canonical.first { $0.isWatchList } }
    private var customLists: [MediaList] { canonical.filter { !$0.isWatchList } }

    var body: some View {
        GlassEffectContainer(spacing: ActionBarMetrics.spacing) {
            HStack(spacing: ActionBarMetrics.spacing) {
                if !isSeen {
                    bookmarkButton
                }
                ShowWatchedButton(isSeen: isSeen, isCaughtUp: caughtUp, isOngoing: show.isOngoing,
                                  tint: tint, glassNamespace: glassNamespace, onApply: applyWatched)
                customListsControl
                TrailerButton(trailer: show.primaryTrailer, tint: tint)
            }
        }
        .animation(didAppear ? .spring(response: 0.4, dampingFraction: 0.8) : nil, value: isSeen)
        .animation(didAppear ? .easeInOut : nil, value: caughtUp)
        .onAppear {
            refresh()
            didAppear = true
        }
        // Caught-up needs the season's episodes to date-check, and they arrive lazily.
        .onChange(of: episodesBySeason.count) { refresh() }
        // Re-sync when episodes are toggled elsewhere: unwatching one pulls a finished show
        // back onto the Watch List, so the bookmark that reappears must read as on.
        .onChange(of: store?.revision) { refresh() }
    }

    private var bookmarkButton: some View {
        GlassActionButton(systemName: tracked ? "bookmark.fill" : "bookmark", isOn: tracked,
                          shape: Circle(), tint: tint) {
            handleBookmarkTap()
        }
        .glassEffectID("bookmark", in: glassNamespace)
        .glassEffectTransition(.matchedGeometry)
        .confirmationDialog("Remove from Watch List?", isPresented: $showRemoveConfirm,
                            titleVisibility: .visible) {
            Button("Remove", role: .destructive) {
                store?.dismissFromWatchList(show)
                refresh()
                onChange()
            }
        } message: {
            Text("You've watched some episodes, so it stays on your Watch List automatically. Removing keeps it off until you add it back.")
        }
    }

    // An in-progress show is auto-kept on the Watch List — removing it takes a confirmation
    // (and sticks). Adding it back is a plain tap that re-tracks the next-episode season.
    private func handleBookmarkTap() {
        guard let store else { return }
        if tracked {
            if hasProgress {
                showRemoveConfirm = true
            } else {
                store.toggleWatchList(show)
                refresh()
                onChange()
            }
        } else {
            if hasProgress {
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
                wasOnWatchList = tracked
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
                                      toggle: { store?.toggle(show, in: $0); refresh(); onChange() })
            }
            // Stays open so several lists can be toggled in one go.
            .menuActionDismissBehavior(.disabled)
            .glassEffectID("plus", in: glassNamespace)
        }
    }

    private func refresh() {
        tracked = watchList?.contains(show.id, .tv) ?? false
        hasProgress = store?.hasWatchedEpisodes(show) ?? false
        isSeen = store?.isShowFullyWatched(show) ?? false
        caughtUp = store?.isShowCaughtUp(show, episodesBySeason: episodesBySeason) ?? false
    }
}

// Interactive: tap Watched to confirm and watch the pill span, or bookmark/list live.
#Preview {
    @Previewable @State var isSeen = false
    let context = previewModelContainer.mainContext
    let watch = MediaList(name: "Watch List", symbol: "bookmark", sortOrder: 0, isWatchList: true)
    let favorites = MediaList(name: "Favorites", symbol: "heart", sortOrder: 1, colorIndex: 2)
    let queued = MediaList(name: "Queued", symbol: "clock", sortOrder: 2, colorIndex: 3)
    context.insert(watch); context.insert(favorites); context.insert(queued)

    return ShowActionBar(show: .preview, lists: [watch, favorites, queued],
                         tint: .appAccent, isSeen: $isSeen)
        .padding()
        .background(Color.appBackground)
        .modelContainer(previewModelContainer)
        .environment(PersistenceCoordinator(context))
        .preferredColorScheme(.dark)
}
