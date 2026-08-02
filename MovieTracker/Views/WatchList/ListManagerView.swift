//
//  ListManagerView.swift
//  MovieTracker
//
//  A modal for reordering, deleting, and editing custom lists. The Watch List,
//  Watched, and Viewed are shown for context (with counts) but pinned and inert.
//

import SwiftUI
import SwiftData

struct ListManagerView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query(sort: [SortDescriptor(\MediaList.sortOrder), SortDescriptor(\MediaList.createdAt)])
    private var lists: [MediaList]
    @Query private var trackedItems: [MediaItem]
    @Environment(MediaStore.self) private var store: MediaStore?

    private var visibleLists: [MediaList] { lists.filter { !$0.isDeduplicated } }
    private var watchList: MediaList? { visibleLists.first { $0.isWatchList } }
    private var customLists: [MediaList] { visibleLists.filter { !$0.isWatchList } }

    private var watchedCount: Int { trackedItems.lazy.filter { $0.watchedAt != nil }.count }
    private var viewedCount: Int { trackedItems.lazy.filter { $0.lastViewedAt != nil }.count }

    @State private var editing: MediaList?
    @State private var creatingNew = false

    private static let separator = Color.white.opacity(0.25)

    var body: some View {
        NavigationStack {
            List {
                // Built-in views pinned at the top — shown for context, not editable.
                Section {
                    if let watchList {
                        row(for: watchList, editable: false)
                            .moveDisabled(true)
                            .deleteDisabled(true)
                    }
                    virtualRow(title: "Watched", symbol: "checkmark.rectangle.stack",
                               color: Color(red255: 90, green255: 200, blue255: 250), count: watchedCount)
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

                // The Viewed history pinned at the bottom.
                Section {
                    virtualRow(title: "Viewed", symbol: "clock.arrow.circlepath",
                               color: .gray, count: viewedCount)
                }
            }
            .listStyle(.insetGrouped)
            // The whole point of this screen is reordering/deleting, so it stays in
            // edit mode permanently rather than gating that behind an Edit button.
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
                    // Custom lists sit after the Watch List (order 0).
                    ListEditorView(existing: nil, nextSortOrder: 1 + customLists.count)
                }
            }
        }
    }

    // MARK: - Rows

    private func row(for list: MediaList, editable: Bool) -> some View {
        HStack(spacing: 0) {
            ListIcon(list, size: 38, symbolSize: 18)
                .padding(.trailing, 14)

            VStack(alignment: .leading, spacing: 2) {
                Text(list.name)
                    .foregroundStyle(.primary)
                Text(countText((list.entries ?? []).count))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .alignmentGuide(.listRowSeparatorLeading) { $0[.leading] }

            Spacer(minLength: 12)

            if editable {
                Button {
                    editing = list
                } label: {
                    Image(systemName: "info.circle")
                        .font(.title2)
                        .fontWeight(.light)
                }
                .buttonStyle(.borderless)

                // Full-height reorder-gutter line echoing the UIKit reorder divider.
                Rectangle()
                    .fill(Self.separator)
                    .frame(width: 1)
                    .padding(.horizontal, 14)
            }
        }
        .frame(minHeight: 60)
        .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: editable ? 0 : 20))
        .listRowSeparatorTint(Self.separator)
    }

    /// An inert row for a derived view (Watched / Viewed), shown for context.
    private func virtualRow(title: String, symbol: String, color: Color, count: Int) -> some View {
        HStack(spacing: 0) {
            ListIcon(symbol: symbol, color: color, size: 38, symbolSize: 18)
                .padding(.trailing, 14)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .foregroundStyle(.primary)
                Text(countText(count))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .alignmentGuide(.listRowSeparatorLeading) { $0[.leading] }

            Spacer(minLength: 12)
        }
        .frame(minHeight: 60)
        .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
        .listRowSeparatorTint(Self.separator)
        .moveDisabled(true)
        .deleteDisabled(true)
    }

    private func countText(_ count: Int) -> String {
        "\(count) \(count == 1 ? "movie" : "movies")"
    }

    // MARK: - Actions

    private func delete(at offsets: IndexSet) {
        let toDelete = offsets.map { customLists[$0] }
        store?.perform { toDelete.forEach { context.delete($0) } }
    }

    /// Reorders custom lists and rewrites their sort orders (starting at 1, after
    /// the Watch List at 0).
    private func move(from source: IndexSet, to destination: Int) {
        store?.perform {
            var reordered = customLists
            reordered.move(fromOffsets: source, toOffset: destination)
            for (index, list) in reordered.enumerated() {
                list.sortOrder = 1 + index
            }
        }
    }
}

#Preview {
    ListManagerView()
        .modelContainer(previewModelContainer)
        .preferredColorScheme(.dark)
}
