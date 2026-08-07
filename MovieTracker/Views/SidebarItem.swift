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
