//
//  PersonDetailHeader.swift
//  MovieTracker
//

import SwiftUI

/// The person header's geometry: what it occupies at rest, and where it comes to rest pinned.
/// Text slots are caller-scaled, so the same numbers drive the header and the pin lines below it.
struct PersonHeaderMetrics {
    static let avatar: CGFloat = 120
    static let collapsedAvatar: CGFloat = 60
    /// The photo grows with a pull-down, up to this much of its resting size.
    static let maxPhotoPull: CGFloat = 1.4
    /// The pull that reaches that cap, as a fraction of the page: a third of the screen, so the
    /// photo grows gradually and maxing it out takes a deliberate drag.
    static let photoPullSpan: CGFloat = 0.35
    static let nameScale: CGFloat = 0.7
    static let padding: CGFloat = 16
    static let avatarGap: CGFloat = 12
    static let collapsedAvatarGap: CGFloat = 10
    /// Separates the name from the birth details, and those two lines from each other.
    static let metaGap: CGFloat = 6
    /// The bar's item row — the back button — starts this far above the content's top edge.
    static let barRow: CGFloat = DetailSearchBar.barHeight

    let nameLine: CGFloat
    let metaLine: CGFloat

    // Both extents run `barRow` short of what the column occupies, so the column reaches up into
    // the bar and the avatar's top edge sits on the back button's throughout the collapse.
    var collapsedExtent: CGFloat {
        Self.collapsedAvatar + Self.collapsedAvatarGap + nameLine * Self.nameScale
            + Self.padding - Self.barRow
    }

    func metaHeight(lines: Int) -> CGFloat {
        guard lines > 0 else { return 0 }
        return metaLine * CGFloat(lines) + Self.metaGap * CGFloat(lines - 1)
    }

    func restExtent(metaLines: Int) -> CGFloat {
        Self.avatar + Self.avatarGap + nameLine
            + (metaLines > 0 ? Self.metaGap + metaHeight(lines: metaLines) : 0)
            + Self.padding - Self.barRow
    }
}

/// The last of the collapse, over which the header crossfades into glass.
private enum Pinning {
    static let glassSpan: CGFloat = 0.3
    /// Where the pinned glass settles. Full opacity reads as a grey pane rather than glass.
    static let glassPeak: CGFloat = 0.80
    static let dimsPage: CGFloat = 0.25
    static let glassTint = Color.black.opacity(0.35)
}

/// The person header: profile photo, name, and birth details, centred in a column that collapses
/// and pins as glass over the page, matching the movie and show detail headers.
struct PersonDetailHeader: View {
    let person: Person
    let metrics: PersonHeaderMetrics
    var photoNamespace: Namespace.ID
    var onPhotoTap: () -> Void = {}
    let navBarBottom: CGFloat
    /// How far the page is pulled past its top edge. The photo grows into that space.
    var overscroll: CGFloat = 0
    /// The page's height, which sets how far a pull has to go to grow the photo fully.
    var pageHeight: CGFloat = 0
    @Binding var headerPinned: Bool
    /// Previews only: holds the collapse at a fixed progress, which scroll geometry can't supply.
    var previewProgress: CGFloat? = nil

    private var metaLines: Int { [birthdayString, birthplace].compactMap { $0 }.count }
    private var restExtent: CGFloat { metrics.restExtent(metaLines: metaLines) }

    var body: some View {
        // `visualEffect`'s closure is `@Sendable`, so read the main-actor values up front.
        let collapse = max(1, restExtent - metrics.collapsedExtent)
        let rest = navBarBottom + restExtent
        let override = previewProgress

        return GeometryReader { proxy in
            let scrolled = max(0, -proxy.frame(in: .named("scroll")).minY)
            let progress = override ?? min(1, scrolled / collapse)
            let shrink = collapse * progress
            let span = max(1, pageHeight * PersonHeaderMetrics.photoPullSpan)
            let pull = PersonHeaderMetrics.avatar * (PersonHeaderMetrics.maxPhotoPull - 1)
                * min(1, overscroll / span)
            // Glass is held off until the last stretch, so the header only crossfades into it
            // as it sticks.
            let reveal = min(1, max(0, (progress - (1 - Pinning.glassSpan)) / Pinning.glassSpan))

            ZStack(alignment: .bottom) {
                Color.appBackground
                    .opacity(1 - reveal * Pinning.dimsPage)

                // Liquid Glass, not a frosted grey `Material`, which only ever thins to grey.
                SectionHeaderGlass(tint: Pinning.glassTint)
                    .opacity(reveal * Pinning.glassPeak)

                column(progress: progress, pull: pull)
            }
            // Grown upward by the pull — bottom-aligned, so the column stays where it is and the
            // photo has room past the frame the header occupies at rest.
            .frame(maxWidth: .infinity, minHeight: rest - shrink + pull,
                   maxHeight: rest - shrink + pull, alignment: .bottom)
            .clipped()
            // Counters the scroll, so the shrinking header's top edge stays at the page's top.
            .offset(y: shrink - pull)
            .onChange(of: scrolled >= collapse) { _, pinned in
                withAnimation(.easeInOut(duration: 0.2)) { headerPinned = pinned }
            }
        }
        .frame(height: rest)
        // Pin via render-time geometry (a GeometryReader-driven offset reads scroll a frame late
        // and the pinned header vibrates against the page). Engages only past the collapse.
        .visualEffect { content, proxy in
            let scrolled = max(0, -proxy.frame(in: .named("scroll")).minY)
            return content.offset(y: max(0, scrolled - collapse))
        }
    }

