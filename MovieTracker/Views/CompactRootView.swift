//
//  CompactRootView.swift
//  MovieTracker
//
//  The compact (iPhone) shell: the three-tab Discover / Lists / Search experience.
//

import SwiftUI
import UIKit

struct CompactRootView: View {
    @Bindable var searchModel: SearchModel

    // Path for the search tab's stack. Watched so that opening a result (which
    // pushes a detail) records the current query as a recent search.
    @State private var searchPath = NavigationPath()

    /// The selected tab, backing the re-tap gesture on Lists.
    @State private var selectedTab: RootTab = .discover
    /// Path for the Lists tab's stack. Watched so a re-tap while a detail is
    /// pushed only pops to root (system behavior); the list reset waits until
    /// we're already at the root.
    @State private var listsPath = NavigationPath()
    /// Bumped when the already-selected Lists tab is tapped again, telling
    /// `ListsView` to jump back to the Watch List.
    @State private var listsResetToken = 0

    var body: some View {
        TabView(selection: tabSelection) {
            Tab("Discover", systemImage: "film", value: RootTab.discover) {
                NavigationStack {
                    FeaturedView()
                        .detailDestinations()
                }
            }

            Tab("Lists", systemImage: "checklist", value: RootTab.lists) {
                NavigationStack(path: $listsPath) {
                    ListsView(resetToken: listsResetToken)
                        .detailDestinations()
                }
            }

            Tab("Search", systemImage: "magnifyingglass", value: RootTab.search, role: .search) {
                NavigationStack(path: $searchPath) {
                    SearchView(model: searchModel, onSelectMovie: openSearchResult)
                        .detailDestinations()
                        // Declare the search field on the content inside the stack
                        // (Apple's recommended placement). On the NavigationStack
                        // itself, a push while the field is focused skipped its
                        // animation; inside, the push animates with the keyboard up.
                        .searchable(text: $searchModel.query, prompt: SearchModel.placeholder)
                        .onChange(of: searchModel.query) { _, newValue in
                            searchModel.search(newValue)
                        }
                        .onSubmit(of: .search) {
                            searchModel.commit()
                        }
                }
                .onChange(of: searchPath) { oldPath, newPath in
                    // Opening a result (pushing onto the stack) counts as
                    // committing the current query to recent searches.
                    if newPath.count > oldPath.count {
                        searchModel.commit()
                    }
                }
            }
        }
        // Selecting the search tab activates its search field (and dismissing
        // search returns to the previously selected tab).
        .tabViewSearchActivation(.searchTabSelection)
    }

    /// Opens a tapped search result: resign the search field's focus first so the
    /// keyboard's collapse doesn't share the push transaction, then push on the next
    /// runloop so the navigation animates even with the keyboard up.
    private func openSearchResult(_ movie: Movie) {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                        to: nil, from: nil, for: nil)
        DispatchQueue.main.async { searchPath.append(movie) }
    }

    /// Drives tab selection while detecting a tap on the already-selected Lists
    /// tab, which resets that screen back to the Watch List.
    private var tabSelection: Binding<RootTab> {
        Binding(get: { selectedTab }) { newValue in
            if newValue == .lists, selectedTab == .lists, listsPath.isEmpty {
                listsResetToken += 1
            }
            selectedTab = newValue
        }
    }
}

private enum RootTab: Hashable {
    case discover, lists, search
}

#Preview {
    CompactRootView(searchModel: SearchModel())
        .modelContainer(previewModelContainer)
        .environment(PersistenceCoordinator(previewModelContainer.mainContext))
        .environment(CloudSyncMonitor(isSyncing: false))
        .preferredColorScheme(.dark)
}
