//
//  RegionPickerView.swift
//  MovieTracker
//

import SwiftUI

struct RegionPickerView: View {
    private let store = StreamingServicesStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var regions: [String] {
        guard !query.isEmpty else { return Region.all }
        return Region.all.filter {
            Region.name($0).localizedCaseInsensitiveContains(query)
                || $0.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        List {
            Section {
                Button {
                    store.setRegion(nil)
                    dismiss()
                } label: {
                    row(flag: Region.flag(Region.device),
                        name: "Device Region (\(Region.name(Region.device)))",
                        selected: store.regionOverride == nil)
                }
            }
            Section {
                ForEach(regions, id: \.self) { code in
                    Button {
                        store.setRegion(code)
                        dismiss()
                    } label: {
                        row(flag: Region.flag(code), name: Region.name(code),
                            selected: store.regionOverride == code)
                    }
                }
            }
        }
        .navigationTitle("Region")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, prompt: "Find a country")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(role: .confirm) { dismiss() }
            }
        }
    }

    private func row(flag: String, name: String, selected: Bool) -> some View {
        HStack(spacing: 12) {
            Text(flag).font(.title3)
            Text(name).foregroundStyle(.primary)
            Spacer(minLength: 12)
            if selected {
                Image(systemName: "checkmark")
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.appAccent)
            }
        }
    }
}

#Preview {
    NavigationStack {
        RegionPickerView()
    }
    .preferredColorScheme(.dark)
}
