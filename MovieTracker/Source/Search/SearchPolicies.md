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

**Cast is billing order among regulars** (see `AggregateCreditsRaw.rankedCast`), not episode
count, or a departed lead lands behind the ensemble who stayed.

## Examples

| Query | Leads with | Why |
|---|---|---|
| `batman` | Bale, Pattinson, Affleck, Keaton | Character match, ordered by film votes |
| `avengers` | Downey Jr., Evans, Hemsworth… | Nobody's character; the named films' billing fills it |
| `office` | Carell, Wilson, Krasinski | Show wins the list, so its cast leads the film's |
| `robert` | Downey Jr., Pattinson, Patrick | Name query; no notable title called "Robert" |
| `dune` | Chalamet, Zendaya | Title holds the query against one obscure namesake |
| `carrie` | Carrie-Anne Moss, Coon, Fisher | Several notable namesakes take it back off the film |
| `friends` | Aniston, Cox, Kudrow | Namesake noise ("Line Friends") is below the floor |

## Changing any of this

Every policy above is pinned by a test in `MarqueeTests/Source/Search/`. Write the expected
order as a test **before** changing a rule: these rules interact, and fixing one query by hand
has repeatedly broken another. Live TMDB is for confirming what the tests already assert.
