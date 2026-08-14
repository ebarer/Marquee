//
//  CompactRootView.swift
//  MovieTracker
//

import SwiftUI

struct CompactRootView: View {
    @Bindable var searchModel: SearchModel

    @State private var searchPath = NavigationPath()
    @State private var selectedTab: RootTab = .discover
    @State private var listsPath = NavigationPath()
    @State private var listsResetToken = 0
    /// The tint published by each tab's list page. Detail screens deliberately publish
    /// nothing: a tint arriving mid-push changes `.tint` here and costs the row its highlight.
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
                    SearchView(model: searchModel)
                        .detailDestinations()
                        // Declared on the content inside the stack: on the NavigationStack
                        // itself, a push with the field focused skipped its animation.
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
