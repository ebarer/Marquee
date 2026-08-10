//
//  CastSection.swift
//  MovieTracker
//

import SwiftUI

/// Cast & crew for a detail screen, with the lead crew credit (Director / Creator) surfaced
/// at the top and a category picker (Cast / Guests / Crew) below. Shared by movie, show,
/// and episode detail via its role/title parameters.
struct CastSection: View {
    let cast: [Person]
    /// Episode guest stars, surfaced as a separate "Guests" tab (empty elsewhere).
    var guests: [Person] = []
    var tint: Color = .appAccent
    /// The crew role surfaced above the tabs (Director for films, Creator for shows),
    /// matched exactly against a person's joined roles.
    var leadRole: String = "Director"
    var leadTitleSingular: String = "Director"
    var leadTitlePlural: String = "Directors"
    var castTitle: String = "Cast"
    /// How many cast members show before the "Show More" expander.
    var castLimit: Int = 10

    @State private var selection: CastCategory?
    @State private var castExpanded = false

    private var castMembers: [Person] { cast.filter { $0.type == .Cast } }

    // Crew whose joined roles include an exact lead credit (so "Art Director" doesn't
    // match "Director"). Shown above the crew list.
    private var directors: [Person] { cast.filter { $0.type == .Crew && isLead($0) } }
    private var crewMembers: [Person] { cast.filter { $0.type == .Crew && !isLead($0) } }

    private func isLead(_ person: Person) -> Bool {
        (person.role ?? "").components(separatedBy: ", ").contains(leadRole)
    }

    private func title(for category: CastCategory) -> String {
        category == .cast ? castTitle : category.title
    }

    private func members(for category: CastCategory) -> [Person] {
        switch category {
        case .cast: return castMembers
        case .guests: return guests
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
                                       tint: tint, titleFor: title(for:)) { option in
                        withAnimation(.easeInOut) { selection = option }
                    }
                    categoryList(category)
                        // New identity per category so switching crossfades the list.
                        .id(category)
                        .transition(.opacity)
                }
            }
        }
    }

    @ViewBuilder
    private func categoryList(_ category: CastCategory) -> some View {
        let all = members(for: category)
        let expandable = category == .cast && all.count > castLimit
        let collapsed = expandable && !castExpanded
        let shown = collapsed ? Array(all.prefix(castLimit)) : all
        VStack(spacing: 0) {
            CastPersonList(people: shown)
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
    }
    .background(Color.appBackground)
    .preferredColorScheme(.dark)
}
