//
//  RootView.swift
//  MovieTracker
//

import SwiftUI
import SwiftData

/// The scene root: owns the shared container / store / search model and picks the
/// shell for the current size class — a tab bar when compact (iPhone, narrow iPad
/// multitasking), a sidebar split view when regular (iPad).
struct RootView: View {
    /// Shared SwiftData container for the Watch List, synced through the app's
    /// private CloudKit database. Built once and attached to the whole scene.
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

    /// Tracks CloudKit sync activity so the Lists screen can show a sync indicator.
    @State private var syncMonitor = CloudSyncMonitor()

    /// The single writer for the store, shared with the whole scene.
    @State private var store = PersistenceCoordinator(RootView.sharedContainer.mainContext)

    /// Search state shared across shells so the query survives a shell switch.
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
        // Seed, deduplicate, and reconcile the store for the lifetime of the scene.
        .task {
            await store.bootstrap()
        }
    }
}

#Preview {
    RootView()
}
