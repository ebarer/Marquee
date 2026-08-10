//
//  PersonDetailModel.swift
//  MovieTracker
//

import SwiftUI

@MainActor
@Observable
final class PersonDetailModel {
    private(set) var person: Person?

    private var loaded = false

    func load(id: Int) async {
        guard !loaded else { return }
        loaded = true
        do {
            person = try await TMDBWrapper.getPerson(id: id)
        } catch {
            print("Person detail load error: \(error)")
        }
    }
}
