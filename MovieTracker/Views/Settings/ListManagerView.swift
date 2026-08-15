//
//  ListManagerView.swift
//  MovieTracker
//
//  A modal for reordering, deleting, and editing custom lists.
//

import SwiftUI
import SwiftData

struct ListManagerView: View {
    @Environment(\.dismiss) private var dismiss

    @Query(sort: [SortDescriptor(\MediaList.sortOrder), SortDescriptor(\MediaList.createdAt)])
    private var lists: [MediaList]
    @Environment(PersistenceCoordinator.self) private var store: PersistenceCoordinator?

    private var visibleLists: [MediaList] {
        store?.canonicalLists(lists) ?? lists.filter { !$0.isDeduplicated }
    }
    private var watchList: MediaList? { visibleLists.first { $0.isWatchList } }
    private var customLists: [MediaList] { visibleLists.filter { !$0.isWatchList } }

    /// One past the highest custom sort order so new lists land at the bottom.
    /// Orders can be non-contiguous (e.g. after an import), so use max + 1, not count.
    private var nextCustomSortOrder: Int {
        (customLists.map(\.sortOrder).max() ?? 0) + 1
    }

    // Same counts the list titles show. They come from a fetch, not an observed property,
    // so touch `revision` to re-read them after any write (else these rows stay stale).
    private var watchedCount: Int { count(for: .watched) }
    private var viewedCount: Int { count(for: .viewed) }

    private func count(for selection: ListSelection) -> Int {
        _ = store?.revision
        return ListDestination.resolve(selection, lists: visibleLists).mediaCount(using: store)
    }

    @State private var editing: MediaList?
    @State private var creatingNew = false
    // One destination for both pushes; two `navigationDestination(isPresented:)` conflict.
    @State private var pushed: ManagerDestination?
#if targetEnvironment(simulator)
    @State private var confirmingReset = false
#endif

    private enum ManagerDestination: Hashable {
        case cache, services
    }

    private static let separator = Color.white.opacity(0.25)

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if let watchList {
                        row(for: watchList, editable: false)
                            .moveDisabled(true)
                            .deleteDisabled(true)
                    }
                    virtualRow(title: "Watched", symbol: "checkmark.rectangle.stack",
                               color: ListDestination.watchedColor, count: watchedCount)
                }

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

                Section {
                    virtualRow(title: "Viewed", symbol: "clock.arrow.circlepath",
                               color: ListDestination.viewedColor, count: viewedCount)
                }

                Section {
#if targetEnvironment(simulator)
                    // Import/export are useless in a bare simulator; seed sample data or wipe instead.
                    Button {
                        if let store, let summary = SimulatorTools.populate(using: store) {
                            ImportExportCoordinator.shared.importSummary = summary
                        }
                    } label: {
                        Label("Populate", systemImage: "wand.and.stars")
                            .foregroundStyle(Color.appAccent)
                    }
                    Button(role: .destructive) {
                        confirmingReset = true
                    } label: {
                        Label("Reset", systemImage: "trash")
                            .foregroundStyle(.red)
                    }
#else
                    Button {
                        ImportExportCoordinator.shared.showImporter = true
                    } label: {
                        Label("Import", systemImage: "square.and.arrow.down")
                            .foregroundStyle(Color.appAccent)
                    }
                    Button {
                        if let store { ImportExportCoordinator.shared.prepareExport(using: store) }
                    } label: {
                        Label("Export", systemImage: "square.and.arrow.up")
                            .foregroundStyle(Color.appAccent)
                    }
#endif
                }
                .listRowSeparatorTint(Self.separator)
                .moveDisabled(true)
                .deleteDisabled(true)

#if DEBUG
                SchemaPrimerSection(store: store)
                    .listRowSeparatorTint(Self.separator)
                    .moveDisabled(true)
                    .deleteDisabled(true)
#endif

                Section {
                    Button {
                        pushed = .services
                    } label: {
                        HStack {
                            Label("Streaming Services", systemImage: "tv")
                                .foregroundStyle(Color.appAccent)
                            Spacer()
                            Image(systemName: "chevron.forward")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                .listRowSeparatorTint(Self.separator)
                .moveDisabled(true)
                .deleteDisabled(true)

                // A Button (not NavigationLink) because this List is permanently in
                // edit mode, where links don't fire; it drives a programmatic push.
                Section {
                    Button {
                        pushed = .cache
                    } label: {
                        HStack {
                            Label("Manage Cache", systemImage: "internaldrive")
                                .foregroundStyle(Color.appAccent)
                            Spacer()
                            Image(systemName: "chevron.forward")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                    }
                } footer: {
                    Text(appInfo)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 8)
                }
                .listRowSeparatorTint(Self.separator)
                .moveDisabled(true)
                .deleteDisabled(true)
            }
            .listStyle(.insetGrouped)
            .navigationDestination(item: $pushed) { destination in
                switch destination {
                case .cache: CacheManagerView()
                case .services: StreamingServicesView()
                }
            }
            // The whole point of this screen is reordering/deleting, so it stays in
            // edit mode permanently rather than gating that behind an Edit button.
            .environment(\.editMode, .constant(.active))
            .navigationTitle("Lists")
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
                    // Custom lists sit after the Watch List (order 0), new ones at the bottom.
                    ListEditorView(existing: nil, nextSortOrder: nextCustomSortOrder)
                }
            }
            .modifier(BackupTransferModifier(
                onImport: { result in
                    if let store { ImportExportCoordinator.shared.handleImport(result, using: store) }
                }
            ))
#if targetEnvironment(simulator)
            .confirmationDialog("Reset to factory state?", isPresented: $confirmingReset,
                                titleVisibility: .visible) {
                Button("Reset", role: .destructive) {
                    if let store { SimulatorTools.reset(using: store) }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Deletes all lists, movies, and watch history, then restores the default Watch List.")
            }
#endif
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
                Text(countText(count(for: .list(list.uuid))))
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
        "\(count) \(count == 1 ? "title" : "titles")"
    }

    private var appInfo: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String
        let build = info?["CFBundleVersion"] as? String
        switch (version, build) {
        case let (version?, build?): return "\(version) (\(build))"
        case let (version?, nil): return version
        case let (nil, build?): return build
        default: return ""
        }
    }

    // MARK: - Actions

    private func delete(at offsets: IndexSet) {
        offsets.map { customLists[$0] }.forEach { store?.delete($0) }
    }

    /// Sort orders start at 1; the Watch List holds 0.
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
        .environment(PersistenceCoordinator(previewModelContainer.mainContext))
        .preferredColorScheme(.dark)
}
