//
//  MovieCastSection.swift
//  MovieTracker
//

import SwiftUI

/// Cast & crew on the movie detail screen, with directors surfaced at the top.
struct MovieCastSection: View {
    let cast: [Person]
    /// Episode guest stars, surfaced as a separate "Guests" tab (empty elsewhere).
    var guests: [Person] = []
    var tint: Color = .appAccent
    /// The crew role surfaced above the cast/crew tabs (Director for films,
    /// Creator for shows), matched exactly against a person's joined roles.
    var leadRole: String = "Director"
    var leadTitleSingular: String = "Director"
    var leadTitlePlural: String = "Directors"
    /// The heading for the cast tab ("Cast" for films, "Recurring Cast" for shows).
    var castTitle: String = "Cast"
    /// How many cast members show before the "Show More" expander.
    var castLimit: Int = 10

    @State private var selection: Category?
    @State private var castExpanded = false

    enum Category: CaseIterable {
        case cast, guests, crew
        var title: String {
            switch self {
            case .cast: return "Cast"
            case .guests: return "Guests"
            case .crew: return "Crew"
            }
        }
    }

    private var castMembers: [Person] { cast.filter { $0.type == .Cast } }

    /// Crew whose joined roles include an exact lead credit (so "Art Director" or
    /// "Director of Photography" don't match "Director"). Shown above the crew list.
    private var directors: [Person] {
        cast.filter { $0.type == .Crew && isLead($0) }
    }

    private var crewMembers: [Person] {
        cast.filter { $0.type == .Crew && !isLead($0) }
    }

    private func isLead(_ person: Person) -> Bool {
        (person.role ?? "").components(separatedBy: ", ").contains(leadRole)
    }

    /// The displayed heading for a category — the cast tab honors `castTitle`.
    private func title(for category: Category) -> String {
        category == .cast ? castTitle : category.title
    }

    private func members(for category: Category) -> [Person] {
        switch category {
        case .cast: return castMembers
        case .guests: return guests
        case .crew: return crewMembers
        }
    }

    private var availableCategories: [Category] {
        Category.allCases.filter { !members(for: $0).isEmpty }
    }

    private var currentCategory: Category? {
        if let selection, availableCategories.contains(selection) { return selection }
        return availableCategories.first
    }

    var body: some View {
        if !directors.isEmpty || currentCategory != nil {
            VStack(spacing: 0) {
                if !directors.isEmpty {
                    SectionHeader(title: directors.count > 1 ? leadTitlePlural : leadTitleSingular)
                    personList(directors)
                }
                if let category = currentCategory {
                    categoryHeader(category)
                    categoryList(category)
                        // New identity per category so switching crossfades the list.
                        .id(category)
                        .transition(.opacity)
                }
            }
        }
    }

    @ViewBuilder
    private func categoryHeader(_ category: Category) -> some View {
        let categories = availableCategories
        if categories.count > 1 {
            Menu {
                ForEach(categories, id: \.self) { option in
                    Button {
                        withAnimation(.easeInOut) { selection = option }
                    } label: {
                        if option == category {
                            Label(title(for: option), systemImage: "checkmark")
                        } else {
                            Text(title(for: option))
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(title(for: category))
                        .font(.headline)
                        .foregroundStyle(.white)
                    Image(systemName: "chevron.down")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(tint)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        } else {
            SectionHeader(title: title(for: category))
        }
    }

    @ViewBuilder
    private func categoryList(_ category: Category) -> some View {
        let all = members(for: category)
        let expandable = category == .cast && all.count > castLimit
        let collapsed = expandable && !castExpanded
        let shown = collapsed ? Array(all.prefix(castLimit)) : all
        VStack(spacing: 0) {
            personList(shown)
            if expandable {
                rowSeparator
                expandToggleRow(collapsed: collapsed, remaining: all.count - castLimit)
            }
        }
    }

    private func personList(_ people: [Person]) -> some View {
        LazyVStack(spacing: 0) {
            ForEach(Array(people.enumerated()), id: \.element.id) { index, person in
                NavigationLink(value: person) {
                    HStack(spacing: 8) {
                        PersonRow(person: person)
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if index < people.count - 1 {
                    rowSeparator
                }
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

    private var rowSeparator: some View {
        Rectangle()
            .fill(Color.appSeparator)
            .frame(height: 0.5)
            .padding(.leading, 72)
    }
}

#Preview {
    NavigationStack {
        ScrollView {
            MovieCastSection(cast: Movie.preview.team)
        }
        .detailDestinations()
    }
    .background(Color.appBackground)
    .preferredColorScheme(.dark)
}
