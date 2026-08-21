# Search

One query, three kinds of answer: movies, shows, and people. The pipeline is declarative —
behaviour is added by writing a tool, not by threading a special case through the model.

## Shape

```
SearchModel  ──▶  SearchPolicy.run(query:using:)  ──▶  SearchResults
 (view state)        │                                  movies / shows
                     ├─ SearchProvider: /search/movie, /tv, /person   (network seam)
                     ├─ tools, in order, each augmenting SearchContext
                     └─ SearchMatching.interlaced(…) → the ranked list
```

- `SearchProvider` is the only thing that talks to TMDB, so tests use a stub.
- `SearchContext` is the working set threaded through the tools.
- `SearchMatching` holds the pure decisions (normalising, title/character/name matching, ranking).
- `SearchPolicy.standard` declares the tool order; order matters:

| Order | Tool | Does |
| --- |---|---|
|  1| `SpellingVariantTool` | Re-queries alternate spellings ("ironman", "wall e") and merges matches |
|  2| `RankMoviesTool` | Orders candidates: notable films by popularity, low-vote noise sunk |
|  3| `HydrateTopMoviesTool` | Fetches detail for the top movies **once**, shared downstream |
|  4| `FranchiseCollectionTool` | Pulls in collection siblings of a matched title |
|  5| `ShowFilterTool` | Trims TV noise |
|  6| `CastPeopleTool` | Extracts the people the strip can show |

## Two signals, used deliberately

TMDB gives two measures and they disagree often enough to matter:

- **votes** — enduring notability. Use this to decide what's *real*.
- **popularity** — what's trending this week. Volatile; a 152-vote 1960s series can out-popularity
  a film with 39,000 votes. Never rank one title against another on popularity alone.

Popularity is only comparable against a benchmark, because TMDB rescales the number periodically.
`PopularityBenchmark` takes the **median of `/movie/popular` page 1** — roughly the tenth most
popular title anywhere — and caches it for six hours. That is the bar "a phenomenon" means, and
deriving it survives a rescaling that a hardcoded threshold would not. Offline it is unavailable,
and ranking falls back to vote count alone.

`notability` is therefore `voteCount × (1 + popularity / benchmark)`: accumulated attention,
scaled by how much of a phenomenon the title is *today*, so a back catalogue's years of votes
can't bury a current hit.

## Ranking the list

`SearchMatching.interlaced` scores every movie and show as `notability × matchWeight(relevance)`.

**Relevance is a step scale, lower is stronger:** 0 exact title, 1 title prefix, 2 word prefix,
3 contains, 4 no match. Both sides are article-stripped, so "The Office" and "office" agree.

**Each step below a title prefix costs a factor of 8** (`relevanceDiscount`). Exact and title-prefix
carry equal weight — `matchWeight` is `8 ^ -max(0, relevance - 1)` — so the scale only starts
charging at a word-prefix match. It is deliberately a discount and not a sort key: relevance decides
between peers, but can't bury a phenomenon. "House of the Dragon" is only a word match for `dragon`,
and still beats an obscure film whose title the query prefixes outright.

**A franchise sibling is never on a stronger footing than the seed that pulled it in.** Its
relevance is `min(seed's relevance, its own literal match)`.

**A title in release now can top its tier outright.** Within `inReleaseDays` (90, roughly a
theatrical run) the most-popular title of a tier is lifted above that tier's ceiling — it is too
new to have the votes, but it is what the query means today. Two guards keep this from running
away: it must clear the popularity benchmark *and* a vote floor, so a fresh sequel can't displace
its own classic.

## Policies

**The results list is the source of truth for order.** The People strip doesn't rank titles
again — it follows the ranked results, so the two can't disagree. Whichever of film or show
leads the list contributes its cast first.

**People are surfaced in stages, and each stage only adds.** Nothing excludes what came before:

1. Whoever played the searched **character**, ordered by their film's votes.
2. The leads of the film the **results list** leads with. Not the same as `context.movies.first`:
   interlacing re-ranks movies with shows and franchise siblings, so for "batman" the list opens
   on The Dark Knight (a collection sibling) while the tool stage's first film is The Batman.
3. The billing of the other films the query names.
4. The top show's recurring cast.

**A title must earn the right to speak for a query.** It has to be named by the query (exact, or
a qualifying prefix) *and* be notable — a vote floor for shows, a popularity floor for films.
Otherwise an obscure same-word title fills the strip with nobody.

**A name query opens on the people who bear it**, above any title's cast. Two guards:
the namesake must clear a popularity floor (else "Line Friends" outranks Jennifer Aniston), and
a title that *is* the query keeps it against a lone namesake — but not against a name several
notable people share.

