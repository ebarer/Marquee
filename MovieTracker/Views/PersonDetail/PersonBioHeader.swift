//
//  PersonBioHeader.swift
//  MovieTracker
//

import SwiftUI

struct PersonBioHeader: View {
    let person: Person
    var photoNamespace: Namespace.ID
    var onPhotoTap: () -> Void = {}
    var navBarBottom: CGFloat = 0
    var onNameHiddenChange: (Bool) -> Void = { _ in }
    var onBioCollapsed: () -> Void = {}

    @State private var bioExpanded = false
    @State private var bioLimitedHeight: CGFloat = 0
    @State private var bioFullHeight: CGFloat = 0
    private var bioTruncated: Bool { bioFullHeight > bioLimitedHeight + 1 }
    @ScaledMetric(relativeTo: .body) private var moreBaselineNudge: CGFloat = 2

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
                            // Hidden once the name's bottom edge crosses above the
                            // nav bar's bottom edge.
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
                bioSection(bio)
            }
        }
    }

    // MARK: - Bio

    @ViewBuilder
    private func bioSection(_ bio: String) -> some View {
        ZStack(alignment: .bottomTrailing) {
            Text(bio)
                .font(.body)
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(bioExpanded ? nil : 5)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background { bioTruncationProbe(bio) }

            if bioTruncated && !bioExpanded {
                Text("More")
                    .textCase(.uppercase)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.12), in: .capsule)
                    .padding(.leading, 44)
                    .background(
                        LinearGradient(
                            colors: [Color.appBackground.opacity(0), .appBackground, .appBackground],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .offset(y: moreBaselineNudge)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            let collapsing = bioExpanded
            withAnimation(.easeInOut) { bioExpanded.toggle() }
            if collapsing { onBioCollapsed() }
        }
    }

    /// Hidden copies of the bio measured at the collapsed 5-line limit and at full
    /// height; the difference tells us whether a "More" pill is warranted.
    private func bioTruncationProbe(_ bio: String) -> some View {
        ZStack {
            Text(bio)
                .font(.body)
                .lineLimit(5)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background { heightReader { bioLimitedHeight = $0 } }
            Text(bio)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background { heightReader { bioFullHeight = $0 } }
        }
        .hidden()
    }

    private func heightReader(_ report: @escaping (CGFloat) -> Void) -> some View {
        GeometryReader { proxy in
            Color.clear
                .onAppear { report(proxy.size.height) }
                .onChange(of: proxy.size.height) { _, new in report(new) }
        }
    }

    /// The place of birth reduced to "City, Country". TMDB returns the full
    /// "City, State, Country" string; we keep only the first (city) and last
    /// (country) components so the header stays compact.
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
        .colorScheme(.dark)
}
