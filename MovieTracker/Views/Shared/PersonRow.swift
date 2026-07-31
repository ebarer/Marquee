//
//  PersonRow.swift
//  MovieTracker
//
//  Shared list row for a person: circular profile beside the name, with an
//  optional role line. The movie detail's Cast & Crew shows name + role;
//  Search shows just the name. Replaces `PersonTableViewCell`.
//

import SwiftUI

struct PersonRow: View {
    let person: Person
    /// Show the person's role (character/job). Used in the movie detail cast list.
    var showRole = true

    var body: some View {
        HStack(spacing: 12) {
            ProfileImage(url: person.profileURL())
                .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(person.name)
                    .font(.body)
                    .foregroundStyle(.white)

                if showRole, let role = person.role, !role.isEmpty {
                    Text(role)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    PersonRow(person: .preview)
        .padding()
        .background(Color.appBackground)
}
