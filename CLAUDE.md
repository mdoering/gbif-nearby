# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Native iOS app (SwiftUI, iOS 17+, Swift 5.10) that surfaces GBIF biodiversity data around the user's location. No third-party dependencies. Data comes from the public GBIF v1/v2 APIs.

## Build & test

The Xcode project is **not** committed — `GBIFNearby.xcodeproj/` is generated from `project.yml` by [XcodeGen](https://github.com/yonaskolb/XcodeGen). The `Makefile` is the canonical entry point:

```sh
make project   # regenerate GBIFNearby.xcodeproj from project.yml
make build     # xcodebuild -scheme GBIFNearby -destination 'platform=iOS Simulator,name=iPhone 15' build
make test      # same, with `test`
make clean     # rm -rf GBIFNearby.xcodeproj build
```

After editing `project.yml` (sources, resources, build settings), run `make project` before building in Xcode. CI mirrors this — `ci_scripts/ci_post_clone.sh` installs xcodegen and runs `xcodegen generate` before xcodebuild.

Override the simulator with `DEST=...`, e.g. `make test DEST='platform=iOS Simulator,name=iPhone 16 Pro'`.

### Running a single test

Tests use the **Swift Testing** framework (`import Testing`, `@Suite`, `@Test`, `#expect`) — not XCTest. To run a single suite or test through xcodebuild:

```sh
xcodebuild -scheme GBIFNearby \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -derivedDataPath build \
  -only-testing:GBIFNearbyTests/GBIFClient \
  test
```

The `-only-testing` argument uses the `@Suite("Name")` value, e.g. `GBIFNearbyTests/GBIFClient/search` to target one `@Test` method.

### Release signing

`Release` config is pinned to **Manual** signing with the `Apple Distribution` cert and the `GBIF Nearby App Store` provisioning profile (see comment in `project.yml`). Xcode 26's Automatic signing no longer performs the dev → distribution swap on archive, which broke App Store validation (ITMS-90035). `Debug` stays Automatic. Don't switch Release back to Automatic without re-validating an archive upload.

## Architecture

### App composition

`GBIFNearbyApp` (`GBIFNearby/App/`) constructs an `AppEnvironment` with six `@MainActor @Observable` stores and a `GBIFClient` actor, then injects them into the SwiftUI environment so any view can pull them with `@Environment(...)`. The five tabs in `RootTabView` (Map, Species, Gallery, Datasets, About) all read from these same stores, which is what makes the radius slider, kingdom chip, and taxon filter shared header state work across tabs.

Stores in `Core/`:

| Store | Role | Persisted? |
|---|---|---|
| `LocationStore` | CoreLocation wrapper; `current` coord + auth status; supports a manual long-press pin. Filters degraded/jittery GPS fixes to avoid per-second refetch storms. | no |
| `RadiusStore` | Search radius in km (0.1–100, default 2.5). | `UserDefaults` |
| `TaxonFilterStore` | Kingdom chip (Animals/Plants/Fungi) **or** a free-text `TaxonSuggestion` override from `/species/suggest`. `effectiveTaxonKey` is what features send to the API. | kingdom yes, override no |
| `FocusFilterStore` | "Focus on dataset X" / "focus on species Y" — toggles cross-tab drill-down. | no |
| `SettingsStore` | Distance unit + preferred vernacular language. | `UserDefaults` |
| `TabSelectionStore` | Drives `TabView` selection so other tabs can navigate. | no |

The GBIF client itself is injected via a separate `EnvironmentValues.gbifClient` key (not `@Environment(...)`) — see `GBIFNearbyApp.swift`.

### Networking

`GBIFClienting` is the protocol every feature depends on. `GBIFClient` is the production actor; `FakeGBIFClient` (in `GBIFNearbyTests/Core/Networking/`) is the in-memory test double that records every call and lets each test wire up handlers per endpoint. Add a new endpoint by extending both — never let view models talk to `URLSession` directly.

`OccurrenceQuery` is the single struct that builds the `geo_distance` + filter query string used by Map, Species, Gallery, and Datasets. Kingdoms are passed as plain `taxonKey` values (Animalia=1, Plantae=6, Fungi=5) — there's no separate `kingdomKey` field, since kingdom keys are themselves valid taxon keys on the GBIF backbone.

`GBIFDensityTileOverlay` (Map feature) hits `api.gbif.org/v2/map/occurrence/density/...` directly via `MKTileOverlay` — it doesn't go through `GBIFClient`. Tile filter params must stay in sync with whatever filters the rest of the app applies.

Image thumbnails come through GBIF's image cache CDN with an MD5-keyed path: `ImageCacheURL.build(occurrenceKey:identifier:size:)` is the only correct way to build a thumbnail URL.

### Feature pattern

Each tab in `Features/<Name>/` follows the same layout:

- `<Name>TabView.swift` — top-level view; owns the `@State` view model, observes the shared stores, debounces refetches.
- `<Name>ViewModel.swift` — `@MainActor @Observable` class with a `Loading<T>` state property (`idle / loading / loaded / failed`) and an `async refresh(...)` entry point.
- `<Name>RowItem.swift` — mutable row struct that view models enrich incrementally (e.g. species details, vernacular name, thumbnail) so the list paints fast and fills in.

Fetches in `MapTabView` / `SpeciesTabView` / etc. are gated through `AsyncDebouncer` (`Core/Util/Debounce.swift`) so that simultaneous changes to radius + taxon + location collapse into a single API call.

### Vernacular name handling

GBIF's `/species/{key}/vernacularNames` returns 3-letter ISO 639-2/T codes (`eng`, `deu`); the rest of the app — settings UI, device locale, language picker — uses 2-letter ISO 639-1 (`en`, `de`). `VernacularResolver` is the single place that bridges the two; always go through it rather than comparing language strings directly.

## Tests

Targets in `GBIFNearbyTests/`:

- `Core/Networking/` — `GBIFClient` is tested against `MockURLProtocol`; everything else uses `FakeGBIFClient`.
- `Core/Stores/`, `Core/Util/`, `Core/Models/` — pure-Swift unit tests.
- `Features/<Name>/` — view model tests, driven by `FakeGBIFClient`.
- `Fixtures/` — JSON fixtures (`occurrence-search.json`, `occurrence-facet-species.json`) are listed individually under `targets.GBIFNearbyTests.sources` in `project.yml` and bundled as test resources. Add new fixtures the same way.

The smoke test in `GBIFNearbyTests/SmokeTest.swift` verifies the test bundle links — keep it passing.

## Repo conventions

- `gbif/` is `.gitignore`d — it holds the App Store icon source files, screenshots, and GBIF brand assets. Don't add app code there.
- `docs/` is published as a Jekyll site (GitHub Pages, Midnight theme). Privacy policy and App Store copy live there.
- `build/` is the xcodebuild `derivedDataPath` — `make app-path` will print the built `.app` location after a build.
