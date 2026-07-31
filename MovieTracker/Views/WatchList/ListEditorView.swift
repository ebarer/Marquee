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
    @Environment(\.dismiss) private var dismiss

    /// The list being edited, or `nil` when creating a new one.
    let existing: MovieList?
    /// Sort order to assign to a newly created list.
    var nextSortOrder: Int = 0
    var onSaved: (MovieList) -> Void = { _ in }
    var onDeleted: () -> Void = {}

    @State private var name: String
    @State private var symbol: String
    @State private var colorIndex: Int

    /// A palette of icons suited to movie lists and leisure.
    private static let symbols = [
        "list.bullet", "star", "heart", "bookmark", "flag", "gift",
        "film", "popcorn", "ticket", "tv", "music.note", "gamecontroller",
        "graduationcap", "books.vertical", "crown", "sparkles", "flame", "eye",
        "clock", "moon.stars", "face.smiling", "hand.thumbsup", "figure.run", "fork.knife",
        "wineglass", "cup.and.saucer", "birthday.cake", "house", "building.2", "building.columns"
    ]

    private let symbolColumns = [GridItem(.adaptive(minimum: 52), spacing: 12)]
    private let colorColumns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 6)

    init(existing: MovieList?,
         nextSortOrder: Int = 0,
         onSaved: @escaping (MovieList) -> Void = { _ in },
         onDeleted: @escaping () -> Void = {}) {
        self.existing = existing
        self.nextSortOrder = nextSortOrder
        self.onSaved = onSaved
        self.onDeleted = onDeleted
        _name = State(initialValue: existing?.name ?? "")
        let storedSymbol = existing?.symbol ?? Self.symbols.first!
        // Selector works with outline base names; strip any stored `.fill` suffix.
        _symbol = State(initialValue: storedSymbol.hasSuffix(".fill")
                        ? String(storedSymbol.dropLast(5))
                        : storedSymbol)
        _colorIndex = State(initialValue: existing?.colorIndex ?? 0)
    }

    private var selectedColor: Color { Color.listColor(colorIndex) }

    /// The filled variant of an SF Symbol when one exists, otherwise the base
    /// name. New lists prefer `.fill` icons; the selector still shows outlines.
    private func filled(_ base: String) -> String {
        let candidate = base + ".fill"
        return UIImage(systemName: candidate) != nil ? candidate : base
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
                        Label("Delete List", systemImage: "trash")
                    }
                    .tint(.red)
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
        ZStack {
            Circle()
                .fill(selectedColor)
                .frame(width: 90, height: 90)
            Image(systemName: filled(symbol))
                .font(.system(size: 40))
                .foregroundStyle(.white)
        }
        .shadow(color: .black.opacity(0.5), radius: 8, y: 4)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
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
            ForEach(Self.symbols, id: \.self) { option in
                symbolCell(option)
            }
        }
        .padding(.vertical, 4)
    }

    private func symbolCell(_ option: String) -> some View {
        let isSelected = option == symbol
        return Image(systemName: option)
            .font(.title3)
            .foregroundStyle(.white)
            .frame(width: 48, height: 48)
            .background(Color.appSeparator.opacity(0.6), in: Circle())
            .overlay {
                if isSelected {
                    Circle()
                        .stroke(selectedColor, lineWidth: 2)
                        .padding(-3)
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
            existing.symbol = filled(symbol)
            existing.colorIndex = colorIndex
            onSaved(existing)
        } else {
            let list = MovieList(name: trimmedName, symbol: filled(symbol), kind: .custom,
                                 sortOrder: nextSortOrder, colorIndex: colorIndex)
            context.insert(list)
            onSaved(list)
        }
        dismiss()
    }

    private func delete() {
        guard let existing else { return }
        context.delete(existing)
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
