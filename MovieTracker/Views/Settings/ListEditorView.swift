//
//  ListEditorView.swift
//  MovieTracker
//
//  Create or edit a custom list: name, tint color, and SF Symbol / emoji icon.
//

import SwiftUI
import SwiftData

struct ListEditorView: View {
    @Environment(PersistenceCoordinator.self) private var store: PersistenceCoordinator?
    @Environment(\.dismiss) private var dismiss

    let existing: MediaList?
    var nextSortOrder: Int = 0
    var onSaved: (MediaList) -> Void = { _ in }
    var onDeleted: () -> Void = {}

    @State private var name: String
    @State private var symbol: String
    @State private var colorIndex: Int
    @State private var customColor: Color?
    @State private var emojiKeyboardActive = false
    @FocusState private var nameFocused: Bool

    private static let symbols = [
        "list.bullet", "star", "heart", "bookmark", "flag", "eye",
        "film", "movieclapper", "popcorn", "ticket", "tv", "play.rectangle",
        "video", "camera", "theatermasks", "crown", "trophy", "sparkles",
        "music.note", "headphones", "guitars", "mic", "gamecontroller", "puzzlepiece",
        "paintpalette", "books.vertical", "graduationcap", "flame", "cloud", "moon.stars",
        "clock", "hand.thumbsup", "gift", "birthday.cake", "figure.run", "fork.knife",
        "wineglass", "cup.and.saucer", "house", "building.2", "archivebox"
    ]

    private let colorColumns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 6)
    private var symbolColumns: [GridItem] { colorColumns }

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
        // The picker works in canonical base names; strip any stored `.fill`/`.inverse` suffix.
        _symbol = State(initialValue: ListSymbol.canonical(storedSymbol))
        _colorIndex = State(initialValue: existing?.colorIndex ?? 0)
        let storedHex = existing?.customColorHex
        _customColor = State(initialValue: storedHex.flatMap { Color(hex: $0) })
    }

    private var selectedColor: Color { customColor ?? Color.listColor(colorIndex) }

    private var customColorBinding: Binding<Color> {
        Binding(get: { selectedColor }, set: { customColor = $0 })
    }

    /// A brand-new list with any user input; blocks accidental drag-to-dismiss.
    private var hasUnsavedInput: Bool {
        guard existing == nil else { return false }
        return !trimmedName.isEmpty
            || colorIndex != 0
            || customColor != nil
            || symbol != ListSymbol.canonical(Self.symbols.first!)
    }

    var body: some View {
        Form {
            Section {
                iconPreview
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }

            Section {
                TextField("List Name", text: $name)
                    .focused($nameFocused)
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(selectedColor)
                    // Pin the height so the row doesn't resize when the field becomes first responder.
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
                        // In a Form the symbol takes the accent tint, not the destructive role; color it directly.
                        Label("Delete List", systemImage: "trash")
                            .foregroundStyle(.red)
                    }
                }
            }
        }
        .listSectionSpacing(18)
        .contentMargins(.top, 10, for: .scrollContent)
        .onAppear { if existing == nil { nameFocused = true } }
        .navigationTitle(existing == nil ? "New List" : "Edit List")
        .navigationBarTitleDisplayMode(.inline)
        .interactiveDismissDisabled(hasUnsavedInput)
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
        ListEditorIcon(symbol: symbol, color: selectedColor)
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
        // Emoji keyboard's hidden field lives here, not in the grid, so raising it doesn't scroll the preview away.
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
                        if customColor == nil && index == colorIndex {
                            Circle()
                                .stroke(Color.secondary, lineWidth: 2)
                                .padding(-4)
                        }
                    }
                    .contentShape(Circle())
                    .onTapGesture {
                        colorIndex = index
                        customColor = nil
                    }
            }
            customColorCell
        }
        .padding(.vertical, 4)
    }

    /// Its native ~28pt swatch is scaled up to match the 36pt palette circles.
    private var customColorCell: some View {
        ColorPicker(selection: customColorBinding, supportsOpacity: false) {
            EmptyView()
        }
        .labelsHidden()
        .scaleEffect(36.0 / 28.0)
    }

    // MARK: - Symbol picker

    private var symbolPicker: some View {
        LazyVGrid(columns: symbolColumns, spacing: 14) {
            emojiCell
            ForEach(Self.symbols, id: \.self) { option in
                symbolCell(option)
            }
        }
        .padding(.vertical, 4)
    }

    private var emojiCell: some View {
        let hasEmoji = ListSymbol.isEmoji(symbol)
        return Group {
            if hasEmoji {
                Text(symbol).font(.system(size: 18))
            } else {
                Image(systemName: "face.smiling")
                    .font(.system(size: 24))
                    .foregroundStyle(Color(red255: 236, green255: 224, blue255: 190))
            }
        }
        .frame(width: 36, height: 36)
        .background(hasEmoji ? selectedColor : Color.appAccent, in: Circle())
        .overlay {
            if hasEmoji {
                Circle().stroke(selectedColor, lineWidth: 2).padding(-4)
            }
        }
        .contentShape(Circle())
        .onTapGesture { emojiKeyboardActive = true }
    }

    private func symbolCell(_ option: String) -> some View {
        let isSelected = option == symbol
        return Image(systemName: ListSymbol.solid(option))
            .font(.system(size: 16))
            .foregroundStyle(.white)
            .frame(width: 36, height: 36)
            .background(isSelected ? selectedColor : Color(white: 0.26), in: Circle())
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
            existing.customColorHex = customColor?.hexString
            store?.save()
            onSaved(existing)
        } else {
            let list = MediaList(name: trimmedName, symbol: symbol,
                                 sortOrder: nextSortOrder, colorIndex: colorIndex)
            list.customColorHex = customColor?.hexString
            store?.insert(list)
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
