//
//  PersonRow.swift
//  MovieTracker
//
//  List row: circular profile beside name + role. Replaces `PersonTableViewCell`.
//

import SwiftUI

struct PersonRow: View {
    let person: Person

    var body: some View {
        HStack(spacing: 12) {
            ProfileImage(url: person.profileURL())
                .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(person.name)
                    .font(.body)
                    .foregroundStyle(.white)

                if let role = person.role, !role.isEmpty {
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
