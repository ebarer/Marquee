
Next:
- [ ] 

Polish:
- [ ] Search history should store the tapped results, going directly to the movie/show/actor
- [ ] Improve layout of awards page

Ideas:`
- [ ] Share lists
- [ ] List of trailers on long press
- [ ] Support landscape
- [ ] Settings page
  - [ ] Version
  - [ ] Cache management
  - [ ] Region selection
  - [ ] Streaming service selection
  - [ ] Import/Export

Archive:
- [ ] All glass buttons should morph into their confirmations/menus (SwiftUI bug)
- [ ] Swipe-to-delete confirmations should anchor on the cell (SwiftUI bug)
  - [ ] move search button into nav bar on scroll, beside filter button for person
- [ ] Drop the `.movie` default from mediaType arguments, so a show can't pass as a movie
  - [ ] `MediaItem.init(tmdbID:mediaType:)`, `MediaItem.find(tmdbID:mediaType:)`
  - [ ] `MediaList.entry(for:_:)`, MediaList.contains(_:_:)
