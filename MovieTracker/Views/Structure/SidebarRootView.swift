//
//  SidebarRootView.swift
//  MovieTracker
//

import SwiftUI

struct SidebarRootView: View {
    @Bindable var searchModel: SearchModel

    @State private var selection: SidebarItem? = .collection(.popular)
    @State private var presented: DetailRoot?

    var body: some View {
        NavigationSplitView {
            SidebarColumn(selection: $selection)
        } detail: {
            DetailColumn(selection: selection, searchModel: searchModel)
        }
        .environment(\.openDetail, present)
        .sheet(item: $presented) { root in
            NavigationStack {
                DetailRootView(root: root)
                    .modalDismissable()
                    .detailDestinations()
            }
            // Injected on the stack so every pushed screen (cast → person, related
            // → movie) inherits it and keeps its own Close button.
            .environment(\.closeModal) { presented = nil }
            .presentationSizing(.fitted)
            .frame(minWidth: 500, idealWidth: 600, maxWidth: 800, minHeight: 600, idealHeight: 800)
        }
    }

    private func present(_ value: AnyHashable) {
        guard let root = DetailRoot(value) else { return }
        presented = root
        if !searchModel.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            searchModel.commit()
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
