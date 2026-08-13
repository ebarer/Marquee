//
//  PersonBioHeader.swift
//  MovieTracker
//

import SwiftUI

/// The person header: profile photo, name, birthday/age, birthplace, and an expandable bio.
struct PersonBioHeader: View {
    let person: Person
    var photoNamespace: Namespace.ID
    var onPhotoTap: () -> Void = {}
    var navBarBottom: CGFloat = 0
    var onNameHiddenChange: (Bool) -> Void = { _ in }
    var onBioCollapsed: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 16) {
                ProfileImage(url: person.profileURL())
                    .frame(width: 100, height: 100)
                    .matchedTransitionSource(id: person.id, in: photoNamespace)
                    .onTapGesture { onPhotoTap() }

                VStack(alignment: .leading, spacing: 6) {
                    Text(person.name)
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                        .onGeometryChange(for: Bool.self) { proxy in
                            // Hidden once the name's bottom edge crosses above the nav bar.
                            proxy.frame(in: .global).maxY <= navBarBottom
                        } action: { onNameHiddenChange($0) }

                    if let birthdayString {
                        Text(birthdayString)
                            .font(.subheadline)
                            .foregroundStyle(Color.appAccent)
                    }

                    if let birthplace {
                        Text(birthplace)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 0)
            }

            if let bio = person.bio, !bio.isEmpty {
                ExpandableText(text: bio, lineLimit: 5, font: .body, onCollapse: onBioCollapsed)
            }
        }
    }

    // TMDB returns "City, State, Country"; keep only the first (city) and last (country)
    // components so the header stays compact.
    private var birthplace: String? {
        guard let place = person.placeOfBirth else { return nil }
        let parts = place
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard let city = parts.first else { return nil }
        guard let country = parts.last, country != city else { return city }
        return "\(city), \(country)"
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
    @Previewable @Namespace var namespace
    PersonBioHeader(person: .preview, photoNamespace: namespace)
        .padding()
        .background(Color.appBackground)
        .preferredColorScheme(.dark)
}
