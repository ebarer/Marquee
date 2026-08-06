//
//  SidebarItem.swift
//  MovieTracker
//

import Foundation

/// A selectable destination in the iPad sidebar: a Discover collection or a list.
enum SidebarItem: Hashable {
    case collection(FeaturedCollection)
    case list(ListSelection)
}

/// Whether the detail search field queries everything or filters the selected list.
enum SearchScope: Hashable {
    case all
    case list
}
