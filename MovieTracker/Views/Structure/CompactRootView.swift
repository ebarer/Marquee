//
//  CompactRootView.swift
//  MovieTracker
//

import SwiftUI
import UIKit

struct CompactRootView: View {
    @Bindable var searchModel: SearchModel

    @State private var searchPath = NavigationPath()
    @State private var selectedTab: RootTab = .discover
    @State private var listsPath = NavigationPath()
    @State private var listsResetToken = 0
    /// The tint published by each tab's frontmost page, so the tab bar can follow the one
    /// on screen. Tracked per tab (not as a single value) because a tab the user left is
    /// still alive and still publishing.
    @State private var tabTints: [RootTab: Color] = [:]

    var body: some View {
        TabView(selection: tabSelection) {
            Tab("Discover", systemImage: "film", value: RootTab.discover) {
                NavigationStack {
                    FeaturedView()
                        .detailDestinations()
                }
                .onPageTintChange { tabTints[.discover] = $0 }
            }

            Tab("Lists", systemImage: "checklist", value: RootTab.lists) {
                NavigationStack(path: $listsPath) {
                    ListsView(resetToken: listsResetToken)
                        .detailDestinations()
                }
                .onPageTintChange { tabTints[.lists] = $0 }
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
                    if newPath.count > oldPath.count {
                        searchModel.commit()
                    }
                }
                .onPageTintChange { tabTints[.search] = $0 }
            }
        }
        .tabViewSearchActivation(.searchTabSelection)
        .tint(tabTints[selectedTab] ?? .appAccent)
    }

    /// Opens a tapped search result: resign the search field's focus first so the
    /// keyboard's collapse doesn't share the push transaction, then push on the next
    /// runloop so the navigation animates even with the keyboard up.
    private func openSearchResult(_ movie: Movie) {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                        to: nil, from: nil, for: nil)
        DispatchQueue.main.async { searchPath.append(movie) }
    }

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
