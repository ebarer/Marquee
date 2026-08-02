//
//  ListEditorView.swift
//  MovieTracker
//
//  Create or edit a custom movie list: choose a name, a tint color, and an SF
//  Symbol icon, previewed together at the top. Built-in lists (To Watch /
//  Watched) are never edited here. Editing an existing custom list also offers
//  deletion (which cascades to its entries).
//

import SwiftUI
import SwiftData

struct ListEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(MediaStore.self) private var store: MediaStore?
    @Environment(\.dismiss) private var dismiss

    /// The list being edited, or `nil` when creating a new one.
    let existing: MediaList?
    /// Sort order to assign to a newly created list.
    var nextSortOrder: Int = 0
    var onSaved: (MediaList) -> Void = { _ in }
    var onDeleted: () -> Void = {}

    @State private var name: String
    @State private var symbol: String
    @State private var colorIndex: Int
    /// Raises the emoji keyboard to pick a single-emoji icon.
    @State private var emojiKeyboardActive = false

    /// A palette of icons suited to movie lists and leisure.
    private static let symbols = [
        "list.bullet", "star", "heart", "bookmark", "flag", "archivebox",
        "film", "popcorn", "ticket", "tv", "music.note", "gamecontroller",
        "graduationcap", "books.vertical", "crown", "sparkles", "flame", "eye",
        "clock", "moon.stars", "theatermasks", "hand.thumbsup", "figure.run", "fork.knife",
        "wineglass", "cup.and.saucer", "birthday.cake", "house", "building.2"
    ]

    private let symbolColumns = [GridItem(.adaptive(minimum: 52), spacing: 12)]
    private let colorColumns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 6)

    init(existing: MediaList?,
         nextSortOrder: Int = 0,
         onSaved: @escaping (MediaList) -> Void = { _ in },
         onDeleted: @escaping () -> Void = {}) {
        self.existing = existing
        self.nextSortOrder = nextSortOrder
        self.onSaved = onSaved
        self.onDeleted = onDeleted
        _name = State(initialValue: existing?.name ?? "")
        let storedSymbol = existing?.symbol ?? Self.symbols.first!
        // The picker works in canonical base names; normalize any stored
        // `.fill`/`.inverse` suffix (and legacy variants) back to the base.
        _symbol = State(initialValue: ListSymbol.canonical(storedSymbol))
        _colorIndex = State(initialValue: existing?.colorIndex ?? 0)
    }

    private var selectedColor: Color { Color.listColor(colorIndex) }

    var body: some View {
        Form {
            Section {
                iconPreview
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }

            Section {
                TextField("List Name", text: $name)
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(selectedColor)
                    // Pin the height so the row doesn't resize when the field
                    // becomes first responder (placeholder vs. caret metrics
                    // otherwise report slightly different intrinsic heights).
                    .frame(height: 28)
            }

            Section {
                colorPicker
            }

            Section {
                symbolPicker
            }

            if existing != nil {
                Section {
                    Button(role: .destructive, action: delete) {
                        // Color the label directly so the trash glyph turns red
                        // too — in a Form the symbol otherwise takes the app's
                        // accent tint, not the button's destructive role.
                        Label("Delete List", systemImage: "trash")
                            .foregroundStyle(.red)
                    }
                }
            }
        }
        .navigationTitle(existing == nil ? "New List" : "Edit List")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(role: .cancel) { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(role: .confirm, action: save)
                    .disabled(trimmedName.isEmpty)
            }
        }
    }

    // MARK: - Icon preview

    private var iconPreview: some View {
        // Matches how the icon appears elsewhere: a filled glyph (or the chosen
        // emoji) on the colored circle.
        ListIcon(symbol: symbol, color: selectedColor, size: 90, symbolSize: 40)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        // The emoji keyboard's hidden field lives up here (not in the symbol grid)
        // so raising it doesn't scroll the form down and hide this preview.
        .background {
            EmojiField(isActive: $emojiKeyboardActive) { emoji in
                symbol = emoji
            }
            .frame(width: 0, height: 0)
        }
    }

    // MARK: - Color picker

    private var colorPicker: some View {
        LazyVGrid(columns: colorColumns, spacing: 14) {
            ForEach(Array(Color.listPalette.enumerated()), id: \.offset) { index, color in
                Circle()
                    .fill(color)
                    .frame(width: 36, height: 36)
                    .overlay {
                        if index == colorIndex {
                            Circle()
                                .stroke(Color.secondary, lineWidth: 2)
                                .padding(-4)
                        }
                    }
                    .contentShape(Circle())
                    .onTapGesture { colorIndex = index }
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Symbol picker

    private var symbolPicker: some View {
        LazyVGrid(columns: symbolColumns, spacing: 12) {
            emojiCell
            ForEach(Self.symbols, id: \.self) { option in
                symbolCell(option)
            }
        }
        .padding(.vertical, 4)
    }

    /// The leading cell (Reminders-style): tap to pick a single emoji instead of
    /// an SF Symbol. Shows the chosen emoji once one is set.
    private var emojiCell: some View {
        let hasEmoji = ListSymbol.isEmoji(symbol)
        return Group {
            if hasEmoji {
                Text(symbol).font(.title3)
            } else {
                Image(systemName: "face.smiling.inverse")
                    .font(.title3)
                    .foregroundStyle(.black)
            }
        }
        .frame(width: 48, height: 48)
        .background(hasEmoji ? selectedColor : Color.appAccent, in: Circle())
        .overlay {
            if hasEmoji {
                Circle().stroke(selectedColor, lineWidth: 2).padding(-3)
            }
        }
        .contentShape(Circle())
        .onTapGesture { emojiKeyboardActive = true }
    }

    private func symbolCell(_ option: String) -> some View {
        let isSelected = option == symbol
        // The picker shows filled variants, matching the icon's final appearance.
        return Image(systemName: ListSymbol.solid(option))
            .font(.title3)
            .foregroundStyle(.white)
            .frame(width: 48, height: 48)
            .background(isSelected ? selectedColor : Color.appSeparator.opacity(0.6), in: Circle())
            .overlay {
                if isSelected {
                    Circle()
                        .stroke(selectedColor, lineWidth: 2)
                        .padding(-4)
                }
            }
            .contentShape(Circle())
            .onTapGesture { symbol = option }
    }

    // MARK: - Actions

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func save() {
        if let existing {
            existing.name = trimmedName
            existing.symbol = symbol
            existing.colorIndex = colorIndex
            store?.save()
            onSaved(existing)
        } else {
            let list = MediaList(name: trimmedName, symbol: symbol,
                                 sortOrder: nextSortOrder, colorIndex: colorIndex)
            context.insert(list)
            store?.save()
            onSaved(list)
        }
        dismiss()
    }

    private func delete() {
        guard let existing else { return }
        store?.deleteList(existing)
        onDeleted()
        dismiss()
    }
}

#Preview {
    NavigationStack {
        ListEditorView(existing: nil, nextSortOrder: 2)
    }
    .modelContainer(previewModelContainer)
    .preferredColorScheme(.dark)
}
