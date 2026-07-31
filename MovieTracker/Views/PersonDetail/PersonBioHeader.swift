//
//  PersonBioHeader.swift
//  MovieTracker
//
//  Biography header for the person detail screen: profile image, name,
//  birthday + age, and an expandable bio.
//

import SwiftUI

struct PersonBioHeader: View {
    let person: Person

    @State private var bioExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 16) {
                ProfileImage(url: person.profileURL())
                    .frame(width: 100, height: 100)

                VStack(alignment: .leading, spacing: 6) {
                    Text(person.name)
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

            if let bio = person.bio, !bio.isEmpty {
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
        guard let birthday = person.birthday else { return nil }
        var result = birthday.toString()
        if let age = Calendar.current.dateComponents([.year], from: birthday, to: Date()).year {
            result += "  •  \(age) years old"
        }
        return result
    }
}

#Preview {
    PersonBioHeader(person: .preview)
        .padding()
        .background(Color.appBackground)
}
