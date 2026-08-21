//
//  CastSection.swift
//  MovieTracker
//

import SwiftUI

/// People a page doesn't list but search still reaches, under a heading of their own.
struct CastSearchRoster {
    let title: String
    let people: [Person]
}

/// Cast and crew for a detail screen: lead crew credit on top, a Cast/Guests/Crew picker below.
struct CastSection: View {
    let cast: [Person]
    var guests: [Person] = []
    var tint: Color = .appAccent
    var countsEpisodes: Bool = true
    var leadRole: String = "Director"
    var leadTitleSingular: String = "Director"
    var leadTitlePlural: String = "Directors"
    var castTitle: String = "Cast"
    var castLimit: Int = 10
    var searchRoster: CastSearchRoster?
    var creditedShow: Show?
    var onSearchRequest: ((DetailSearchRequest?) -> Void)?

    @State private var selection: CastCategory?
    @State private var castExpanded = false
    @AppStorage("castEpisodeCounts") private var showsEpisodeCounts = true

    private var hasEpisodeCounts: Bool {
        countsEpisodes && (cast + guests).contains { ($0.episodeCount ?? 0) > 0 }
    }

    private var castMembers: [Person] { cast.filter { $0.type == .Cast } }

    // Crew whose joined roles include an exact lead credit (so "Art Director" doesn't
    // match "Director"). Shown above the crew list.
    private var directors: [Person] { cast.filter { $0.type == .Crew && isLead($0) } }
    private var crewMembers: [Person] { cast.filter { $0.type == .Crew && !isLead($0) } }

    private func isLead(_ person: Person) -> Bool {
        (person.role ?? "").components(separatedBy: ", ").contains(leadRole)
    }

    // A host-led show, whose guests read as its cast. Two regulars covers a host and a co-host.
    private var mergesGuests: Bool {
        (1...2).contains(castMembers.count) && !guests.isEmpty
    }

    private func title(for category: CastCategory) -> String {
        guard category == .cast else { return category.title }
        return mergesGuests ? "\(castTitle) & \(CastCategory.guests.title)" : castTitle
    }

    private func members(for category: CastCategory) -> [Person] {
        switch category {
        case .cast:
            guard mergesGuests else { return castMembers }
            // A regular can also be billed as a guest star on their own episode.
            var seen = Set<Int>()
            return (castMembers + guests).filter { seen.insert($0.id).inserted }
        case .guests: return mergesGuests ? [] : guests
        case .crew: return crewMembers
        }
    }

    private var availableCategories: [CastCategory] {
        CastCategory.allCases.filter { !members(for: $0).isEmpty }
    }

    private var currentCategory: CastCategory? {
        if let selection, availableCategories.contains(selection) { return selection }
        return availableCategories.first
    }

    var body: some View {
        if !directors.isEmpty || currentCategory != nil {
            VStack(spacing: 0) {
                if !directors.isEmpty {
                    SectionHeader(title: directors.count > 1 ? leadTitlePlural : leadTitleSingular)
                    CastPersonList(people: directors)
                }
                if let category = currentCategory {
                    CastCategoryPicker(categories: availableCategories, current: category,
                                       tint: tint, titleFor: title(for:),
                                       onSelect: { option in
                                           withAnimation(.easeInOut) { selection = option }
                                       },
                                       filter: {
                                           if hasEpisodeCounts {
                                               CastCountsMenu(showsCounts: $showsEpisodeCounts,
                                                              tint: tint)
                                               .padding(.leading, 8)
                                           }
                                       },
                                       accessory: {
                                           if onSearchRequest == nil {
                                               DetailSearchButton(request: searchRequest)
                                           }
                                       })
                        .onChange(of: searchSignature, initial: true) { _, _ in
                            onSearchRequest?(searchRequest)
                        }
                    categoryList(category)
                        // New identity per category so switching crossfades the list.
                        .id(category)
                        .transition(.opacity)
                        // `@AppStorage` publishes outside a `withAnimation`, so the rows
                        // animate their own change of height.
                        .animation(.easeInOut, value: showsEpisodeCounts)
                }
            }
        }
    }

