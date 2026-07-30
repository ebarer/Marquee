//
//  RootView.swift
//  MovieTracker
//
//  Root SwiftUI interface: a tabbed shell replacing the storyboard
//  TabBarController. Each tab is its own NavigationStack; movie and
//  person values pushed onto a stack resolve to the (currently bridged)
//  detail screens.
//

import SwiftUI
import SwiftData

struct RootView: View {
    /// Shared SwiftData container for the Watch List, synced through the app's
    /// private CloudKit database. Built once and attached to the whole scene.
    static let sharedContainer: ModelContainer = {
        let configuration = ModelConfiguration(cloudKitDatabase: .automatic)
        do {
            return try ModelContainer(for: WatchListEntry.self, configurations: configuration)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()

    var body: some View {
        TabView {
            Tab("Discovery", systemImage: "film") {
                NavigationStack {
                    FeaturedView()
                        .movieTrackerDestinations()
                }
            }

            Tab("Lists", systemImage: "checklist") {
                NavigationStack {
                    WatchListView()
                        .movieTrackerDestinations()
                }
            }

            Tab("Search", systemImage: "magnifyingglass", role: .search) {
                NavigationStack {
                    SearchView()
                        .movieTrackerDestinations()
                }
            }
        }
        .tint(.appAccent)
        .preferredColorScheme(.dark)
        .modelContainer(Self.sharedContainer)
    }
}

extension View {
    /// Registers the shared movie/person navigation destinations on a stack.
    func movieTrackerDestinations() -> some View {
        self
            .navigationDestination(for: Movie.self) { movie in
                MovieDetailView(movie: movie)
            }
            .navigationDestination(for: Person.self) { person in
                PersonDetailView(person: person)
            }
    }
}

#Preview {
    RootView()
}
