//
//  PersonDetailView.swift
//  MovieTracker
//

import SwiftUI
import SwiftData

// A ScrollView + LazyVStack (not a List) so the expandable bio animates its height without
// disturbing scroll offset; the reader scrolls back to the header on collapse.
struct PersonDetailView: View {
    let person: Person

    @State private var model = PersonDetailModel()
    @Query(sort: [SortDescriptor(\MediaList.sortOrder), SortDescriptor(\MediaList.createdAt)])
    private var lists: [MediaList]

    @Namespace private var photoNamespace
    @State private var showPhoto = false
    @State private var headerPinned = false
    @State private var overscroll: CGFloat = 0
    // The page's top edge in window coordinates. A sheet sits inset in the window, so a bare
    // `.global` reading would count the sheet's offset as nav-bar height.
    @State private var pageTop: CGFloat = 0
    @AppStorage("personCreditFilter") private var filter = CreditFilter()
    @State private var creditSearch: DetailSearchRequest?
    @State private var filterPinned = false

    @ScaledMetric(relativeTo: .title2) private var nameLine: CGFloat = 27
    @ScaledMetric(relativeTo: .subheadline) private var metaLine: CGFloat = 18

    private let headerID = "personHeader"

    private var headerMetrics: PersonHeaderMetrics {
        PersonHeaderMetrics(nameLine: nameLine, metaLine: metaLine)
    }

    private var current: Person { model.person ?? person }

    // Rebuilt only when the credits themselves change: `allCredits` sorts, and the entries sort
    // again, which is far too much for a body pass the scroll drives.
    @State private var filmography: [FilmographyEntry] = []

    private var creditsSignature: [Int] {
        [current.id, current.credits?.count ?? 0, current.tvCredits?.count ?? 0,
         model.episodeCredits.count]
    }

    var body: some View {
        detailContent
            .background(Color.appBackground.ignoresSafeArea())
            // The pinned header carries the name, so the nav bar stays chromeless.
            .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
            .detailChrome(title: current.name, search: creditSearch)
            .fullScreenCover(isPresented: $showPhoto) {
                // The zoom transition is applied inside PosterDetailView, so the source profile
                // photo morphs into the enlarged image.
                PosterDetailView(imageURL: current.profileURL(.orig),
                                 zoomSourceID: current.id, zoomNamespace: photoNamespace)
            }
            .onChange(of: creditsSignature, initial: true) { _, _ in
                filmography = FilmographyEntry.entries(for: current.allCredits,
                                                       episodeCredits: model.episodeCredits)
            }
            .task {
                await model.load(id: person.id)
            }
    }

    private var detailContent: some View {
        GeometryReader { container in
            // This reader sits below the nav bar, so its distance from the page's top edge is the bar's
            // bottom edge: the offset the header's collapsed layout works from.
            let navBarBottom = container.frame(in: .global).minY - pageTop
            let pinLine = navBarBottom + headerMetrics.collapsedExtent

            ScrollViewReader { proxy in
                ScrollView {
                    // First child, high zIndex: the header draws over the sections below it.
                    // Not lazy: a LazyVStack discards the pinned header once its slot scrolls off.
                    VStack(spacing: 0) {
                        pageTopProbe

                        PersonDetailHeader(
                            person: current, metrics: headerMetrics,
                            photoNamespace: photoNamespace,
                            onPhotoTap: { if current.profilePicture != nil { showPhoto = true } },
                            navBarBottom: navBarBottom, overscroll: overscroll,
                            pageHeight: container.size.height, headerPinned: $headerPinned
                        )
                        .id(headerID)
                        .zIndex(1)

                        bio(scrollProxy: proxy)

                        knownForSection

                        PersonFilmography(entries: filmography, lists: lists,
                                          filter: $filter,
                                          isResolving: model.isResolvingCredits,
                                          pinLine: pinLine,
                                          isFilterPinned: filterPinned,
                                          onSearchRequest: { request in
                                              withAnimation(DetailSearch.barHandoff) {
                                                  creditSearch = request
                                              }
                                          },
                                          onFilterPinned: { filterPinned = $0 })
                    }
                    .padding(.bottom, 24)
                }
                .coordinateSpace(name: "scroll")
                .scrollEdgeEffectHidden(!headerPinned, for: .top)
                // Also ignore horizontal safe area, or the content sits inset and the background shows as a
                // trailing gutter.
                .ignoresSafeArea(edges: [.top, .horizontal])
                .onScrollGeometryChange(for: CGFloat.self) { geo in
                    max(0, -(geo.contentOffset.y + geo.contentInsets.top))
                } action: { _, newValue in
                    overscroll = newValue
                }
                // This overlay is aligned to the bar's bottom edge, not the page top `pinLine` is
                // measured from, so it travels the collapsed header's extent alone.
                .overlay(alignment: .top) {
                    pinnedFilter(offset: headerMetrics.collapsedExtent)
                }
            }
        }
        .swipeActionsContainerIfAvailable()
    }

    // The Credits header's filter, held at the line the year headers pin to. A real position rather
    // than a `visualEffect` offset, which moves what is drawn and not what takes the tap.
    @ViewBuilder
    private func pinnedFilter(offset: CGFloat) -> some View {
        let kinds = creditSearch?.filterKinds ?? []
        if filterPinned, !kinds.isEmpty {
            // A row as tall as the year header's title, with the control overlaid: laid out inline,
            // its taller glyph would deepen this row and sit below the year it pins over.
            Text(" ")
                .font(.headline)
                .sectionHeaderInsets()
                .overlay(alignment: .trailing) {
                    CreditFilterMenu(kinds: kinds, filter: $filter) {
                        SectionHeaderFilterGlyph(isOn: kinds.contains(where: filter.hides))
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, SectionHeaderMetrics.horizontal)
                }
                .offset(y: offset)
        }
    }

    // Window position minus scroll-space position is where the page begins.
    // `ignoresSafeArea` widens what the ScrollView draws, not its frame.
    private var pageTopProbe: some View {
        Color.clear
            .frame(height: 0)
            .onGeometryChange(for: CGFloat.self) {
                $0.frame(in: .global).minY - $0.frame(in: .named("scroll")).minY
            } action: { newValue in
                pageTop = newValue
            }
    }

    @ViewBuilder
    private func bio(scrollProxy: ScrollViewProxy) -> some View {
        if let bio = current.bio, !bio.isEmpty {
            ExpandableText(text: bio, lineLimit: 5, font: .body) {
                // Collapsing removes the tall bio from above the fold; bring the header back
                // into view rather than leaving a meaningless offset.
                withAnimation(.easeInOut) { scrollProxy.scrollTo(headerID, anchor: .top) }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    @ViewBuilder
    private var knownForSection: some View {
        let knownFor = Array(current.knownFor.prefix(10))
        if !knownFor.isEmpty {
            SectionHeader(title: "Known For")
            PosterStrip(media: knownFor, lists: lists, showsEpisodeCredits: true)
        }
    }
}

private extension View {
    // `swipeActionsContainer()` requires iOS 27; earlier releases go without it.
    @ViewBuilder
    func swipeActionsContainerIfAvailable() -> some View {
        if #available(iOS 27.0, *) {
            swipeActionsContainer()
        } else {
            self
        }
    }
}

#Preview {
    NavigationStack {
        PersonDetailView(person: .preview)
            .detailSearchHost()
            .detailDestinations()
    }
    .modelContainer(previewModelContainer)
    .environment(PersistenceCoordinator(previewModelContainer.mainContext))
    .preferredColorScheme(.dark)
}
