//
//  Person.swift
//  MovieTracker
//
//  Created by Elliot Barer on 11/12/18.
//  Copyright © 2018 ebarer. All rights reserved.
//

import UIKit

class Person: NSObject {
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

    /// The person's most notable movie credits (their "known for"), sorted by
    /// popularity. Excludes talk-show "Self" and "Thanks" credits and anything
    /// without a poster so the row reads as a clean poster strip.
    var knownFor: [Movie] {
        (credits ?? [])
            .filter { !$0.isExtraneousCredit && $0.poster != nil }
            .sorted { ($0.popularity ?? 0) > ($1.popularity ?? 0) }
    }

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
        self.type = type
        self.name = name
        self.role = role
        self.profilePicture = pic
    }
    
    override var description: String {
        return "[\(id)] \(name)"
    }
}

// MARK: - Image Size Enumerations

extension Person {
    enum ProfileSize: String {
        case w276 = "w276_and_h350_face"
        case orig = "original"
    }
}