    private var searchRequest: DetailSearchRequest {
        var groups = [
            DetailSearchGroup(title: directors.count > 1 ? leadTitlePlural : leadTitleSingular,
                              content: .people(directors)),
            DetailSearchGroup(title: title(for: .cast), content: .people(members(for: .cast))),
            DetailSearchGroup(title: title(for: .guests), content: .people(members(for: .guests))),
            DetailSearchGroup(title: title(for: .crew), content: .people(members(for: .crew))),
        ]
        if let searchRoster {
            // A season regular can be billed below the show's own floor too, so the listed
            // rows win and the roster supplies only what they leave out.
            let listed = Set(groups.flatMap(\.peopleIDs))
            groups.append(DetailSearchGroup(
                title: searchRoster.title,
                content: .people(searchRoster.people.filter { !listed.contains($0.id) })))
        }
        return DetailSearchRequest(prompt: "Search Cast & Crew",
                                   groups: groups.filter { $0.rowCount > 0 },
                                   tint: tint, countsEpisodes: hasEpisodeCounts,
                                   creditedShow: creditedShow)
    }

    // The request is rebuilt off this rather than diffed: a guest roster runs to thousands.
    private var searchSignature: [Int] {
        [directors.count, castMembers.count, castMembers.first?.id ?? 0, guests.count,
         crewMembers.count, searchRoster?.people.count ?? 0, hasEpisodeCounts ? 1 : 0]
    }

    @ViewBuilder
    private func categoryList(_ category: CastCategory) -> some View {
        let all = members(for: category)
        let expandable = category == .cast && all.count > castLimit
        let collapsed = expandable && !castExpanded
        let shown = collapsed ? Array(all.prefix(castLimit)) : all
        VStack(spacing: 0) {
            CastPersonList(people: shown,
                           showsEpisodeCounts: hasEpisodeCounts && showsEpisodeCounts)
            if expandable {
                CastRowSeparator()
                expandToggleRow(collapsed: collapsed, remaining: all.count - castLimit)
            }
        }
    }

    private func expandToggleRow(collapsed: Bool, remaining: Int) -> some View {
        Button {
            withAnimation(.easeInOut) { castExpanded.toggle() }
        } label: {
            HStack(spacing: 6) {
                Text(collapsed ? "Show \(remaining) More" : "Show Less")
                    .font(.subheadline.weight(.semibold))
                Image(systemName: "chevron.down")
                    .font(.footnote.weight(.semibold))
                    .rotationEffect(.degrees(collapsed ? 0 : 180))
                Spacer(minLength: 0)
            }
            .foregroundStyle(tint)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        ScrollView {
            CastSection(cast: Movie.preview.team)
        }
        .detailDestinations()
        .detailSearchHost()
    }
    .background(Color.appBackground)
    .modelContainer(previewModelContainer)
    .environment(PersistenceCoordinator(previewModelContainer.mainContext))
    .preferredColorScheme(.dark)
}

#Preview("Host and one guest") {
    let cast = Person.previewTeam.filter { $0.type == .Cast }

    return NavigationStack {
        ScrollView {
            CastSection(cast: [cast[0]], guests: [cast[1]], countsEpisodes: false)
        }
        .detailDestinations()
        .detailSearchHost()
    }
    .background(Color.appBackground)
    .modelContainer(previewModelContainer)
    .environment(PersistenceCoordinator(previewModelContainer.mainContext))
    .preferredColorScheme(.dark)
}

// TV: aggregate credits carry a per-person episode count, so the section also offers the
// control that hides it.
#Preview("Episode counts") {
    let cast = Person.previewTeam.enumerated().map { index, member -> Person in
        var member = member
        if member.type == .Cast { member.episodeCount = 62 - index * 5 }
        return member
    }

    return NavigationStack {
        ScrollView {
            CastSection(cast: cast, leadRole: "Creator", leadTitleSingular: "Creator",
                        leadTitlePlural: "Creators", castLimit: 5)
        }
        .detailDestinations()
        .detailSearchHost()
    }
    .background(Color.appBackground)
    .modelContainer(previewModelContainer)
    .environment(PersistenceCoordinator(previewModelContainer.mainContext))
    .preferredColorScheme(.dark)
}
