//
//  MovieCastSection.swift
//  MovieTracker
//

import SwiftUI

/// Cast & crew on the movie detail screen. The director(s) sit at the top under
/// their own header; below, a menu switches between the full cast (shown ten at a
/// time behind a "show more" row) and the rest of the crew. Each row navigates to
/// the person's detail.
struct MovieCastSection: View {
    let cast: [Person]
    var tint: Color = .appAccent

    /// The user's pick from the category menu; nil follows the default (first available).
    @State private var selection: Category?
    /// Whether the full cast is revealed past the initial cap.
    @State private var castExpanded = false

    /// How many cast rows show before the "show more" row appears.
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

    /// Crew whose joined roles include an exact "Director" credit (so "Art
    /// Director" or "Director of Photography" don't match). Shown above, not in the
    /// crew list.
    private var directors: [Person] {
        cast.filter { $0.type == .Crew && isDirector($0) }
    }

    /// Crew other than the directors already surfaced at the top.
    private var crewMembers: [Person] {
        cast.filter { $0.type == .Crew && !isDirector($0) }
    }

    private func isDirector(_ person: Person) -> Bool {
        (person.role ?? "").components(separatedBy: ", ").contains("Director")
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
                    SectionHeader(title: directors.count > 1 ? "Directors" : "Director")
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

    /// A menu header styled like the Related/Recommendations switcher; falls back
    /// to a plain header when only one category is available.
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
        // Only the cast is capped; crew shows in full.
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

    /// Hairline inset to start under the name, past the avatar.
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
