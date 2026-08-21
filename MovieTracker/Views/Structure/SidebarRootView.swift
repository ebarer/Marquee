//
//  SidebarRootView.swift
//  MovieTracker
//

import SwiftUI

struct SidebarRootView: View {
    @Bindable var searchModel: SearchModel

    @State private var selection: SidebarItem? = .collection(.nowPlaying)
    @State private var presented: DetailRoot?
    // Waits while the outgoing modal finishes dismissing; `onDismiss` presents it.
    @State private var pending: DetailRoot?
    @State private var scrollTopToken = 0

    var body: some View {
        NavigationSplitView {
            SidebarColumn(selection: $selection) { scrollTopToken += 1 }
        } detail: {
            DetailColumn(selection: selection, searchModel: searchModel)
        }
        .environment(\.scrollTopToken, scrollTopToken)
        .environment(\.openDetail, present)
        .sheet(item: $presented, onDismiss: presentPending) { root in
            NavigationStack {
                DetailRootView(root: root)
                    .detailDestinations()
            }
            // Injected on the stack so every pushed screen inherits it and keeps its own Close button.
            .environment(\.closeModal) { presented = nil }
            .presentationSizing(.fitted)
            .frame(minWidth: 500, idealWidth: 600, maxWidth: 800, minHeight: 600, idealHeight: 800)
        }
    }

    private func present(_ value: AnyHashable) {
        guard let root = DetailRoot(value) else { return }
        // Non-nil here means the modal is still dismissing: writing over it cancels that
        // dismissal, and `.sheet(item:)` doesn't rebuild, so the outgoing screen comes back.
        if presented == nil {
            presented = root
        } else {
            pending = root
            presented = nil
        }
        searchModel.recordVisit(value)
    }

    private func presentPending() {
        guard let next = pending else { return }
        pending = nil
        presented = next
    }
}

#Preview {
    SidebarRootView(searchModel: SearchModel())
        .modelContainer(previewModelContainer)
        .environment(PersistenceCoordinator(previewModelContainer.mainContext))
        .environment(CloudSyncMonitor(isSyncing: false))
        .preferredColorScheme(.dark)
}
