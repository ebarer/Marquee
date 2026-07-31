//
//  PersonBioHeader.swift
//  MovieTracker
//
//  Biography header for the person detail screen: profile image with the name
//  and age vertically centered beside it, and an expandable bio below.
//

import SwiftUI

struct PersonBioHeader: View {
    let person: Person
    /// Global Y coordinate of the nav bar's bottom edge, used to decide when the
    /// on-page name has scrolled up behind the bar.
    var navBarBottom: CGFloat = 0
    /// Called as the name crosses above/below the nav bar (true = hidden behind it).
    var onNameHiddenChange: (Bool) -> Void = { _ in }

    @State private var bioExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 16) {
                ProfileImage(url: person.profileURL())
                    .frame(width: 100, height: 100)

                VStack(alignment: .leading, spacing: 6) {
                    Text(person.name)
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                        .onGeometryChange(for: Bool.self) { proxy in
                            // Hidden once the name's bottom edge crosses above the
                            // nav bar's bottom edge.
                            proxy.frame(in: .global).maxY <= navBarBottom
                        } action: { onNameHiddenChange($0) }

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
