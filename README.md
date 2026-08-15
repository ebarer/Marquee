# Marquee

A SwiftUI app for discovering and tracking movies and TV shows, backed by TMDB for
metadata and SwiftData + CloudKit for the user's own library.

The Xcode project is still named `MovieTracker`; the app target is **Marquee**
(`MarqueeTests` / `MarqueeUITests`).

## Features

- **Discover** – curated collections of popular, now playing, and upcoming movies and shows
- **Watch Lists** – track what you want to watch, have watched, or sorted into custom lists,
  synced across all your devices
- **Search** – unified movies/TV/people search; people surface by name *and* by the roles
  they played
- **Details** – trailers, cast and crew, episode-level TV progress, and what else a person
  has been in
- **Where to Watch** – region-aware streaming availability, filtered to your services

---

## Architecture

Three layers, listed as the project lists them. Dependency runs one way, in the other order:
**Views → Persistence → Source**.

| Layer | Role | Rule |
|---|---|---|
| `Views/` | SwiftUI screens plus their view-models | Never touches `ModelContext` directly |
| `Source/` | Domain types, TMDB networking, search engine, streaming catalog | No SwiftUI, no SwiftData |
| `Persistence/` | SwiftData models, the store, caching, import/export | Knows `Source`, not `Views` |

### Data flow

```
TMDB ──► TMDBResponses (raw DTOs) ──► Representations (Movie/Show/Person/…)
                                            │
                        ┌───────────────────┼────────────────────┐
                        ▼                   ▼                    ▼
                 MediaCacheStore     view-models          MediaItem / ListEntry
                 (offline JSON)      (@Observable)        (SwiftData + CloudKit)
                        └───────────────────┴────────────────────┘
                                            ▼
                                     SwiftUI views
```

Remote types (`Movie`, `Show`, `Episode`, `Person`) are `Codable`, `Hashable` value types —
they double as navigation values (`navigationDestination(for: Movie.self)`) and as cache
payloads. Persisted types (`MediaItem`, `ListEntry`, …) hold only *the user's* state; TMDB
metadata is re-fetched or read from the cache, never treated as the source of truth.

### Keys

- **`PersistenceCoordinator`** (`Persistence/Store/`) is the single access point for reads and
  writes. It owns the main-actor `ModelContext`, saves eagerly, bumps a `revision` counter that
  views observe, and is split by domain (`+Media`, `+TV`, `+Lists`, `+Lifecycle`). Views get it
  from the environment.
- **`ListCoordinator`** is a `@ModelActor` that reads list contents off the main actor;
  `SectionFormatter` turns the result into titled month/year sections.
- **`SearchPolicy`** (`Source/Search/`) declares a search as base fetches plus an ordered list
  of `SearchTool`s (spelling variants, ranking, franchise expansion, cast lookup). New search
  behaviour means adding or reordering a tool — not threading a special case through the model.
  Everything runs against the `SearchProvider` protocol, so tests use canned data.
- **`MediaCacheStore`** is a bounded (400-entry) on-disk JSON cache, keyed by TMDB id, so
  detail screens render offline. Entries carry a `MediaCachePriority`, and eviction drops the
  worst tier first (oldest within a tier) rather than plain LRU. `MediaCachePlan` buckets what
  to keep — Watch List (shows pull their latest 3 seasons), Discovery, this year's watched,
  custom lists, then the rest of Watched — and `MediaCachePrefetcher` works through it at launch.
- **CloudKit** sync is automatic (`ModelConfiguration(cloudKitDatabase: .automatic)`).
  Because CloudKit requires optional/defaulted properties, imports can produce duplicates;
  `PersistenceCoordinator.deduplicate()` converges them at launch. `CloudSyncMonitor` exposes
  sync activity to the UI, and `SyncLog` traces it.

### App

`AppDelegate` (`@main`, UIKit lifecycle) configures `URLCache` and gates landscape to fullscreen
trailer playback. `RootView` builds the shared `ModelContainer`, injects the coordinator and sync
monitor, and picks a shell by size class:

- **Compact (iPhone)** – `CompactRootView`: a `TabView` of Discover / Lists / Search, each with
  its own `NavigationStack`.
- **Regular (iPad)** – `SidebarRootView`: `NavigationSplitView`; detail screens open as sized
  sheets via the `openDetail` environment action, with `closeModal` injected for the Close button.
  `DetailRootView` marks what the sheet opened on with `isModalRoot`, so Close takes the leading
  side there and the trailing side on a pushed screen, where Back owns the leading one.

