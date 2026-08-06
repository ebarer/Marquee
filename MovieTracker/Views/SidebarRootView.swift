//
//  SidebarRootView.swift
//  MovieTracker
//
//  The regular-width (iPad) shell: a sidebar of Discover collections + lists
//  driving a detail column, replacing the compact tab bar.
//

import SwiftUI

struct SidebarRootView: View {
    @Bindable var searchModel: SearchModel

    @State private var selection: SidebarItem? = .collection(.popular)
    @State private var scope: SearchScope = .all
    @State private var detailPath = NavigationPath()

    var body: some View {
        NavigationSplitView {
            SidebarColumn(selection: $selection)
        } detail: {
            SidebarDetailView(selection: selection, scope: $scope,
                              path: $detailPath, searchModel: searchModel)
        }
    }
}

#Preview {
    SidebarRootView(searchModel: SearchModel())
        .modelContainer(previewModelContainer)
        .environment(PersistenceCoordinator(previewModelContainer.mainContext))
        .environment(CloudSyncMonitor(isSyncing: false))
        .preferredColorScheme(.dark)
}
