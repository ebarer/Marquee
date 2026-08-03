//
//  Person.swift
//  MovieTracker
//
//  Created by Elliot Barer on 11/12/18.
//  Copyright © 2018 ebarer. All rights reserved.
//

import Foundation

/// A transient person hydrated from TMDB (not persisted). Identity is the TMDB id,
/// so it works as a navigation value.
struct Person: Hashable, Identifiable {
    var id: Int
    var name: String
    var popularity: Float = 0.0
    var type: PersonType?
    var role: String?
    var profilePicture: String?
    var birthday: Date?
    var placeOfBirth: String?
    var imdbID: String?
    var bio: String?
    var credits: [Movie]?

    enum PersonType {
        case Cast
        case Crew
    }

    init(id: Int, name: String) {
        self.id = id
        self.name = name
    }

    init(id: Int, name: String, role: String?, pic: String?, type: PersonType) {
        self.id = id
        self.name = name
        self.role = role
        self.profilePicture = pic
        self.type = type
    }

    static func == (lhs: Person, rhs: Person) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    /// The person's most notable credits (their "known for"), sorted by popularity.
    /// Excludes "Self"/"Thanks" credits and anything without a poster.
    var knownFor: [Movie] {
        (credits ?? [])
            .filter { !$0.isExtraneousCredit && $0.poster != nil }
            .sorted { ($0.popularity ?? 0) > ($1.popularity ?? 0) }
    }
}

// MARK: - Image Size Enumerations

extension Person {
    enum ProfileSize: String {
        case w276 = "w276_and_h350_face"
        case orig = "original"
    }

    func profileURL(_ size: ProfileSize = .w276) -> URL? {
        TMDBWrapper.imageURL(path: profilePicture, size: size.rawValue)
    }
}