**Cast is billing order among regulars** (see `AggregateCreditsRaw.regularCast`), not episode
count, or a departed lead lands behind the ensemble who stayed. A regular is someone in half
the longest run, which keeps a guest billed high in a handful of episodes out.

**A name matches whole segments, or a run of them.** `office` must not claim someone called
"Officer", and a partly-typed name waits until it is a name — `cameron dia` matches nobody.
A run is required because normalising drops the separator the query has and the name keeps:
`cameron diaz` becomes `camerondiaz`, which equals no single segment of "Cameron Diaz", so
segment-at-a-time matching left an exact full-name search ranked behind the cast of her own
films. Below three characters, nothing matches by name.

**The strip's inline prefix ends at the first person who isn't prominent.** A cast match always
counts as prominent; a name match counts only if it clears `inlinePopularityFloor` *and* has a
photo. The rest fold under "More". With nothing prominent at all the strip still shows
`minInlinePeople` (3) rather than a bare "More" button — a pure obscure-name search should show
its best few. A photoless entry that clears the floor on popularity alone ("AI-D\*300") folds.

**Franchise expansion is a general rule, never a hardcoded franchise list.** Take the notable
titles that *do* match the query, look up the TMDB collection each belongs to, and merge in its
siblings at the seed's relevance. `batman` reaches The Dark Knight through "Batman Begins";
`superman` reaches "Man of Steel" through "Batman v Superman", which the query only word-matches.

**TV noise is trimmed by origin, not by relevance alone.** `ShowFilterTool` keeps US-aired shows
that are established (votes) or trending (popularity) — plus *any* exact title match, so a
directly-searched foreign show ("Squid Game") still appears.

**An initialism is expanded from a table, which is the one hardcoded thing here.** TMDB records
"SNL" on the show as an alternative title of type `initialism`, but its search endpoint never
consults alternative titles, so `snl` reaches only SNL Korea and SNL China — the original is
unreachable by any query, and there is nothing to derive the expansion from. `SpellingVariantTool`
re-queries the expansion against TV as well as film, and records it as a *title alias*: relevance
takes the best score across the query and its aliases, so the show outranks a title that merely
carries the letters. Keep the table to initialisms people actually type.

The same table serves the in-app search boxes — a person's credits, a title's cast — because
`String.matches(query:)` falls back to the expansion when the literal substring misses. That is
one matcher behind every filter field, so the rule does not need repeating per screen.

**Spelling variants exist because TMDB's title search is literal.** A compressed hero name
("ironman") or a separator title ("wall e") finds only obscure films, and an interpunct title
matches only its own spelling. `SpellingVariantTool` re-queries the alternates and merges them in;
whatever noise they add sinks under `RankMoviesTool`.

**Recall recovery covers TMDB dropping the real match mid-type.** Incremental search is erratic:
typing one more character can lose the film that was leading a keystroke ago. The model keeps the
last query whose own results were strong as an *anchor*, and when the current query returns nothing
strong but still extends or prefixes that anchor, it re-runs the anchor and takes those results
instead. The anchor only advances on a query that was strong in its own right, so recovery never
re-runs a recovered result.

## Examples

What the **People strip** opens on:

| Query | Leads with | Why |
|---|---|---|
| `batman` | Bale, Pattinson, Affleck, Keaton | Character match, ordered by film votes |
| `avengers` | Downey Jr., Evans, Hemsworth… | Nobody's character; the named films' billing fills it |
| `office` | Carell, Wilson, Krasinski | Show wins the list, so its cast leads the film's |
| `robert` | Downey Jr., Pattinson, Patrick | Name query; no notable title called "Robert" |
| `cameron diaz` | Cameron Diaz | Full name matches as a run, ahead of her own films' cast |
| `dune` | Chalamet, Zendaya | Title holds the query against one obscure namesake |
| `carrie` | Carrie-Anne Moss, Coon, Fisher | Several notable namesakes take it back off the film |
| `friends` | Aniston, Cox, Kudrow | Namesake noise ("Line Friends") is below the floor |

What the **results list** opens on:

| Query | Leads with | Why |
|---|---|---|
| `dragon` | House of the Dragon | The phenomenon outweighs an 8× relevance discount |
| `batman` | The Dark Knight | Collection sibling, inheriting "Batman Begins"'s relevance |
| `superman` | Man of Steel | Sibling of a title the query only word-matches |
| `squid game` | Squid Game | Exact title match escapes the US-origin TV filter |
| `ironman` | Iron Man | Spaced variant; the literal query finds only obscure films |
| `snl` | Saturday Night Live | Initialism expansion, aliased so SNL Korea can't lead |

## Changing any of this

Every policy above is pinned by a test in `MarqueeTests/Source/Search/`. Write the expected
order as a test **before** changing a rule: these rules interact, and fixing one query by hand
has repeatedly broken another. Live TMDB is for confirming what the tests already assert.
