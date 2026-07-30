//
//  PersonDetailView.swift
//  MovieTracker
//
//  SwiftUI person detail screen: biography header (profile, name,
//  birthday + age, expandable bio) and filmography. Replaces the
//  storyboard PersonDetailViewController.
//

import SwiftUI

struct PersonDetailView: View {
    let person: Person

    @State private var model = PersonDetailModel()

    private var current: Person { model.person ?? person }

    var body: some View {
        List {
            Section {
                PersonBioHeader(person: current)
                    .listRowInsets(EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16))
                    .listRowSeparator(.hidden)
            }

            if let credits = current.credits, !credits.isEmpty {
                Section("Filmography") {
                    ForEach(credits, id: \.id) { movie in
                        NavigationLink(value: movie) {
                            MovieRow(movie: movie)
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle(current.name)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await model.load(id: person.id)
        }
    }
}

#Preview {
    NavigationStack {
        PersonDetailView(person: .preview)
    }
    .preferredColorScheme(.dark)
}
