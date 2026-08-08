//
//  ShowActionBar.swift
//  MovieTracker
//

import SwiftUI
import SwiftData

/// The Liquid Glass controls beside the show poster — bookmark (Watch List),
/// checkmark (Watched), a custom-lists control, and a trailer button. Mirrors
/// `MovieActionBar`, writing through the `PersistenceCoordinator` Show overloads
/// (list membership and watched/rating reuse `MediaItem`/`ListEntry` with `.tv`).
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
    @State private var selectedTrailer: MovieTrailer?
    /// Non-nil while a mark-all-watched (true) / unmark-all (false) confirmation is pending.
    @State private var pendingWatched: Bool?
    /// Gate the watched animation so the first sync (entry) settles instantly; only
    /// user-driven changes after appearance animate the bookmark↔checkmark transition.
    @State private var didAppear = false

    private static let size: CGFloat = 52
    private static let spacing: CGFloat = 12

    private var canonical: [MediaList] { store?.canonicalLists(lists) ?? lists }
    private var watchList: MediaList? { canonical.first { $0.isWatchList } }
    private var customLists: [MediaList] { canonical.filter { !$0.isWatchList } }

    var body: some View {
        GlassEffectContainer(spacing: Self.spacing) {
            HStack(spacing: Self.spacing) {
                if !isSeen {
                    bookmarkButton
                }
                watchedButton
                customListsControl
                trailerButton
            }
        }
        .animation(didAppear ? .spring(response: 0.4, dampingFraction: 0.8) : nil, value: isSeen)
        .onAppear {
            refresh()
            didAppear = true
        }
        .fullScreenCover(item: $selectedTrailer) { trailer in
            NavigationStack {
                TrailerPlayerView(trailer: trailer) { selectedTrailer = nil }
                    .background(Color.black.ignoresSafeArea())
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button(role: .close) { selectedTrailer = nil }
                        }
                    }
            }
        }
    }

    private var bookmarkButton: some View {
        glassButton(system: tracked ? "bookmark.fill" : "bookmark", isOn: tracked, shape: Circle()) {
            store?.toggleWatchList(show)
            refresh()
            onChange()
        }
        .glassEffectID("bookmark", in: glassNamespace)
        .glassEffectTransition(.matchedGeometry)
    }

    private var watchedButton: some View {
        glassButton(system: "checkmark", isOn: isSeen,
                    width: isSeen ? Self.size * 2 + Self.spacing : Self.size,
                    shape: Capsule()) {
            pendingWatched = !isSeen
        }
        .glassEffectID("watched", in: glassNamespace)
        .confirmationDialog(
            pendingWatched == true ? "Mark all seasons as watched?" : "Mark all seasons as unwatched?",
            isPresented: Binding(get: { pendingWatched != nil },
                                 set: { if !$0 { pendingWatched = nil } }),
            titleVisibility: .visible) {
            if pendingWatched == true {
                Button("Mark Watched") { applyWatched(true) }
            } else {
                Button("Mark Unwatched", role: .destructive) { applyWatched(false) }
            }
            Button("Cancel", role: .cancel) { pendingWatched = nil }
        }
    }

    private func applyWatched(_ watched: Bool) {
        if watched {
            wasOnWatchList = tracked
            store?.setShowWatched(true, show: show)
        } else {
            store?.setShowWatched(false, show: show)
            if wasOnWatchList { store?.addToWatchList(show) }
        }
        pendingWatched = nil
        refresh()
        onChange()
    }

    @ViewBuilder
    private var customListsControl: some View {
        if customLists.count == 1, let list = customLists.first {
            let member = list.contains(show.id, .tv)
            glassButton(system: member ? filledSymbol(list.symbol) : list.symbol,
                        isOn: member, shape: Circle()) {
                store?.toggle(show, in: list)
                refresh()
                onChange()
            }
            .glassEffectID("plus", in: glassNamespace)
        } else if !customLists.isEmpty {
            let anyMember = customLists.contains { $0.contains(show.id, .tv) }
            glassButton(system: "plus", isOn: anyMember, shape: Circle()) {
                showListPicker = true
            }
            .glassEffectID("plus", in: glassNamespace)
            .popover(isPresented: $showListPicker,
                     attachmentAnchor: .rect(.rect(CGRect(
                        x: 0, y: -8, width: Self.size, height: Self.size)))) {
                ShowListPickerPopover(show: show, lists: customLists, tint: tint, onChange: onChange)
            }
        }
    }

    @ViewBuilder
    private var trailerButton: some View {
        if let trailer = show.primaryTrailer {
            glassButton(system: "play.fill", isOn: false, shape: Circle()) {
                selectedTrailer = trailer
            }
        }
    }

    private func refresh() {
        tracked = watchList?.contains(show.id, .tv) ?? false
        isSeen = store?.isShowFullyWatched(show) ?? false
    }

    private func filledSymbol(_ base: String) -> String {
        let candidate = base + ".fill"
        return UIImage(systemName: candidate) != nil ? candidate : base
    }

    private func glassButton(system: String, isOn: Bool, width: CGFloat = ShowActionBar.size,
                             shape: some Shape, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(isOn ? .appBackground : tint)
                .frame(width: width, height: Self.size)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .glassEffect(isOn ? .regular.tint(tint).interactive() : .regular.interactive(), in: shape)
    }
}

/// Tap-anywhere-to-toggle custom-list popover for a show (parallels the movie one).
private struct ShowListPickerPopover: View {
    let show: Show
    let lists: [MediaList]
    let tint: Color
    var onChange: () -> Void = {}

    @Environment(PersistenceCoordinator.self) private var store: PersistenceCoordinator?
    @State private var contentHeight: CGFloat = 0
    private static let maxHeight: CGFloat = 320

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(lists) { list in
                    let member = list.contains(show.id, .tv)
                    Button {
                        store?.toggle(show, in: list)
                        onChange()
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
    let watch = MediaList(name: "Watch List", symbol: "bookmark", sortOrder: 0, isWatchList: true)
    let favorites = MediaList(name: "Favorites", symbol: "heart", sortOrder: 1, colorIndex: 2)
    let queued = MediaList(name: "Queued", symbol: "clock", sortOrder: 2, colorIndex: 3)
    context.insert(watch); context.insert(favorites); context.insert(queued)

    return ShowActionBar(show: .preview, lists: [watch, favorites, queued],
                         tint: .appAccent, isSeen: .constant(false))
        .padding()
        .background(Color.appBackground)
        .modelContainer(previewModelContainer)
        .environment(PersistenceCoordinator(context))
        .preferredColorScheme(.dark)
}
