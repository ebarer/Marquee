
Important:
- [ ] Marking as watched should save watched date if you toggle it

Polish:
- [ ] Watched: date watched should show up for seasons "Finished on x/y/z"
- [ ] People: expand filter menu on people to include more options (present a checklist menu):
  - [ ] self/…
  - [ ] producer roles
- [ ] People: always make sure to prioritze director/acting role over others in the list
- [ ] Discover Grid: Incorrect gap between TV show name and number of seasons
- [ ] Episode details: include cast (first position), and use standard picker
- [ ] "older" category shouldn't be collapsed when presented in grid, since it's a single shelf it takes up no extra room
- [ ] presenting watch list should start scrolled to the (current month - 1)
- [ ] sorting by rating, etc. the header is too low, should be closer to nav bar
- [ ] tapping selected list in sidebar should scroll to top
- [ ] Drop the `.movie` default from mediaType arguments, so a show can't pass as a movie
  - [ ] `MediaItem.init(tmdbID:mediaType:)`, `MediaItem.find(tmdbID:mediaType:)`
  - [ ] `MediaList.entry(for:_:)`, MediaList.contains(_:_:)

Ideas:`
- [ ] Clean up person page
  - [ ] Center avatar, name below
  - [ ] Collapsing header with small avatar and name
  - [ ] Filter button moves into nav bar on scroll
- [ ] Filter watch list by what's streamable
  - [ ] Add support for toggling between what you subscribe to, and whether it's streamable at all
- [ ] Share lists
- [ ] Support landscape?
- [ ] Add support for awards?
- [ ] Settings page
  - [ ] Version
  - [ ] Cache management
  - [ ] Region selection
  - [ ] Streaming service selection
  - [ ] Import/Export

Archive:
- [ ] All glass buttons should morph into their confirmations/menus (SwiftUI bug)
- [ ] Swipe-to-delete confirmations should anchor on the cell (SwiftUI bug)