    private func column(progress: CGFloat, pull: CGFloat) -> some View {
        let avatar = PersonHeaderMetrics.avatar
            - (PersonHeaderMetrics.avatar - PersonHeaderMetrics.collapsedAvatar) * progress
        let nameScale = 1 - (1 - PersonHeaderMetrics.nameScale) * progress
        let avatarGap = PersonHeaderMetrics.avatarGap
            - (PersonHeaderMetrics.avatarGap - PersonHeaderMetrics.collapsedAvatarGap) * progress
        // Uniform, so what the metadata draws always matches the slot its frame reserves.
        let metaScale = max(0.5, 1 - progress)

        return VStack(spacing: 0) {
            ProfileImage(url: person.profileURL())
                .frame(width: avatar, height: avatar)
                // Scaled rather than sized, so the pull never re-lays out the column below it.
                .scaleEffect((avatar + pull) / avatar, anchor: .bottom)
                .matchedTransitionSource(id: person.id, in: photoNamespace)
                .onTapGesture { onPhotoTap() }

            Text(person.name)
                .font(.title2.bold())
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                // Fixed font in a fixed slot + scaleEffect: the text never re-wraps or re-lays
                // out as it shrinks, and what it draws matches the header's own height math.
                .frame(height: metrics.nameLine)
                .scaleEffect(nameScale, anchor: .top)
                .frame(height: metrics.nameLine * nameScale, alignment: .top)
                .padding(.top, avatarGap)

            if metaLines > 0 {
                metadata
                    .scaleEffect(metaScale, anchor: .top)
                    .frame(height: metrics.metaHeight(lines: metaLines) * (1 - progress),
                           alignment: .top)
                    .opacity(Double(max(0, 1 - progress * 3)))
                    .padding(.top, PersonHeaderMetrics.metaGap * (1 - progress))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, PersonHeaderMetrics.padding)
        .padding(.bottom, PersonHeaderMetrics.padding)
        // Negative, and matched by both extents: the column reaches into the bar's row.
        .padding(.top, -PersonHeaderMetrics.barRow)
    }

    private var metadata: some View {
        VStack(spacing: PersonHeaderMetrics.metaGap) {
            if let birthdayString {
                Text(birthdayString)
                    .font(.subheadline)
                    .foregroundStyle(Color.appAccent)
                    .frame(height: metrics.metaLine)
            }

            if let birthplace {
                Text(birthplace)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(height: metrics.metaLine)
            }
        }
        .lineLimit(1)
        .multilineTextAlignment(.center)
    }

    /// Countries whose second-level division is the more telling half of a birthplace.
    private static let regionalCountries: Set<String> = [
        "USA", "US", "United States", "United States of America", "Canada",
    ]

    // TMDB returns "City, State, Country" (sometimes with a district ahead of the city); keep
    // the city and the country, or the state for the countries people name by state.
    private var birthplace: String? {
        guard let place = person.placeOfBirth else { return nil }
        let parts = place
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard let city = parts.first else { return nil }
        guard let country = parts.last, country != city else { return city }
        if Self.regionalCountries.contains(country), parts.count >= 3 {
            return "\(city), \(parts[parts.count - 2])"
        }
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

private struct HeaderPreview: View {
    var progress: CGFloat?
    var overscroll: CGFloat = 0
    var person: Person = .preview

    @Namespace private var namespace
    @ScaledMetric(relativeTo: .title2) private var nameLine: CGFloat = 27
    @ScaledMetric(relativeTo: .subheadline) private var metaLine: CGFloat = 18

    var body: some View {
        GeometryReader { container in
            ScrollView {
                VStack(spacing: 0) {
                    PersonDetailHeader(
                        person: person,
                        metrics: PersonHeaderMetrics(nameLine: nameLine, metaLine: metaLine),
                        photoNamespace: namespace, navBarBottom: 100, overscroll: overscroll,
                        pageHeight: container.size.height,
                        headerPinned: .constant(progress == 1), previewProgress: progress
                    )
                    Color.appSeparator.frame(height: 1200)
                }
            }
            .coordinateSpace(name: "scroll")
            .ignoresSafeArea(edges: [.top, .horizontal])
        }
        .background(Color.appBackground)
        .preferredColorScheme(.dark)
    }
}

#Preview("At rest") {
    HeaderPreview()
}

#Preview("Pinned") {
    HeaderPreview(progress: 1)
}

// A pull of a fifth of the page: what a flick reaches, and most of what anyone will see.
#Preview("Pulled down") {
    HeaderPreview(overscroll: 180)
}

#Preview("Pulled down, maxed") {
    HeaderPreview(overscroll: 400)
}

#Preview("No birth details") {
    var person = Person(id: Person.preview.id, name: Person.preview.name)
    person.profilePicture = Person.preview.profilePicture
    return HeaderPreview(person: person)
}
