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
    // The page's top edge in window coordinates. A sheet sits inset in the window, so a bare
    // `.global` reading would count the sheet's offset as nav-bar height.
    @State private var pageTop: CGFloat = 0
    /// Remembered across people and launches; talk-show and courtesy credits are the default
    /// selection, so an untouched filter behaves as it always has.
    @AppStorage("personCreditFilter") private var filter = CreditFilter()
    /// Set once the credits header scrolls under the pinned header, so its controls carry on
    /// in the bar.
    @State private var hiddenSearch: DetailSearchRequest?

    @ScaledMetric(relativeTo: .title2) private var nameLine: CGFloat = 27
    @ScaledMetric(relativeTo: .subheadline) private var metaLine: CGFloat = 18

    private let headerID = "personHeader"

    private var headerMetrics: PersonHeaderMetrics {
        PersonHeaderMetrics(nameLine: nameLine, metaLine: metaLine)
    }

    private var current: Person { model.person ?? person }
    private var entries: [FilmographyEntry] {
        FilmographyEntry.entries(for: current.allCredits, episodeCredits: model.episodeCredits)
    }
    private var availableKinds: [CreditKind] { CreditKind.present(in: current.allCredits) }
    private var isFiltering: Bool { availableKinds.contains(where: filter.hides) }

    var body: some View {
        detailContent
            .background(Color.appBackground.ignoresSafeArea())
            // The pinned header carries the name, so the nav bar stays chromeless.
            .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
            .detailChrome(title: current.name, hiddenSearch: hiddenSearch, extra: {
                if availableKinds.count > 1 {
                    ToolbarItem(placement: .topBarTrailing) {
                        CreditFilterMenu(kinds: availableKinds, filter: $filter) {
                            Image(systemName: "line.3.horizontal.decrease")
                                .foregroundStyle(isFiltering ? Color.black : .white)
                        }
                        // On the menu rather than its label, so the fill is centred on the item
                        // the bar lays out.
                        .filterOnBadge(isFiltering, size: DetailSearchBar.barItemFill)
                        .tint(.white)
                    }
                }
            })
            .fullScreenCover(isPresented: $showPhoto) {
                // The zoom transition is applied inside PosterDetailView, so the source profile
                // photo morphs into the enlarged image.
                PosterDetailView(imageURL: current.profileURL(.orig),
                                 zoomSourceID: current.id, zoomNamespace: photoNamespace)
            }
            .task {
                await model.load(id: person.id)
            }
    }

    private var detailContent: some View {
        GeometryReader { container in
            // This reader sits below the nav bar, so its distance from the page's top edge is the
            // bar's bottom edge — the offset the header's collapsed layout works from.
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
                            navBarBottom: navBarBottom, headerPinned: $headerPinned
                        )
                        .id(headerID)
                        .zIndex(1)

                        bio(scrollProxy: proxy)

                        knownForSection

                        PersonFilmography(entries: entries, lists: lists,
                                          filter: $filter,
                                          isResolving: model.isResolvingCredits,
                                          pinLine: pinLine,
                                          coveredBelow: container.frame(in: .global).minY
                                              + headerMetrics.collapsedExtent,
                                          onHeaderHiddenChange: { request in
                                              withAnimation(DetailSearch.barHandoff) {
                                                  hiddenSearch = request
                                              }
                                          })
                    }
                    .padding(.bottom, 24)
                }
                .coordinateSpace(name: "scroll")
                .scrollEdgeEffectHidden(!headerPinned, for: .top)
                // Also ignore horizontal safe area — otherwise the content sits inset and the
                // background shows as a trailing gutter.
                .ignoresSafeArea(edges: [.top, .horizontal])
            }
        }
        .swipeActionsContainerIfAvailable()
    }

    /// Zero-height, at the top of the scroll content: window position minus scroll-space position
    /// is where the page begins. `ignoresSafeArea` widens what the ScrollView draws, not its frame.
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
    /// `swipeActionsContainer()` requires iOS 27; earlier releases go without it.
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
            .detailDestinations()
    }
    .modelContainer(previewModelContainer)
    .environment(PersistenceCoordinator(previewModelContainer.mainContext))
    .preferredColorScheme(.dark)
}
