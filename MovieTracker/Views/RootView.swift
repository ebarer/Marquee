//
//  RootView.swift
//  MovieTracker
//

import SwiftUI
import SwiftData

struct RootView: View {
    static let sharedContainer: ModelContainer = {
        let configuration = ModelConfiguration(cloudKitDatabase: .automatic)
        do {
            return try ModelContainer(
                for: MediaItem.self, MediaList.self, ListEntry.self,
                configurations: configuration)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()

    @State private var syncMonitor = CloudSyncMonitor()
    @State private var store = PersistenceCoordinator(RootView.sharedContainer.mainContext)

    /// Shared across shells so the query survives a shell switch.
    @State private var searchModel = SearchModel()

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        Group {
            if horizontalSizeClass == .compact {
                CompactRootView(searchModel: searchModel)
            } else {
                SidebarRootView(searchModel: searchModel)
            }
        }
        .tint(.appAccent)
        .preferredColorScheme(.dark)
        .modelContainer(Self.sharedContainer)
        .environment(syncMonitor)
        .environment(store)
        .task {
            await store.bootstrap()
        }
    }
}

#Preview {
    RootView()
}
