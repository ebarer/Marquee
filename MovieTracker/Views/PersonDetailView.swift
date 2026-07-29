//
//  PersonDetailView.swift
//  MovieTracker
//
//  SwiftUI person detail screen: biography header (profile, name,
//  birthday + age, expandable bio) and filmography. Replaces the
//  storyboard PersonDetailViewController.
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

struct PersonDetailView: View {
    let person: Person

    @State private var model = PersonDetailModel()
    @State private var bioExpanded = false

    private var current: Person { model.person ?? person }

    var body: some View {
        List {
            Section {
                bioHeader
                    .listRowInsets(EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16))
                    .listRowBackground(Color.appBackground)
                    .listRowSeparator(.hidden)
            }

            if let credits = current.credits, !credits.isEmpty {
                Section("Filmography") {
                    ForEach(credits, id: \.id) { movie in
                        NavigationLink(value: movie) {
                            MovieRow(movie: movie)
                        }
                        .listRowBackground(Color.appBackground)
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.appBackground)
        .navigationTitle(current.name)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await model.load(id: person.id)
        }
    }

    private var bioHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 16) {
                ProfileImage(url: current.profileURL())
                    .frame(width: 100, height: 100)

                VStack(alignment: .leading, spacing: 6) {
                    Text(current.name)
                        .font(.title2.bold())
                        .foregroundStyle(.white)

                    if let birthdayString {
                        Text(birthdayString)
                            .font(.subheadline)
                            .foregroundStyle(Color.appAccent)
                    }
                }

                Spacer(minLength: 0)
            }

            if let bio = current.bio, !bio.isEmpty {
                Text(bio)
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(bioExpanded ? nil : 5)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.easeInOut) { bioExpanded.toggle() }
                    }
            }
        }
    }

    private var birthdayString: String? {
        guard let birthday = current.birthday else { return nil }
        var result = birthday.toString()
        if let age = Calendar.current.dateComponents([.year], from: birthday, to: Date()).year {
            result += "  •  \(age) years old"
        }
        return result
    }
}
