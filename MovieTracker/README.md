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

Three layers, one direction of dependency: **Views → Persistence → Source**.

| Layer | Role | Rule |
|---|---|---|
| `Source/` | Domain types, TMDB networking, search engine, streaming catalog | No SwiftUI, no SwiftData |
| `Persistence/` | SwiftData models, the store, caching, import/export | Knows `Source`, not `Views` |
| `Views/` | SwiftUI screens plus their view-models | Never touches `ModelContext` directly |

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

### Key seams

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
- **`MediaCacheStore`** is a bounded (300-entry) on-disk JSON cache, keyed by TMDB id, so
  detail screens render offline. `MediaCachePrefetcher` warms it for saved titles at launch.
- **CloudKit** sync is automatic (`ModelConfiguration(cloudKitDatabase: .automatic)`).
  Because CloudKit requires optional/defaulted properties, imports can produce duplicates;
  `PersistenceCoordinator.deduplicate()` converges them at launch. `CloudSyncMonitor` exposes
  sync activity to the UI, and `SyncLog` traces it.

### App shell

`AppDelegate` (`@main`, UIKit lifecycle) configures `URLCache` and gates landscape to fullscreen
trailer playback. `RootView` builds the shared `ModelContainer`, injects the coordinator and sync
monitor, and picks a shell by size class:

- **Compact (iPhone)** – `CompactRootView`: a `TabView` of Discover / Lists / Search, each with
  its own `NavigationStack`.
- **Regular (iPad)** – `SidebarRootView`: `NavigationSplitView`; detail screens open as sized
  sheets via the `openDetail` environment action, with `closeModal` injected for the Close button.

Both shells attach `.detailDestinations()`, so any screen can push a `Movie`, `Show`, `Episode`,
or `Person` without knowing which shell it's in. Each page publishes its accent colour with
`.pageTint(_:)` (a `PreferenceKey`), which the shell applies — that's how the UI takes on the
current poster's colour.

---

## Directory hierarchy

```
MovieTracker/
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
├── Views/
│   ├── App/                    # AppDelegate, SceneDelegate
│   ├── Structure/              # RootView, the two shells, sidebar, detail routing, PageTint
│   ├── Featured/               # Discover
│   ├── Lists/                  # Lists screen, sections, sorting, row actions
│   ├── Search/                 # Search screen, people strip
│   ├── Details/                # Movie/ Show/ Person/ Episode/ + Common/ building blocks
│   ├── Shared/                 # Images, Cards, Rows, Lists, Controls, Text
│   ├── Settings/               # List manager (settings hub), streaming, region, cache, backup
│   ├── Extensions/             # Color, String, DateFormatter, detailDestinations
│   └── Preview/                # In-memory container + sample data for previews
└── Resources/                  # Assets, Info.plist, entitlements, sample JSON/images
```

### View-model placement

Pure logic lives in `Source/`. A view-model that exists to drive one screen lives *next to that
screen* (`Views/Details/Movie/MovieDetailModel.swift`, `Views/Featured/FeaturedModel.swift`,
`Views/Lists/ListSectionsModel.swift`). They're `@MainActor @Observable` classes with
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

## Project policies

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
