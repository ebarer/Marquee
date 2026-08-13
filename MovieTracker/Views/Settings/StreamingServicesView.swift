//
//  StreamingServicesView.swift
//  MovieTracker
//

import SwiftUI

struct StreamingServicesView: View {
    private let store = StreamingServicesStore.shared

    @State private var groups: [ProviderGroup] = []
    @State private var loadedRegion: String?
    @State private var loadFailed = false
    @State private var query = ""
    @State private var showingRegion = false
    // Snapshotted when the picker opens so toggling doesn't reshuffle rows between sections mid-interaction.
    @State private var initialSelection: Set<Int> = []

    private var filtered: [ProviderGroup] {
        guard !query.isEmpty else { return groups }
        return groups.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    private func wasSubscribed(_ group: ProviderGroup) -> Bool {
        !initialSelection.isDisjoint(with: group.memberIDs)
    }

    private var subscribed: [ProviderGroup] { filtered.filter(wasSubscribed) }
    private var others: [ProviderGroup] { filtered.filter { !wasSubscribed($0) } }

    var body: some View {
        List {
            if groups.isEmpty {
                statusRow
            } else {
                if !subscribed.isEmpty {
                    Section("My Services") {
                        ForEach(subscribed) { row(for: $0) }
                    }
                }
                Section {
                    ForEach(others) { row(for: $0) }
                } header: {
                    Text(subscribed.isEmpty ? "All Services" : "More Services")
                } footer: {
                    Text("Only services you turn on appear under “Where to Watch”. "
                       + "Leave everything off to see every service.")
                }
            }
        }
        .navigationTitle("Streaming Services")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { showingRegion = true } label: {
                    Text(Region.flag(store.region)).font(.title3)
                }
                .accessibilityLabel("Region: \(Region.name(store.region))")
            }
        }
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always),
                    prompt: "Find a service")
        .sheet(isPresented: $showingRegion) {
            NavigationStack { RegionPickerView() }
                .preferredColorScheme(.dark)
        }
        .task { initialSelection = store.selected.ids }
        .task(id: store.region) { await load() }
    }

    private func row(for group: ProviderGroup) -> some View {
        Toggle(isOn: binding(for: group)) {
            HStack(spacing: 12) {
                RemoteImage(url: group.logoURL(size: "w92")) {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Color.appSeparator)
                }
                .frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

                Text(group.name)
            }
        }
        .tint(.green)
    }

    private func binding(for group: ProviderGroup) -> Binding<Bool> {
        Binding(get: { store.isSelected(group) }, set: { _ in store.toggle(group) })
    }

    @ViewBuilder
    private var statusRow: some View {
        if loadFailed {
            ContentUnavailableView("Couldn’t Load Services",
                                   systemImage: "wifi.slash",
                                   description: Text("Check your connection and try again."))
        } else {
            HStack {
                Spacer()
                ProgressView()
                Spacer()
            }
            .listRowBackground(Color.clear)
        }
    }

    private func load() async {
        guard loadedRegion != store.region else { return }
        groups = []
        loadFailed = false
        do {
            groups = ProviderCatalog.grouped(try await TMDBWrapper.watchProviders(region: store.region))
            loadedRegion = store.region
        } catch {
            loadFailed = true
        }
    }
}

#Preview {
    NavigationStack {
        StreamingServicesView()
    }
    .preferredColorScheme(.dark)
}
