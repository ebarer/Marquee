//
//  PersonDetailView.swift
//  MovieTracker
//
//  SwiftUI person detail screen: a biography header (profile, name + age,
//  expandable bio) and a filmography grouped into per-year sections. The
//  nav-bar title stays hidden until the on-page name scrolls up behind the
//  bar. Replaces the storyboard PersonDetailViewController.
//
//  Built on a ScrollView + LazyVStack (matching the movie detail screen's
//  Cast & Crew list) rather than a `List`, so the expandable bio grows and
//  shrinks smoothly — a `List` disturbs its scroll offset whenever a row's
//  height animates. Row swipe actions still work via `swipeActionsContainer()`.
//

import SwiftUI
import SwiftData

struct PersonDetailView: View {
    let person: Person

    @State private var model = PersonDetailModel()
    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor(\MovieList.sortOrder), SortDescriptor(\MovieList.createdAt)])
    private var lists: [MovieList]

    /// Zoom transition namespace + presentation flag for the full-screen profile
    /// photo viewer (the same viewer used for movie posters).
    @Namespace private var photoNamespace
    @State private var showPhoto = false

    /// Reveal the nav-bar title only once the on-page name is hidden behind it.
    @State private var showNavTitle = false
    /// Global Y of the nav bar's bottom edge (the scroll view's top), fed to the header.
    @State private var navBarBottom: CGFloat = 0

    /// When on, hides "Self" (talk-show) and "Thanks" credits from the filmography.
    /// On by default so the filmography leads with actual roles.
    @State private var hideExtraneous = true

    /// Scroll target for re-anchoring to the header when the bio collapses.
    private let bioHeaderID = "personBioHeader"

    private var current: Person { model.person ?? person }
    private var watchList: MovieList? { lists.first { $0.kind == .toWatch } }
    private var watchedList: MovieList? { lists.first { $0.kind == .watched } }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    PersonBioHeader(
                        person: current,
                        photoNamespace: photoNamespace,
                        onPhotoTap: { if current.profilePicture != nil { showPhoto = true } },
                        navBarBottom: navBarBottom,
                        onNameHiddenChange: { hidden in
                            withAnimation(.easeInOut(duration: 0.2)) { showNavTitle = hidden }
                        },
                        onBioCollapsed: {
                            // Collapsing removes the tall bio from above the fold; bring the
                            // header back into view so the reader isn't dropped into the
                            // filmography, rather than keeping a now-meaningless offset.
                            withAnimation(.easeInOut) { proxy.scrollTo(bioHeaderID, anchor: .top) }
                        }
                    )
                    .id(bioHeaderID)
                    .padding(16)

                    knownForSection

                    if !creditsByYear.isEmpty {
                        filmographyHeader
                        ForEach(creditsByYear, id: \.year) { group in
                            SectionHeader(title: yearTitle(group.year), color: .appAccent)
                            ForEach(Array(group.movies.enumerated()), id: \.element.id) { index, movie in
                                filmographyRow(movie)
                                if index < group.movies.count - 1 {
                                    // Separator between rows, inset to start under the title (past the poster).
                                    Rectangle()
                                        .fill(Color.appSeparator)
                                        .frame(height: 0.5)
                                        .padding(.leading, 79)
                                }
                            }
                        }
                    }
                }
                .padding(.bottom, 24)
            }
        }
        .swipeActionsContainer()
        .background(Color.appBackground)
        .navigationTitle(current.name)
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(current.name)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .opacity(showNavTitle ? 1 : 0)
            }
        }
        .background {
            // The scroll view sits below the nav bar, so its global top edge is
            // the nav bar's bottom edge — the threshold the header compares against.
            GeometryReader { proxy in
                Color.clear
                    .onAppear { navBarBottom = proxy.frame(in: .global).minY }
                    .onChange(of: proxy.frame(in: .global).minY) { _, newValue in
                        navBarBottom = newValue
                    }
            }
        }
        .fullScreenCover(isPresented: $showPhoto) {
            // The zoom transition is applied to the image inside PosterDetailView (not
            // here), so the source profile photo morphs into the enlarged image.
            PosterDetailView(imageURL: current.profileURL(.orig),
                             zoomSourceID: current.id, zoomNamespace: photoNamespace)
        }
        .task {
            await model.load(id: person.id)
        }
    }

    // MARK: - Known For

    @ViewBuilder
    private var knownForSection: some View {
        let knownFor = Array(current.knownFor.prefix(10))
        if !knownFor.isEmpty {
            SectionHeader(title: "Known For")
            PosterStrip(movies: knownFor, lists: lists, context: context)
        }
    }

    // MARK: - Filmography rows

    /// A single filmography row, styled like the movie detail Cast & Crew list:
    /// a plain navigation row with a trailing chevron, carrying the shared swipe
    /// actions and long-press menu.
    private func filmographyRow(_ movie: Movie) -> some View {
        NavigationLink(value: movie) {
            HStack(spacing: 8) {
                MovieRow(movie: movie, role: movie.creditRole)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            WatchedSwipeButton(movie: movie, watchedList: watchedList, context: context)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            WatchListSwipeButton(movie: movie, watchList: watchList, context: context)
        }
        .movieContextMenu(for: movie, lists: lists, context: context)
    }

    /// The "Filmography" section header, matching the "Known For" style, with the
    /// Self/Thanks filter toggle inline on the trailing side (shown only when the
    /// person actually has such credits to filter).
    private var filmographyHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Filmography")
                .font(.headline)
                .foregroundStyle(.white)
            Spacer(minLength: 8)
            if hasExtraneousCredits {
                Button {
                    withAnimation(.easeInOut) { hideExtraneous.toggle() }
                } label: {
                    Image(systemName: hideExtraneous
                          ? "line.3.horizontal.decrease.circle.fill"
                          : "line.3.horizontal.decrease.circle")
                        .font(.title3)
                }
                .tint(.appAccent)
                .accessibilityLabel(hideExtraneous ? "Show all credits" : "Hide Self and Thanks credits")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 4)
    }

    // MARK: - Filmography grouping

    /// True when the person has any "Self"/"Thanks" credits — i.e. when the
    /// filter toggle is worth showing.
    private var hasExtraneousCredits: Bool {
        (current.credits ?? []).contains { $0.isExtraneousCredit }
    }

    /// The credits shown in the filmography, honoring the "hide Self/Thanks" filter.
    private var visibleCredits: [Movie] {
        let credits = current.credits ?? []
        return hideExtraneous ? credits.filter { !$0.isExtraneousCredit } : credits
    }

    /// The visible credits grouped into consecutive per-year buckets. Credits
    /// arrive already sorted newest-first, so grouping in order yields sections
    /// in descending year order with undated (upcoming) credits last.
    private var creditsByYear: [(year: Int?, movies: [Movie])] {
        let credits = visibleCredits
        var groups: [(year: Int?, movies: [Movie])] = []
        for movie in credits {
            let year = movie.releaseDate.map { Calendar.current.component(.year, from: $0) }
            if let index = groups.indices.last, groups[index].year == year {
                groups[index].movies.append(movie)
            } else {
                groups.append((year: year, movies: [movie]))
            }
        }
        return groups
    }

    private func yearTitle(_ year: Int?) -> String {
        guard let year else { return "Upcoming" }
        return String(year)
    }
}

#Preview {
    NavigationStack {
        PersonDetailView(person: .preview)
            .movieTrackerDestinations()
    }
    .modelContainer(previewModelContainer)
    .preferredColorScheme(.dark)
}
