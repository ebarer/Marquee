//
//  DetailBridges.swift
//  MovieTracker
//
//  Temporary UIKit bridges that host the existing storyboard-based
//  detail screens inside the new SwiftUI navigation stacks. These are
//  removed once MovieDetailViewController / PersonDetailViewController
//  are rewritten in SwiftUI (see the migration plan's follow-up).
//

import SwiftUI
import UIKit

/// Hosts the storyboard `MovieDetailViewController` for a given movie.
struct MovieDetailBridge: UIViewControllerRepresentable {
    let movie: Movie

    func makeUIViewController(context: Context) -> MovieDetailViewController {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let controller = storyboard.instantiateViewController(
            withIdentifier: "MovieDetailViewController"
        ) as! MovieDetailViewController
        controller.movie = movie
        return controller
    }

    func updateUIViewController(_ controller: MovieDetailViewController, context: Context) {}
}

/// Hosts the storyboard `PersonDetailViewController` for a given person.
struct PersonDetailBridge: UIViewControllerRepresentable {
    let person: Person

    func makeUIViewController(context: Context) -> PersonDetailViewController {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let controller = storyboard.instantiateViewController(
            withIdentifier: "PersonDetailViewController"
        ) as! PersonDetailViewController
        controller.person = person
        return controller
    }

    func updateUIViewController(_ controller: PersonDetailViewController, context: Context) {}
}
