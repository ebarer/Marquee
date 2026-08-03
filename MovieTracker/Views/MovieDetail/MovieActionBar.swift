//
//  MovieActionBar.swift
//  MovieTracker
//

import SwiftUI
import SwiftData

/// The Liquid Glass controls beside the poster: bookmark (Watch List), checkmark
/// (Watched), a custom-lists control, and a trailer play button. Marking Watched
/// absorbs the bookmark into a pill spanning both slots.
struct MovieActionBar: View {
    let movie: Movie
    let lists: [MediaList]
    let tint: Color
    @Binding var isSeen: Bool

    @Environment(MediaStore.self) private var store: MediaStore?
    @Namespace private var glassNamespace
    @State private var tracked = false
    @State private var wasOnWatchList = false
    @State private var showListPicker = false
    @State private var selectedTrailer: MovieTrailer?

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
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isSeen)
        .onAppear(perform: refresh)
        .fullScreenCover(item: $selectedTrailer) { trailer in
            NavigationStack {
                TrailerPlayerView(trailer: trailer) { selectedTrailer = nil }
                    // Black fills the edges so the YouTube page looks intentional
                    // if the user leaves fullscreen.
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
            store?.toggleWatchList(movie)
            refresh()
        }
        .glassEffectID("bookmark", in: glassNamespace)
        .glassEffectTransition(.matchedGeometry)
    }

    private var watchedButton: some View {
        // Unmarking Watched restores the movie to the Watch List only if it was
        // there beforehand.
        glassButton(system: "checkmark", isOn: isSeen,
                    width: isSeen ? Self.size * 2 + Self.spacing : Self.size,
                    shape: Capsule()) {
            if isSeen {
                store?.setWatched(false, for: movie)
                if wasOnWatchList { store?.addToWatchList(movie) }
            } else {
                wasOnWatchList = tracked
                store?.setWatched(true, for: movie)
            }
            refresh()
        }
        .glassEffectID("watched", in: glassNamespace)
    }

    /// Hidden with no custom lists; a direct toggle for a single list; a popover
    /// menu for several.
    @ViewBuilder
    private var customListsControl: some View {
        if customLists.count == 1, let list = customLists.first {
            let member = list.contains(movie.id)
            glassButton(system: member ? filledSymbol(list.symbol) : list.symbol,
                        isOn: member, shape: Circle()) {
                store?.toggle(movie, in: list)
                refresh()
            }
            .glassEffectID("plus", in: glassNamespace)
        } else if !customLists.isEmpty {
            glassButton(system: "plus", isOn: false, shape: Circle()) {
                showListPicker = true
            }
            .glassEffectID("plus", in: glassNamespace)
            // Anchor above the button so the cartouche beak doesn't crowd it.
            .popover(isPresented: $showListPicker,
                     attachmentAnchor: .rect(.rect(CGRect(
                        x: 0, y: -8, width: Self.size, height: Self.size)))) {
                ListPickerPopover(movie: movie, lists: customLists, tint: tint)
            }
        }
    }

    @ViewBuilder
    private var trailerButton: some View {
        if let trailer = movie.primaryTrailer {
            glassButton(system: "play.fill", isOn: false, shape: Circle()) {
                selectedTrailer = trailer
            }
        }
    }

    private func refresh() {
        tracked = watchList?.contains(movie.id) ?? false
        isSeen = store?.isWatched(movie) ?? false
    }

    /// The `.fill` variant of a symbol when one exists, else the base name.
    private func filledSymbol(_ base: String) -> String {
        let candidate = base + ".fill"
        return UIImage(systemName: candidate) != nil ? candidate : base
    }

    private func glassButton(system: String, isOn: Bool, width: CGFloat = MovieActionBar.size,
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

/// A tap-anywhere-to-toggle list of custom lists shown as a popover. Unlike a
/// `Menu` it stays open so several lists can be toggled in a row.
private struct ListPickerPopover: View {
    let movie: Movie
    let lists: [MediaList]
    let tint: Color

    @Environment(MediaStore.self) private var store: MediaStore?
    @State private var contentHeight: CGFloat = 0
    private static let maxHeight: CGFloat = 320

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(lists) { list in
                    let member = list.contains(movie.id)
                    Button {
                        store?.toggle(movie, in: list)
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

#Preview("Unseen") {
    MovieActionBar(movie: .preview, lists: [], tint: .appAccent, isSeen: .constant(false))
        .padding()
        .background(Color.appBackground)
        .modelContainer(previewModelContainer)
        .environment(MediaStore(previewModelContainer.mainContext))
}

#Preview("Seen") {
    MovieActionBar(movie: .preview, lists: [], tint: .appAccent, isSeen: .constant(true))
        .padding()
        .background(Color.appBackground)
        .modelContainer(previewModelContainer)
        .environment(MediaStore(previewModelContainer.mainContext))
}
