//
//  MovieCastSection.swift
//  MovieTracker
//

import SwiftUI

/// Cast & crew on the movie detail screen, with directors surfaced at the top.
struct MovieCastSection: View {
    let cast: [Person]
    var tint: Color = .appAccent
    /// The crew role surfaced above the cast/crew tabs (Director for films,
    /// Creator for shows), matched exactly against a person's joined roles.
    var leadRole: String = "Director"
    var leadTitleSingular: String = "Director"
    var leadTitlePlural: String = "Directors"

    @State private var selection: Category?
    @State private var castExpanded = false

    private let castLimit = 10

    enum Category: CaseIterable {
        case cast, crew
        var title: String {
            switch self {
            case .cast: return "Cast"
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

    private func members(for category: Category) -> [Person] {
        switch category {
        case .cast: return castMembers
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
                            Label(option.title, systemImage: "checkmark")
                        } else {
                            Text(option.title)
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(category.title)
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
            SectionHeader(title: category.title)
        }
    }

    @ViewBuilder
    private func categoryList(_ category: Category) -> some View {
        let all = members(for: category)
        let collapsed = category == .cast && !castExpanded && all.count > castLimit
        let shown = collapsed ? Array(all.prefix(castLimit)) : all
        VStack(spacing: 0) {
            personList(shown)
            if collapsed {
                rowSeparator
                showMoreRow(remaining: all.count - castLimit)
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

    private func showMoreRow(remaining: Int) -> some View {
        Button {
            withAnimation(.easeInOut) { castExpanded = true }
        } label: {
            HStack(spacing: 6) {
                Text("Show \(remaining) More")
                    .font(.subheadline.weight(.semibold))
                Image(systemName: "chevron.down")
                    .font(.footnote.weight(.semibold))
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
