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
    /// Called when the bio is collapsed, so the container can re-anchor the scroll
    /// to the header — collapsing removes the tall bio's height from above the
    /// viewport, which would otherwise leave the reader stranded in the filmography.
    var onBioCollapsed: () -> Void = {}

    @State private var bioExpanded = false
    /// Rendered heights of the bio text at its 5-line limit vs. unclipped, used to
    /// decide whether the "More" pill is needed at all.
    @State private var bioLimitedHeight: CGFloat = 0
    @State private var bioFullHeight: CGFloat = 0
    /// True only when the bio actually overflows the collapsed line limit.
    private var bioTruncated: Bool { bioFullHeight > bioLimitedHeight + 1 }
    /// Baseline nudge that lands the "More" pill on the bio's last line; scaled so
    /// it keeps up as the surrounding text grows.
    @ScaledMetric(relativeTo: .body) private var moreBaselineNudge: CGFloat = 2

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

                    if let place = person.placeOfBirth, !place.isEmpty {
                        Text(place)
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

            // A neutral glass "More" pill at the end of the truncated text, with a
            // gradient behind it that masks the words underneath and blends into the
            // background. Shown only when the bio actually overflows the 5-line limit.
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
                    // Nudge down so "MORE" sits on the bio's baseline rather than
                    // the top of the last line's spacing.
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

    /// Reports the measured height of the view it backs.
    private func heightReader(_ report: @escaping (CGFloat) -> Void) -> some View {
        GeometryReader { proxy in
            Color.clear
                .onAppear { report(proxy.size.height) }
                .onChange(of: proxy.size.height) { _, new in report(new) }
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
