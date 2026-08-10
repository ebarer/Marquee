# README

Important:
- [ ] Checkmark on episode details should animate in the date watched label
- [ ] Deleting a tv show from the "to watch" list causes it to reappear, needs to mark the override (with warning)
- [ ] We've lost the swipe to mark as watched action?
  - [ ] Except in custom lists, even for shows thst are already watched

Project:
- [ ] Clean up comments + organize project
- [ ] Get rid of single-letter variables/arguments, always use proper names

Polish:
- [ ] Search: Brand New Day isn't #1 for Spiderman
- [ ] Search: Noah Wyle is known for ER and The Pitt, neither show up in that section (movies only?)
- [ ] Search: Seth Rogen is known for The Studio, Superbad and Knocked Up, (the 1st doesn't show up at all, the other 2 aren't rated highly enough?
- [ ] Search: searching for Seth Rogen should return his discography
- [ ] Search: presenting TV show is unanimated, and missing status badges on poster
- [ ] Episode row: background should highlight when clicked, not the text
- [ ] Episode row: tapping image should mark as watched/unwatched
- [ ] Tint tab bar to match view color
- [ ] Movies/TV show filter should have checkmark in gutter, not replacing the icon, and label for the first option should be "Both"
- [ ] Alphabetical sort for lists
- [ ] List popover should present downwards when at top of the screen (always presents up)

Ideas:
- [ ] Filter watch list by what's streamable
  - [ ] Add support for togglign between what you subscribe to, and whether it's streamable at all
- [ ] Share lists
- [ ] Support landscape?

Description:
- Discover – curated list of popular, now playing, and upcoming movies
- Watch Lists – keep track of the movies you want to watch, have watched, or sort into custom lists across all your devices
- Search – find movies and people, with cast/crew lookup
- Details – watch a trailer, see the cast and crew and see what else they've been in
- Where to Watch – region-aware streaming provider links

---
Next:
1. we've once again violated my 3 most important policies:
  1. files shouldn't exceed 100 lines unless absolutely necessary
  2. all view files should have a preview, and every view should have its own file to make it easy to debug. the preview should simulate all possible states/conditions.
  3. comments shouldn't exceed 2 lines, and should only be used when the code is non-obvious
