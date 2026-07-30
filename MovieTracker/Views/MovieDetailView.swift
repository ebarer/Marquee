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

@MainActor
@Observable
final class MovieDetailModel {
    private(set) var movie: Movie?
    private(set) var tint: Color = .appAccent

    private var loaded = false

    func load(id: Int) async {
        guard !loaded else { return }
        loaded = true
        do {
            let full = try await TMDBWrapper.getMovie(id: id)
            movie = full
            if let url = full.posterURL(.w342),
               let data = try? await TMDBWrapper.imageData(from: url) {
                tint = Color.averageColor(from: data)
            }
        } catch {
            print("Movie detail load error: \(error)")
        }
    }
}

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
    @State private var model = MovieDetailModel()
    @Namespace private var zoomNamespace
    @State private var showPoster = false
    @State private var selectedTrailer: MovieTrailer?
    @State private var overviewExpanded = false
    @State private var showNavTitle = false
    @State private var tracked = false
    @State private var seen = false

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
            // Initialize the Track/Seen state from the persisted Watch List entry.
            let entry = WatchListStore.entry(for: movieID, in: context)
            tracked = entry?.tracked ?? false
            seen = entry?.watched ?? false
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

    private func actionButtons(movie: Movie) -> some View {
        HStack(spacing: 8) {
            Button {
                tracked.toggle()
                WatchListStore.setTracked(tracked, for: movie, in: context)
            } label: {
                Label(tracked ? "Tracking" : "Track", systemImage: tracked ? "bookmark.fill" : "bookmark")
            }
            .buttonStyle(.bordered)
            .disabled(seen)
            .opacity(seen ? 0.4 : 1)

            seenButton(movie: movie)
        }
        .controlSize(.small)
        .buttonBorderShape(.capsule)
        .font(.subheadline)
    }

    @ViewBuilder
    private func seenButton(movie: Movie) -> some View {
        let label = Label("Seen", systemImage: seen ? "checkmark.circle.fill" : "checkmark.circle")
        let toggle = {
            seen.toggle()
            // Marking seen clears the tracked state (the store enforces the same rule).
            if seen { tracked = false }
            WatchListStore.setWatched(seen, for: movie, in: context)
        }
        // Prominent when seen, bordered otherwise (the two styles are distinct types,
        // so they can't share a ternary).
        if seen {
            Button(action: toggle) { label }.buttonStyle(.borderedProminent)
        } else {
            Button(action: toggle) { label }.buttonStyle(.bordered)
        }
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

// MARK: - Metadata card strip

private struct MovieMetadataStrip: View {
    let movie: Movie

    var body: some View {
        VStack(spacing: 0) {
            hairline
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 0) {
                    cell(header: "RATING") {
                        if let cert = movie.certification, let image = UIImage(named: "Cert-\(cert)") {
                            Image(uiImage: image)
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 24)
                                .foregroundStyle(.white)
                        } else {
                            valueText("N/A")
                        }
                    }
                    divider
                    cell(header: "CREDIT CLIPS") { valueText(movie.bonusString) }
                    divider
                    cell(header: "TMDB.org") { valueText(tmdbScore) }
                    divider
                    cell(header: "GENRE") { valueText(movie.genresString) }
                }
            }
            // Always allow elastic scrolling, even when the cells fit within the width.
            .scrollBounceBehavior(.always, axes: .horizontal)
            hairline
        }
    }

    private var tmdbScore: String {
        if let rating = movie.rating, rating > 0 {
            return String(format: "%.1f / 5", rating / 2)
        }
        return "N/A"
    }

    // Equal-width column: title label at the top, value beneath it.
    private func cell<Content: View>(header: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 10) {
            Text(header)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            content()
                .font(.system(size: 14))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
        }
        .frame(width: 104, alignment: .top)
        .padding(.vertical, 14)
    }

    private func valueText(_ text: String) -> some View {
        Text(text).multilineTextAlignment(.center)
    }

    // Full-width top/bottom rule.
    private var hairline: some View {
        Rectangle()
            .fill(Color.appSeparator)
            .frame(height: 0.5)
    }

    // Vertical rule between columns. Inset top/bottom by the same amount as the cell's vertical
    // text padding so it doesn't touch the top/bottom hairlines.
    private var divider: some View {
        Rectangle()
            .fill(Color.appSeparator)
            .frame(width: 0.5)
            .frame(maxHeight: .infinity)
            .padding(.vertical, 14)
    }
}