Both shells attach `.detailDestinations()`, so any screen can push a `Movie`, `Show`, `Episode`,
or `Person` without knowing which shell it's in. Preferences carry state the other way, up to
whichever shell owns the chrome: `.pageTint(_:)` hands up a page's accent colour (that's how the
UI takes on the current poster's colour), and `.listVisibleCount(_:)` hands up how many rows a
list is showing, for the "3 of 30 Titles" navigation subtitle.

The same screens serve both shells, in two presentations: `ListTable` renders a list as `List`
rows on iPhone, `ListGrid` as cards in a grid on iPad, both from one `ListContentView` and the
same `SectionSnapshot`s. Search does likewise — rows on iPhone, `SearchResultsGrid` on iPad.

---

## Directory Hierarchy

```
MovieTracker/
├── App/                        # AppDelegate, SceneDelegate, UITestHooks
├── Views/
│   ├── Structure/              # RootView, the two shells, sidebar, detail routing, PageTint
│   ├── Featured/               # Discover
│   ├── Lists/                  # ListsView + ListContentView, and the visible-count preference
│   │   ├── Sections/           # SectionSnapshot, SectionFormatter, ListSectionsModel, header
│   │   ├── Entries/            # One entry's body, context, actions, links, swipes
│   │   ├── Table/              # ListTable: the iPhone rows
│   │   ├── Grid/               # ListGrid: the iPad cards
│   │   └── Toolbar/            # Title label + switcher, sort/filter menu and its options
│   ├── Search/                 # Search screen, people strip, iPad results grid
│   ├── Details/                # Movie/ Show/ Person/ Episode/ + Common/ building blocks
│   ├── Shared/                 # Images, Cards, Rows, Lists, Controls, Actions, Text
│   ├── Settings/               # List manager (settings hub), streaming, region, cache, backup
│   ├── Extensions/             # Color, String, DateFormatter, detailDestinations, swipe grid
│   └── Preview/                # In-memory container + sample data for previews
├── Source/                     # Domain + services (no UI, no SwiftData)
│   ├── Representations/        # Movie, Show, Season, Episode, Person, MediaRef, MediaKey…
│   ├── Requests/               # TMDBWrapper (+Movie, +TV, +Person)
│   ├── Responses/              # Raw TMDB DTOs → Representations
│   ├── Search/                 # SearchPolicy, SearchProvider, SearchMatching, Tools/
│   └── Streaming/              # WatchProvider, ProviderCatalog, services + region prefs
├── Persistence/
│   ├── Models/                 # @Model: MediaItem, MediaList, ListEntry, Tracked/Watched…
│   ├── Store/                  # PersistenceCoordinator, ListCoordinator, ListRequest/Result
│   ├── Sync/                   # CloudSyncMonitor, SyncLog
│   ├── Cache/                  # MediaCacheStore, prefetcher, season counts
│   └── Transfer/               # JSON library backup, CSV import, import/export coordinator
└── Resources/                  # Assets, Info.plist, entitlements, sample JSON/images
```

`Resources/` is a synchronized group — anything dropped in is built automatically. Everywhere
else the project carries explicit file references, so a new source file has to be added to the
target or the build fails.

### View-Model Placement

Pure logic lives in `Source/`. A view-model that exists to drive one screen lives *next to that
screen* (`Views/Details/Movie/MovieDetailModel.swift`, `Views/Featured/FeaturedModel.swift`,
`Views/Lists/Sections/ListSectionsModel.swift`). They're `@MainActor @Observable` classes with
`private(set)` state and `async` load methods — no Combine.

### Previews

`Views/Preview/` provides `previewModelContainer` (in-memory) and sample `Movie`/`Show` data;
`Resources/Sample Data/` supplies bundled artwork so `RemoteImage` renders offline in the canvas.
Async detail screens take an injected, pre-seeded model so populated states can be previewed
without a network call.

## Testing

- `MarqueeTests` – Swift Testing (`@Test`/`#expect`), mirroring the app's folder layout, with
  `URLProtocolStub` for network fixtures and in-memory containers for SwiftData.
- `MarqueeUITests` – XCUIAutomation smoke and navigation tests.

---

## Project Policies

1. **File size** – files should not exceed 100 lines unless absolutely necessary. Don't split
   just to hit the target, but do move distinct pieces into their own files.
2. **Previews** – every view file has a preview, with one preview per distinct state or
   condition that view can be in.
3. **Comments** – only when the code is non-obvious or a high-level concept needs explaining.
   Never more than 2 lines; if it can't be explained in 2 lines, split the code further.
4. **Frameworks** – prefer `async`/`await` over Combine, and native components (`Menu`,
   `Picker`, `alert`) over hand-rolled equivalents. Adjust the design to fit the control.
5. **Layering** – views read and write through `PersistenceCoordinator`, never `ModelContext`.
   Logic that isn't tied to one screen belongs in `Source/`.
