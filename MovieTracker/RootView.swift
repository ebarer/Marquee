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

struct RootView: View {
    var body: some View {
        TabView {
            Tab("Featured", systemImage: "film") {
                NavigationStack {
                    FeaturedView()
                        .movieTrackerDestinations()
                }
            }

            Tab("Watch List", systemImage: "checklist") {
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
    }
}

extension View {
    /// Registers the shared movie/person navigation destinations on a stack.
    /// While the detail screens are still UIKit, these resolve to bridges.
    func movieTrackerDestinations() -> some View {
        self
            .navigationDestination(for: Movie.self) { movie in
                MovieDetailBridge(movie: movie)
                    .ignoresSafeArea()
                    .toolbar(.hidden, for: .navigationBar)
            }
            .navigationDestination(for: Person.self) { person in
                PersonDetailBridge(person: person)
            }
    }
}

#Preview {
    RootView()
}
