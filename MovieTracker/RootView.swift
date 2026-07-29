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
