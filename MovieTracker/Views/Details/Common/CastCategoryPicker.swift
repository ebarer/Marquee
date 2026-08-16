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
/// otherwise a plain section header.
struct CastCategoryPicker: View {
    let categories: [CastCategory]
    let current: CastCategory
    let tint: Color
    let titleFor: (CastCategory) -> String
    let onSelect: (CastCategory) -> Void

    private var selection: Binding<CastCategory> {
        Binding(get: { current }, set: { onSelect($0) })
    }

    var body: some View {
        if categories.count > 1 {
            // A styled label backed by an embedded Picker, as in `SeasonHeader`: the menu keeps
            // the standard checkmark gutter while the category reads as a section title.
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
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        } else {
            SectionHeader(title: titleFor(current))
        }
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
