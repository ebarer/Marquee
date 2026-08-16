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
            return try ModelContainer(for: MarqueeSchema.schema, configurations: configuration)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()

    @State private var syncMonitor = CloudSyncMonitor()
    @State private var store = PersistenceCoordinator(RootView.sharedContainer.mainContext)

    /// Shared across shells so the query survives a shell switch.
    @State private var searchModel = SearchModel()

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.scenePhase) private var scenePhase

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
        // Re-poll in-progress shows for newly-aired seasons on each foreground (TTL-gated).
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await store.refreshWatchedShows() } }
        }
    }
}

#Preview {
    RootView()
}
