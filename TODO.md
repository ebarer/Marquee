
Important:
- [ ] Inline search polish:
  - [ ] Cancel button on people page doesn't work
  - [ ] People page has nav bar background, movies don't
  - [ ] move search button into nav bar on scroll, beside filter button for person
  - [ ] filter button should become glass
- [ ] Swipe on tv season should mark that episode as watched, secondary action to mark entire season
- [x] Person: tv show cells in credits don't show watched/in progress badge
- [x] Person: tv show cell doesn't support orb or swipe, nor does known for

Polish:
- [ ] tv season header should be sticky until scrolling to next header
- [ ] presenting watch list should start scrolled to the (current month - 1)
- [ ] iPad: when sorting by rating, etc. the header is too low, should be closer to nav bar
- [ ] iPad: tapping selected list in sidebar should scroll to top
- [ ] Marking as watched should save watched date if you toggle it
- [ ] Drop the `.movie` default from mediaType arguments, so a show can't pass as a movie
  - [ ] `MediaItem.init(tmdbID:mediaType:)`, `MediaItem.find(tmdbID:mediaType:)`
  - [ ] `MediaList.entry(for:_:)`, MediaList.contains(_:_:)
- [ ] Use percent instead of out of 5

Ideas:`
- [ ] Rotten tomatoes and IMDB links/integration?
- [ ] List of trailers on long press?
- [ ] Clean up person page
  - [ ] Center avatar, name below
  - [ ] Collapsing header with small avatar and name
- [ ] Filter watch list by what's streamable
  - [ ] Add support for toggling between what you subscribe to, and whether it's streamable at all
- [ ] Share lists
- [ ] Add support for awards?
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
