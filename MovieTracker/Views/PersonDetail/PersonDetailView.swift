//
//  PersonDetailView.swift
//  MovieTracker
//

import SwiftUI
import SwiftData

// A ScrollView + LazyVStack (not a List) so the expandable bio animates its height
// without disturbing scroll offset; swipe actions come from swipeActionsContainer().

struct PersonDetailView: View {
    let person: Person

    @State private var model = PersonDetailModel()
    @Query(sort: [SortDescriptor(\MediaList.sortOrder), SortDescriptor(\MediaList.createdAt)])
    private var lists: [MediaList]

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
    /// True once the filmography's own filter button has scrolled behind the nav
    /// bar, at which point the toolbar shows a stand-in.
    @State private var filterButtonHidden = false

    /// Scroll target for re-anchoring to the header when the bio collapses.
    private let bioHeaderID = "personBioHeader"

    private var current: Person { model.person ?? person }
    private var hasExtraneousCredits: Bool {
        (current.credits ?? []).contains { $0.isExtraneousCredit }
    }

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

                    PersonFilmography(credits: current.credits ?? [], lists: lists,
                                      hideExtraneous: $hideExtraneous,
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
            if filterButtonHidden && hasExtraneousCredits {
                ToolbarItem(placement: .topBarTrailing) {
                    let button = Button {
                        withAnimation(.easeInOut) { hideExtraneous.toggle() }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease")
                    }
                    .accessibilityLabel(hideExtraneous ? "Show all credits" : "Hide Self and Thanks credits")

                    // Active filtering reads as a prominent accent-tinted glass button;
                    // off falls back to the default toolbar glass.
                    if hideExtraneous {
                        button.buttonStyle(.glassProminent).tint(.appAccent)
                    } else {
                        button
                    }
                }
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
            PosterStrip(movies: knownFor, lists: lists)
        }
    }

}

private extension View {
    /// `swipeActionsContainer()` requires iOS 27; on earlier releases the
    /// filmography rows simply go without the swipe container.
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
