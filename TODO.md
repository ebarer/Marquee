
Next:
- [ ] Search bug:
  - [ ] keyboard dismisses after transition (lingers), should dismiss as oon as I hit cancel
  - [ ] Keyboard failed to dismiss entirely one time
  - [ ] Clear button in search field doesn't work

Polish:
- [ ] Drop the `.movie` default from mediaType arguments, so a show can't pass as a movie
  - [ ] `MediaItem.init(tmdbID:mediaType:)`, `MediaItem.find(tmdbID:mediaType:)`
  - [ ] `MediaList.entry(for:_:)`, MediaList.contains(_:_:)

Ideas:`
- [ ] Clean up person page
  - [ ] Center avatar, name below
  - [ ] Collapsing header with small avatar and name
- [ ] Filter watch list by what's streamable
  - [ ] Add support for toggling between what you subscribe to, and whether it's streamable at all
- [ ] Add support for awards?
- [ ] Share lists
- [ ] Rotten tomatoes and IMDB links/integration?
  - [ ] Use percent instead of out of 5
- [ ] List of trailers on long press?
- [ ] Support landscape?
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
