//
//  ShowActionBar.swift
//  MovieTracker
//

import SwiftUI
import SwiftData

/// The Liquid Glass controls beside the show poster — bookmark (Watch List), checkmark
/// (Watched, confirm-first via `ShowWatchedButton`), a custom-lists control, and a trailer
/// button. Mirrors `MovieActionBar`, writing through the `PersistenceCoordinator` Show
/// overloads (list membership and watched/rating reuse `MediaItem`/`ListEntry` with `.tv`).
struct ShowActionBar: View {
    let show: Show
    let lists: [MediaList]
    let tint: Color
    @Binding var isSeen: Bool
    /// Refine list membership after a mutation (advance the tracked season, precise
    /// next-episode date) — supplied by the detail screen, which can load episodes.
    var onChange: () -> Void = {}

    @Environment(PersistenceCoordinator.self) private var store: PersistenceCoordinator?
    @Namespace private var glassNamespace
    @State private var tracked = false
    @State private var wasOnWatchList = false
    @State private var showListPicker = false
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
                ShowWatchedButton(isSeen: isSeen, tint: tint, glassNamespace: glassNamespace,
                                  onApply: applyWatched)
                customListsControl
                TrailerButton(trailer: show.primaryTrailer, tint: tint)
            }
        }
        .animation(didAppear ? .spring(response: 0.4, dampingFraction: 0.8) : nil, value: isSeen)
        .onAppear {
            refresh()
            didAppear = true
        }
    }

    private var bookmarkButton: some View {
        GlassActionButton(systemName: tracked ? "bookmark.fill" : "bookmark", isOn: tracked,
                          shape: Circle(), tint: tint) {
            store?.toggleWatchList(show)
            refresh()
            onChange()
        }
        .glassEffectID("bookmark", in: glassNamespace)
        .glassEffectTransition(.matchedGeometry)
    }

    private func applyWatched(_ watched: Bool) {
        if watched {
            wasOnWatchList = tracked
            store?.setShowWatched(true, show: show)
        } else {
            store?.setShowWatched(false, show: show)
            if wasOnWatchList { store?.addToWatchList(show) }
        }
        refresh()
        onChange()
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
            GlassActionButton(systemName: "plus", isOn: anyMember, shape: Circle(), tint: tint) {
                showListPicker = true
            }
            .glassEffectID("plus", in: glassNamespace)
            .popover(isPresented: $showListPicker,
                     attachmentAnchor: .rect(.rect(CGRect(
                        x: 0, y: -8, width: ActionBarMetrics.size, height: ActionBarMetrics.size)))) {
                ListPickerPopover(lists: customLists, tint: tint,
                                  isMember: { $0.contains(show.id, .tv) },
                                  toggle: { store?.toggle(show, in: $0); onChange() })
            }
        }
    }

    private func refresh() {
        tracked = watchList?.contains(show.id, .tv) ?? false
        isSeen = store?.isShowFullyWatched(show) ?? false
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
