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

    @Environment(\.closeModal) private var closeModal
    @Environment(\.isModalRoot) private var isModalRoot

    @Namespace private var photoNamespace
    @State private var showPhoto = false
    @State private var showNavTitle = false
    @State private var navBarBottom: CGFloat = 0
    /// Remembered across people and launches; talk-show and courtesy credits are the default
    /// selection, so an untouched filter behaves as it always has.
    @AppStorage("personCreditFilter") private var filter = CreditFilter()
    @State private var filterButtonHidden = false

    private let bioHeaderID = "personBioHeader"

    private var current: Person { model.person ?? person }
    private var entries: [FilmographyEntry] {
        FilmographyEntry.entries(for: current.allCredits, episodeCredits: model.episodeCredits)
    }
    private var availableKinds: [CreditKind] { CreditKind.present(in: current.allCredits) }
    private var isFiltering: Bool { availableKinds.contains(where: filter.hides) }

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
                            // header back into view rather than leaving a meaningless offset.
                            withAnimation(.easeInOut) { proxy.scrollTo(bioHeaderID, anchor: .top) }
                        }
                    )
                    .id(bioHeaderID)
                    .padding(16)

                    knownForSection

                    PersonFilmography(entries: entries, lists: lists,
                                      filter: $filter,
                                      isResolving: model.isResolvingCredits,
                                      navBarBottom: navBarBottom,
                                      onFilterHiddenChange: { hidden in
                                          withAnimation(.easeInOut(duration: 0.2)) {
                                              filterButtonHidden = hidden
                                          }
                                      })
                }
                .padding(.bottom, 24)
            }
        }
        .swipeActionsContainerIfAvailable()
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
            if filterButtonHidden && availableKinds.count > 1 {
                ToolbarItem(placement: .topBarTrailing) {
                    // State lives in the symbol: `.glassProminent` rendered identically either
                    // way, leaving a tap looking like it did nothing.
                    CreditFilterMenu(kinds: availableKinds, filter: $filter) {
                        Image(systemName: isFiltering
                              ? "line.3.horizontal.decrease.circle.fill"
                              : "line.3.horizontal.decrease")
                    }
                    .tint(.appAccent)
                }

                ToolbarSpacer(.fixed)
            }
            // Declared here, after the filter, so Close stays the rightmost item.
            if let closeModal {
                ModalCloseItem(close: closeModal, isRoot: isModalRoot)
            }
        }
        .background {
            // The scroll view sits below the nav bar, so its global top edge is the nav bar's
            // bottom edge — the threshold the header compares against.
            GeometryReader { proxy in
                Color.clear
                    .onAppear { navBarBottom = proxy.frame(in: .global).minY }
                    .onChange(of: proxy.frame(in: .global).minY) { _, newValue in
                        navBarBottom = newValue
                    }
            }
        }
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
