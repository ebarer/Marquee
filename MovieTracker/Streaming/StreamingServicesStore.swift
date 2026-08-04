//
//  StreamingServicesStore.swift
//  MovieTracker
//

import Foundation

/// The user's service selection and region, synced across devices via iCloud.
@MainActor
@Observable
final class StreamingServicesStore {
    static let shared = StreamingServicesStore()

    private(set) var selected: SelectedProviders
    /// nil follows the device region; a code overrides it.
    private(set) var regionOverride: String?

    var region: String { regionOverride ?? Region.device }

    private let store = NSUbiquitousKeyValueStore.default
    private let key = SelectedProviders.storageKey
    private let regionKey = "streamingRegion"

    private init() {
        selected = Self.load(store, key)
        regionOverride = store.string(forKey: regionKey)
        NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: store, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.reload() }
        }
        store.synchronize()
    }

    func isSelected(_ group: ProviderGroup) -> Bool { selected.isSelected(group) }

    func toggle(_ group: ProviderGroup) {
        var updated = selected
        updated.toggle(group)
        selected = updated
        store.set(updated.rawValue, forKey: key)
        store.synchronize()
    }

    func setRegion(_ code: String?) {
        regionOverride = code
        if let code {
            store.set(code, forKey: regionKey)
        } else {
            store.removeObject(forKey: regionKey)
        }
        store.synchronize()
    }

    private func reload() {
        selected = Self.load(store, key)
        regionOverride = store.string(forKey: regionKey)
    }

    private static func load(_ store: NSUbiquitousKeyValueStore, _ key: String) -> SelectedProviders {
        SelectedProviders(rawValue: store.string(forKey: key) ?? "") ?? SelectedProviders()
    }
}
