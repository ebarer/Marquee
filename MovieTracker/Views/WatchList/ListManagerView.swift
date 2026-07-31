//
//  ListManagerView.swift
//  MovieTracker
//
//  A modal for managing the user's custom lists in one place: reorder them,
//  delete them (which cascades to their entries), or tap one to edit its name,
//  color, and icon. The two built-in lists (Watch List / Watched) aren't shown
//  here since they can't be renamed, reordered, or removed.
//

import SwiftUI
import SwiftData

struct ListManagerView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query(sort: [SortDescriptor(\MovieList.sortOrder), SortDescriptor(\MovieList.createdAt)])
    private var lists: [MovieList]

    /// Only user-created lists, in display order — built-ins aren't managed here.
    private var customLists: [MovieList] { lists.filter { $0.kind == .custom } }

    /// The list currently open in the editor sheet, if any.
    @State private var editing: MovieList?
    /// Presents the editor for a brand-new list.
    @State private var creatingNew = false

    /// Higher-contrast tint shared by the row separators and the reorder gutter.
    private static let separator = Color.white.opacity(0.25)

    var body: some View {
        NavigationStack {
            List {
                ForEach(customLists) { list in
                    HStack(spacing: 0) {
                        ListIcon(list, size: 38, symbolSize: 18)
                            .padding(.trailing, 14)

                        Text(list.name)
                            .foregroundStyle(.primary)
                            // Start the row separator at the title, not under
                            // the circle.
                            .alignmentGuide(.listRowSeparatorLeading) { $0[.leading] }

                        Spacer(minLength: 12)

                        // Only the info button opens the editor; the rest of the
                        // row is inert (reordering/deleting use the edit controls).
                        Button {
                            editing = list
                        } label: {
                            Image(systemName: "info.circle")
                                .font(.title2)
                                .fontWeight(.light)
                        }
                        .buttonStyle(.borderless)

                        // Full-height reorder-gutter line with equal padding on
                        // both sides, echoing the divider UIKit draws next to the
                        // reorder grip. A Rectangle so we control its contrast.
                        Rectangle()
                            .fill(Self.separator)
                            .frame(width: 1)
                            .padding(.horizontal, 14)
                    }
                    .frame(minHeight: 60)
                    // Zero vertical inset so the gutter line meets the row separators.
                    .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 0))
                    .listRowSeparatorTint(Self.separator)
                }
                .onDelete(perform: delete)
                .onMove(perform: move)
            }
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
            .overlay {
                if customLists.isEmpty {
                    ContentUnavailableView(
                        "No Custom Lists",
                        systemImage: "list.bullet",
                        description: Text("Create a list from the menu on the Lists screen.")
                    )
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
