//
//  CastSection.swift
//  MovieTracker
//

import SwiftUI

/// Cast & crew for a detail screen: lead crew credit on top, a Cast/Guests/Crew picker below.
/// Shared by movie, show, and episode detail via its role/title parameters.
struct CastSection: View {
    let cast: [Person]
    /// Episode guest stars, surfaced as a separate "Guests" tab (empty elsewhere).
    var guests: [Person] = []
    var tint: Color = .appAccent
    /// An episode count describes a run, so a single episode's page has no use for one.
    var countsEpisodes: Bool = true
    /// The crew role surfaced above the tabs (Director for films, Creator for shows),
    /// matched exactly against a person's joined roles.
    var leadRole: String = "Director"
    var leadTitleSingular: String = "Director"
    var leadTitlePlural: String = "Directors"
    var castTitle: String = "Cast"
    /// How many cast members show before the "Show More" expander.
    var castLimit: Int = 10
    /// Global y below which this section's header counts as covered — the pinned header's edge.
    var coveredBelow: CGFloat = 0
    var onSearchHiddenChange: (DetailSearchRequest?) -> Void = { _ in }

    @State private var selection: CastCategory?
    @State private var castExpanded = false
    @AppStorage("castEpisodeCounts") private var showsEpisodeCounts = true

    /// Only TV credits carry a count, so only they get the control that hides it.
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

    /// A host-led show, where the episode's guests are its cast to a viewer, so the two share
    /// one list instead of hiding one behind a tab. Two regulars covers a host and a co-host.
    private var mergesGuests: Bool {
        (1...2).contains(castMembers.count) && guests.count > castMembers.count
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
                                       accessory: {
                                           HStack(spacing: 8) {
                                               DetailSearchButton(request: searchRequest)
                                               if hasEpisodeCounts {
                                                   CastCountsMenu(showsCounts: $showsEpisodeCounts,
                                                                  tint: tint)
                                               }
                                           }
                                       })
                        .onGeometryChange(for: Bool.self) { proxy in
                            proxy.frame(in: .global).maxY <= coveredBelow
                        } action: { covered in
                            onSearchHiddenChange(covered ? searchRequest : nil)
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
        let groups = [
            DetailSearchGroup(title: directors.count > 1 ? leadTitlePlural : leadTitleSingular,
                              content: .people(directors)),
            DetailSearchGroup(title: title(for: .cast), content: .people(members(for: .cast))),
            DetailSearchGroup(title: title(for: .guests), content: .people(members(for: .guests))),
            DetailSearchGroup(title: title(for: .crew), content: .people(members(for: .crew))),
        ].filter { $0.rowCount > 0 }
        return DetailSearchRequest(prompt: "Search Cast & Crew", groups: groups, tint: tint)
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

/// The cast section's filter: a tap shows or hides the episode counts, a long press opens the
/// same switch as a checklist.
private struct CastCountsMenu: View {
    @Binding var showsCounts: Bool
    let tint: Color

    var body: some View {
        Menu {
            Toggle("Episode Counts", isOn: $showsCounts)
        } label: {
            Image(systemName: "line.3.horizontal.decrease")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(showsCounts ? tint : .black)
                .filterOnBadge(!showsCounts, size: SectionHeaderControl.fill, color: tint)
                .sectionHeaderControl()
        } primaryAction: {
            showsCounts.toggle()
        }
        .buttonStyle(.plain)
        .accessibilityLabel(showsCounts ? "Hide episode counts" : "Show episode counts")
        .accessibilityHint("Touch and hold to choose what a cast row shows")
    }
}

// Hosted, so the search button is present and tapping it zooms into search in the canvas.
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
