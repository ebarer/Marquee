//
//  CastCategoryPicker.swift
//  MovieTracker
//

import SwiftUI

/// The cast/guests/crew categories a ``CastSection`` can show.
enum CastCategory: CaseIterable {
    case cast, guests, crew
    var title: String {
        switch self {
        case .cast: return "Cast"
        case .guests: return "Guests"
        case .crew: return "Crew"
        }
    }
}

/// The category heading for a cast section — a Menu when more than one category exists,
/// otherwise a plain title — with room for a trailing control opposite it.
struct CastCategoryPicker<Accessory: View>: View {
    let categories: [CastCategory]
    let current: CastCategory
    let tint: Color
    let titleFor: (CastCategory) -> String
    let onSelect: (CastCategory) -> Void
    @ViewBuilder var accessory: () -> Accessory

    private var selection: Binding<CastCategory> {
        Binding(get: { current }, set: { onSelect($0) })
    }

    // Metrics match `SectionHeader`, so a section with categories lines up with one without.
    var body: some View {
        HStack(spacing: 0) {
            if categories.count > 1 {
                categoryMenu
            } else {
                Text(titleFor(current))
                    .font(.headline)
                    .foregroundStyle(.white)
            }
            Spacer(minLength: 8)
            accessory()
        }
        // Width goes outside the Menu, as in `SeasonHeader`: a label as wide as the iPad
        // detail sheet makes UIKit take the sheet as the menu's source and hide it.
        .sectionHeaderInsets()
    }

    private var categoryMenu: some View {
        // A styled label backed by an embedded Picker: the menu keeps the standard
        // checkmark gutter while the category reads as a section title.
        Menu {
            Picker("Category", selection: selection) {
                ForEach(categories, id: \.self) { option in
                    Text(titleFor(option)).tag(option)
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(titleFor(current))
                    .font(.headline)
                    .foregroundStyle(.white)
                Image(systemName: "chevron.down")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(tint)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

extension CastCategoryPicker where Accessory == EmptyView {
    init(categories: [CastCategory], current: CastCategory, tint: Color,
         titleFor: @escaping (CastCategory) -> String,
         onSelect: @escaping (CastCategory) -> Void) {
        self.init(categories: categories, current: current, tint: tint,
                  titleFor: titleFor, onSelect: onSelect, accessory: { EmptyView() })
    }
}

#Preview {
    VStack(spacing: 24) {
        CastCategoryPicker(categories: [.cast, .crew], current: .cast, tint: .appAccent,
                           titleFor: { $0.title }, onSelect: { _ in })
        CastCategoryPicker(categories: [.cast], current: .cast, tint: .appAccent,
                           titleFor: { $0.title }, onSelect: { _ in })
    }
    .background(Color.appBackground)
    .preferredColorScheme(.dark)
}
