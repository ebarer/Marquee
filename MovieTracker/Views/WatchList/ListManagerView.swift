//
//  ListManagerView.swift
//  MovieTracker
//
//  A modal for reordering, deleting, and editing custom lists. Built-in lists are
//  shown for context (with counts) but pinned and inert.
//

import SwiftUI
import SwiftData

struct ListManagerView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query(sort: [SortDescriptor(\MovieList.sortOrder), SortDescriptor(\MovieList.createdAt)])
    private var lists: [MovieList]

    /// Live lists only (duplicates awaiting cleanup are hidden).
    private var visibleLists: [MovieList] { lists.filter { !$0.isDeduplicated } }

    /// Built-in lists pinned to the top, in order (Watch List, then Watched).
    private var pinnedTop: [MovieList] {
        [ListKind.toWatch, .watched].compactMap { kind in
            visibleLists.first { $0.kind == kind }
        }
    }

    /// User-created lists, in display order.
    private var customLists: [MovieList] { visibleLists.filter { $0.kind == .custom } }

    /// The Viewed history, pinned to the bottom.
    private var viewedList: MovieList? { visibleLists.first { $0.kind == .viewed } }

    /// The list currently open in the editor sheet, if any.
    @State private var editing: MovieList?
    /// Presents the editor for a brand-new list.
    @State private var creatingNew = false

    /// Higher-contrast tint shared by the row separators and the reorder gutter.
    private static let separator = Color.white.opacity(0.25)

    var body: some View {
        NavigationStack {
            List {
                // Built-in lists pinned at the top — shown for context, not editable.
                Section {
                    ForEach(pinnedTop) { list in
                        row(for: list, editable: false)
                            .moveDisabled(true)
                            .deleteDisabled(true)
                    }
                }

                // Custom lists: reorderable and deletable.
                Section {
                    if customLists.isEmpty {
                        Text("No custom lists yet")
                            .foregroundStyle(.secondary)
                            .moveDisabled(true)
                            .deleteDisabled(true)
                    } else {
                        ForEach(customLists) { list in
                            row(for: list, editable: true)
                        }
                        .onDelete(perform: delete)
                        .onMove(perform: move)
                    }
                }

                // The Viewed history pinned at the bottom — not editable.
                if let viewedList {
                    Section {
                        row(for: viewedList, editable: false)
                            .moveDisabled(true)
                            .deleteDisabled(true)
                    }
                }
            }
            .listStyle(.insetGrouped)
            // The whole point of this screen is reordering/deleting, so it stays
            // in edit mode permanently rather than gating that behind an Edit button.
            .environment(\.editMode, .constant(.active))
            .navigationTitle("Edit Lists")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        creatingNew = true
                    } label: {
                        Label("New List", systemImage: "plus")
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .confirm) { dismiss() }
                }
            }
            .sheet(item: $editing) { list in
                NavigationStack {
                    ListEditorView(existing: list)
                }
            }
            .sheet(isPresented: $creatingNew) {
                NavigationStack {
                    // Custom lists sit after the two built-ins (orders 0 and 1).
                    ListEditorView(existing: nil, nextSortOrder: 2 + customLists.count)
                }
            }
        }
    }

    // MARK: - Row

    /// One list row: icon, name, and a movie-count subtitle. Custom (`editable`)
    /// rows also carry the info button that opens the editor plus the reorder
    /// gutter; built-in rows are inert.
    private func row(for list: MovieList, editable: Bool) -> some View {
        HStack(spacing: 0) {
            ListIcon(list, size: 38, symbolSize: 18)
                .padding(.trailing, 14)

            VStack(alignment: .leading, spacing: 2) {
                Text(list.name)
                    .foregroundStyle(.primary)
                Text(countText(for: list))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            // Start the row separator at the title, not under the circle.
            .alignmentGuide(.listRowSeparatorLeading) { $0[.leading] }

            Spacer(minLength: 12)

            if editable {
                // Only the info button opens the editor; the rest of the row is
                // inert (reordering/deleting use the edit controls).
                Button {
                    editing = list
                } label: {
                    Image(systemName: "info.circle")
                        .font(.title2)
                        .fontWeight(.light)
                }
                .buttonStyle(.borderless)

                // Full-height reorder-gutter line echoing the divider UIKit draws
                // next to the reorder grip. A Rectangle so we control its contrast.
                Rectangle()
                    .fill(Self.separator)
                    .frame(width: 1)
                    .padding(.horizontal, 14)
            }
        }
        .frame(minHeight: 60)
        // Zero vertical inset so the gutter line meets the row separators.
        .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: editable ? 0 : 20))
        .listRowSeparatorTint(Self.separator)
    }

    /// "12 movies" / "1 movie" for a list's current entry count.
    private func countText(for list: MovieList) -> String {
        let count = (list.entries ?? []).count
        return "\(count) \(count == 1 ? "movie" : "movies")"
    }

    // MARK: - Actions

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            context.delete(customLists[index])
        }
    }

    /// Reorders custom lists and rewrites their sort orders. Custom lists always
    /// sit after the two built-ins (whose sort orders are 0 and 1), so numbering
    /// starts at 2.
    private func move(from source: IndexSet, to destination: Int) {
        var reordered = customLists
        reordered.move(fromOffsets: source, toOffset: destination)
        for (index, list) in reordered.enumerated() {
            list.sortOrder = 2 + index
        }
    }
}

#Preview {
    ListManagerView()
        .modelContainer(previewModelContainer)
        .preferredColorScheme(.dark)
}
