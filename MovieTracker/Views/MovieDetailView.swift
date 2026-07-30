//
//  MovieDetailView.swift
//  MovieTracker
//
//  SwiftUI movie detail screen: a parallax backdrop header that scrolls as
//  one unit (backdrop image stretches on pull-down and scales slightly on
//  scroll-up while the poster/title/actions stay anchored to it), poster
//  average-color tint, Track/Seen actions beside the poster, a metadata
//  card strip, expandable overview, Cast & Crew, and Trailers. Replaces
//  the storyboard MovieDetailViewController.
//

import SwiftUI
import SwiftData

struct MovieDetailView: View {
    /// All that's needed to present the screen: the id to fetch the full movie,
    /// and the title to show while it loads.
    private let movieID: Int
    private let movieTitle: String

    init(movie: Movie) {
        self.movieID = movie.id
        self.movieTitle = movie.title
    }

    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor(\MovieList.sortOrder), SortDescriptor(\MovieList.createdAt)])
    private var lists: [MovieList]
    @State private var model = MovieDetailModel()
    @Namespace private var zoomNamespace
    @Namespace private var glassNamespace
    @State private var showPoster = false
    @State private var selectedTrailer: MovieTrailer?
    @State private var overviewExpanded = false
    @State private var showNavTitle = false
    @State private var tracked = false
    @State private var seen = false
    /// Whether the movie was on the Watch List when it was last marked Watched,
    /// so unmarking Watched can restore it there (and only then).
    @State private var wasOnWatchList = false

    private var toWatchList: MovieList? { lists.first { $0.kind == .toWatch } }
    private var watchedList: MovieList? { lists.first { $0.kind == .watched } }
    private var customLists: [MovieList] { lists.filter { $0.kind == .custom } }

    /// Refreshes the Track/Seen button state from current list membership.
    private func refreshMembership() {
        tracked = toWatchList.map { WatchListStore.isMember(movieID, of: $0) } ?? false
        seen = watchedList.map { WatchListStore.isMember(movieID, of: $0) } ?? false
    }

    // Header layout constants.
    private static let posterHeight: CGFloat = 150
    private static let headerPadding: CGFloat = 16

    var body: some View {
        Group {
            if let movie = model.movie {
                detailContent(movie: movie)
            } else {
                loadingView
            }
        }
        .background(Color.appBackground.ignoresSafeArea())
        .tint(model.tint)
        .navigationTitle(model.movie?.title ?? movieTitle)
        .toolbarTitleDisplayMode(.inline)
        .toolbarBackgroundVisibility(showNavTitle ? .visible : .hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(model.movie?.title ?? movieTitle)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .opacity(showNavTitle ? 1 : 0)
            }
        }
        .fullScreenCover(isPresented: $showPoster) {
            // The zoom transition is applied to the poster inside PosterDetailView (not here),
            // so the source morphs into the poster's frame rather than the whole screen.
            if let movie = model.movie {
                PosterDetailView(movie: movie, tint: model.tint,
                                 zoomSourceID: movie.id, zoomNamespace: zoomNamespace)
            }
        }
        .sheet(item: $selectedTrailer) { trailer in
            if let url = trailer.watchURL {
                SafariView(url: url).ignoresSafeArea()
            }
        }
        .task {
            WatchListStore.ensureDefaultLists(in: context)
            refreshMembership()
            await model.load(id: movieID)
        }
    }

    // MARK: - Loading state

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text(movieTitle)
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Loaded content

    private func detailContent(movie: Movie) -> some View {
        GeometryReader { container in
            // This reader is laid out below the nav bar (it respects the safe area), so its own
            // global top edge IS the nav bar's bottom edge. `safeAreaInsets.top` reports 0 here
            // (the reader already sits inside the safe region), so we can't use it. The ScrollView
            // below ignores the top safe area so the backdrop still draws under the bar.
            let navBarBottom = container.frame(in: .global).minY
            let fullHeight = container.size.height + navBarBottom
            // The backdrop image keeps its natural height; the header is extended below it with
            // solid app-background (the gradient blends the two) so the poster bottom lands near
            // the screen's vertical midpoint without scaling the image up.
            let imageHeight = fullHeight * 0.45
            let headerHeight = fullHeight * 0.54
            let width = container.size.width

            ScrollView {
                VStack(spacing: 0) {
                    header(movie: movie, imageHeight: imageHeight, headerHeight: headerHeight,
                           width: width, navBarBottom: navBarBottom)
                    MovieMetadataStrip(movie: movie)
                        .padding(.vertical, 8)
                    overviewSection(movie: movie)
                    castSection(movie: movie)
                    trailersSection(movie: movie)
                }
                .padding(.bottom, 24)
            }
            .coordinateSpace(name: "scroll")
            // Remove the automatic scroll-edge blur at the top until the title appears,
            // so the bar reads as fully transparent over the backdrop on first presentation.
            .scrollEdgeEffectHidden(!showNavTitle, for: .top)
            .ignoresSafeArea(edges: .top)
        }
    }

    // MARK: - Parallax header (top-pinned, collapses then releases)

    private func header(movie: Movie, imageHeight: CGFloat, headerHeight: CGFloat,
                        width: CGFloat, navBarBottom: CGFloat) -> some View {
        // The backdrop image keeps its natural height and is pinned to the top of the screen; it
        // stretches on pull-down and scales down to a floor on scroll-up. The header extends
        // BELOW the image with solid app-background — the gradient fades the image into it — so
        // the header bottom (and thus the poster) sits lower, near the screen's vertical midpoint,
        // without enlarging the image. The image floor stays taller than the poster/title so
        // nothing clips at the top.
        let minImageHeight = width * 1.25 * 9.0 / 16.0
        let collapseDistance = max(0, imageHeight - minImageHeight)
        let solidExtension = max(0, headerHeight - imageHeight)

        return GeometryReader { proxy in
            let minY = proxy.frame(in: .named("scroll")).minY
            let stretch = max(0, minY)                          // pull-down over-scroll
            let shrink = min(max(0, -minY), collapseDistance)   // scroll-up collapse (capped)
            let currentImageHeight = imageHeight + stretch - shrink
            let currentHeaderHeight = currentImageHeight + solidExtension
            // Pin the top edge while stretching or collapsing; release once fully collapsed.
            let pinOffset = minY > 0 ? -minY : shrink

            ZStack(alignment: .bottomLeading) {
                // Solid extension below the image; the poster/title sit over this region.
                Color.appBackground

                PosterImage(url: movie.backgroundURL())
                    .frame(width: width, height: currentImageHeight)
                    .clipped()
                    .overlay(alignment: .bottom) {
                        // Gradient fades the bottom of the image into the solid app-background.
                        LinearGradient(
                            colors: [.clear, .appBackground],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: min(220, currentImageHeight))
                        .allowsHitTesting(false)
                    }
                    .frame(width: width, height: currentHeaderHeight, alignment: .top)

                headerOverlay(movie: movie, navBarBottom: navBarBottom)
                    .padding(Self.headerPadding)
            }
            .frame(width: width, height: currentHeaderHeight)
            .clipped()
            .offset(y: pinOffset)
        }
        .frame(height: headerHeight)
    }

    private func headerOverlay(movie: Movie, navBarBottom: CGFloat) -> some View {
        HStack(alignment: .bottom, spacing: 12) {
            PosterImage(url: movie.posterURL(.w342))
                .frame(width: 100, height: Self.posterHeight)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(.white.opacity(0.2), lineWidth: 0.5)
                }
                .matchedTransitionSource(id: movie.id, in: zoomNamespace)
                .onTapGesture { showPoster = true }

            VStack(alignment: .leading, spacing: 8) {
                Text(movie.title)
                    .font(.title.bold())
                    .foregroundStyle(.white)
                    .lineLimit(3)
                    .onGeometryChange(for: Bool.self) { proxy in
                        // Reveal the nav-bar title once the on-page title's bottom edge has
                        // crossed above the nav bar's bottom edge — i.e. the on-page title is
                        // fully hidden, so the two titles are never visible at the same time.
                        proxy.frame(in: .global).maxY <= navBarBottom
                    } action: { crossed in
                        withAnimation(.easeInOut(duration: 0.2)) { showNavTitle = crossed }
                    }
                let subtitle = subtitle(for: movie)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(model.tint)
                }
                actionButtons(movie: movie)
            }

            Spacer(minLength: 0)
        }
    }

    private func subtitle(for movie: Movie) -> String {
        var parts: [String] = []
        if let date = movie.releaseDate?.toString() { parts.append(date) }
        if let duration = movie.duration { parts.append(duration) }
        return parts.joined(separator: "  •  ")
    }

    // MARK: - Action buttons (beside the poster)

    private static let actionButtonSize: CGFloat = 52
    private static let actionButtonSpacing: CGFloat = 12

    /// Plus (Watch List) and checkmark (Watched) as Liquid Glass toggles sharing
    /// a container so they metaball together. Marking Watched removes the plus and
    /// morphs the checkmark leftward into a pill spanning both slots.
    private func actionButtons(movie: Movie) -> some View {
        GlassEffectContainer(spacing: Self.actionButtonSpacing) {
            HStack(spacing: Self.actionButtonSpacing) {
                if !seen {
                    // Tap toggles the Watch List; press-and-hold opens the list menu.
                    Menu {
                        listsMenu(movie: movie)
                    } label: {
                        glassIcon(system: tracked ? "bookmark.fill" : "bookmark", isOn: tracked)
                    } primaryAction: {
                        guard let toWatch = toWatchList else { return }
                        WatchListStore.toggle(movie, in: toWatch, in: context)
                        refreshMembership()
                    }
                    .buttonStyle(.plain)
                    .glassEffect(tracked ? .regular.tint(model.tint).interactive() : .regular.interactive(),
                                 in: Circle())
                    .glassEffectID("plus", in: glassNamespace)
                    .glassEffectTransition(.matchedGeometry)
                }

                glassButton(system: "checkmark", isOn: seen,
                            width: seen ? Self.actionButtonSize * 2 + Self.actionButtonSpacing
                                        : Self.actionButtonSize,
                            shape: Capsule()) {
                    // Marking Watched moves the movie off the Watch List. Unmarking
                    // restores it there only if it was on the Watch List beforehand.
                    guard let watched = watchedList else { return }
                    if seen {
                        WatchListStore.remove(movie, from: watched, in: context)
                        if wasOnWatchList, let toWatch = toWatchList {
                            WatchListStore.add(movie, to: toWatch, in: context)
                        }
                    } else {
                        wasOnWatchList = tracked
                        WatchListStore.add(movie, to: watched, in: context)
                    }
                    refreshMembership()
                }
                .glassEffectID("watched", in: glassNamespace)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: seen)
    }

    /// Icon content for a glass action control.
    private func glassIcon(system: String, isOn: Bool,
                           width: CGFloat = MovieDetailView.actionButtonSize) -> some View {
        Image(systemName: system)
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(isOn ? .white : model.tint)
            .frame(width: width, height: Self.actionButtonSize)
            .contentShape(Rectangle())
    }

    /// A Liquid Glass icon toggle, tinted with the poster color when on.
    private func glassButton(system: String, isOn: Bool,
                             width: CGFloat = MovieDetailView.actionButtonSize,
                             shape: some Shape,
                             action: @escaping () -> Void) -> some View {
        Button(action: action) {
            glassIcon(system: system, isOn: isOn, width: width)
        }
        .buttonStyle(.plain)
        .glassEffect(isOn ? .regular.tint(model.tint).interactive() : .regular.interactive(),
                     in: shape)
    }

    /// Long-press menu on the plus: the Watch List up top, a separator, then any
    /// custom lists. Membership shows a checkmark alongside each list's icon.
    private func listsMenu(movie: Movie) -> some View {
        // Watched has its own dedicated toggle above, so it's omitted here.
        ListMembershipMenu(movie: movie, watchList: toWatchList, watchedList: nil,
                           customLists: customLists, context: context,
                           onChange: { refreshMembership() })
    }

    // MARK: - Overview

    @ViewBuilder
    private func overviewSection(movie: Movie) -> some View {
        let overview = movie.overview ?? "No movie description available."
        ZStack(alignment: .bottomTrailing) {
            Text(overview)
                .font(.body)
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(overviewExpanded ? nil : 5)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Inline "… More" at the end of the truncated text, with a gradient behind it
            // that masks the text underneath and blends into the background.
            if !overviewExpanded {
                Text("… \(Text("More").foregroundStyle(model.tint).fontWeight(.semibold))")
                    .foregroundStyle(.white.opacity(0.85))
                    .font(.body)
                .padding(.leading, 44)
                .background(
                    LinearGradient(
                        colors: [Color.appBackground.opacity(0), .appBackground, .appBackground],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut) { overviewExpanded.toggle() }
        }
    }

    // MARK: - Cast & Crew

    @ViewBuilder
    private func castSection(movie: Movie) -> some View {
        if !movie.team.isEmpty {
            sectionHeader("Cast & Crew")
            let members = Array(movie.team.prefix(10))
            LazyVStack(spacing: 0) {
                ForEach(Array(members.enumerated()), id: \.element.id) { index, person in
                    NavigationLink(value: person) {
                        HStack(spacing: 8) {
                            PersonRow(person: person)
                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if index < members.count - 1 {
                        // Separator between members, inset to start under the name (past the avatar).
                        Rectangle()
                            .fill(Color.appSeparator)
                            .frame(height: 0.5)
                            .padding(.leading, 72)
                    }
                }
            }
        }
    }

    // MARK: - Trailers

    @ViewBuilder
    private func trailersSection(movie: Movie) -> some View {
        if let trailers = movie.trailers, !trailers.isEmpty {
            sectionHeader("Trailers")
            LazyVStack(spacing: 0) {
                ForEach(trailers) { trailer in
                    Button {
                        selectedTrailer = trailer
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "play.circle.fill")
                                .font(.title2)
                                .foregroundStyle(model.tint)
                            Text(trailer.title.isEmpty ? trailer.type.rawValue : trailer.title)
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 4)
    }
}

#Preview {
    NavigationStack {
        MovieDetailView(movie: .preview)
    }
    .modelContainer(previewModelContainer)
    .preferredColorScheme(.dark)
}
