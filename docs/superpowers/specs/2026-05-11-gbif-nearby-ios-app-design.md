# GBIF Nearby — iOS app design

**Status:** Draft for review
**Date:** 2026-05-11
**Author:** Markus Döring (with Claude)

## Summary

A native iOS app, **GBIF Nearby**, that shows GBIF biodiversity data centered on the user's current location. Five tabs — Map, Species, Gallery, Datasets, About — share a persistent header with a radius slider (0.1–100 km, default 5 km) and a single-select kingdom filter (All / Animals / Plants / Fungi). Built fresh in SwiftUI for iOS 17+, no third-party dependencies.

## Goals

- Native, fast, low-chrome interface for browsing GBIF occurrences around you.
- All filters (location, radius, kingdom) consistent across every data-driven tab.
- Use canonical GBIF endpoints; never scrape, never hit raw external image URLs.

## Non-goals

- iPad-optimized layout, widget, watchOS companion.
- Offline data caching beyond `URLCache`.
- User accounts, saved searches, notifications.
- Localized UI strings (data is multilingual; chrome stays English at MVP).

## Tech stack

- SwiftUI, iOS 17 minimum.
- Swift 5.10, Xcode 16+.
- iPhone only, portrait + landscape.
- Frameworks only: SwiftUI, MapKit, CoreLocation, CryptoKit, SafariServices, Foundation.
- No third-party packages.

## App identity

- Display name: **GBIF Nearby**
- Bundle identifier: `org.gbif.nearby`

## Project layout

```
gbif-ios/
  GBIFNearby.xcodeproj
  GBIFNearby/
    App/                  GBIFNearbyApp.swift, RootTabView.swift
    Core/
      Location/           LocationStore.swift   (@Observable, wraps CLLocationManager)
      Radius/             RadiusStore.swift     (@Observable, km Double, UserDefaults-backed)
      TaxonFilter/        TaxonFilterStore.swift (@Observable, KingdomFilter enum)
      FocusFilter/        FocusFilterStore.swift (@Observable, optional datasetKey/speciesKey)
      Networking/         GBIFClient.swift      (actor, URLSession + async/await)
      Models/             Occurrence, Dataset, Species, FacetBucket, Media (Codable)
      Util/               MD5+Hex.swift, GeoDistance.swift, Debounce.swift
      UI/                 RadiusHeader.swift, FocusFilterChip.swift, ErrorBanner.swift
    Features/
      Map/                MapTabView, MapViewModel, GBIFMapView (UIViewRepresentable),
                          GBIFDensityTileOverlay (MKTileOverlay)
      Species/            SpeciesTabView, SpeciesViewModel, SpeciesRow, SpeciesDetailView
      Gallery/            GalleryTabView, GalleryViewModel, GalleryTile, OccurrenceDetailView
      Datasets/           DatasetsTabView, DatasetsViewModel, DatasetRow, DatasetDetailView
      About/              AboutTabView (static + Settings form)
    Resources/            Assets.xcassets, Info.plist, PrivacyInfo.xcprivacy
  GBIFNearbyTests/        Unit tests
  GBIFNearbyUITests/      UI smoke tests
  docs/                   (this design doc and future plans)
```

## Shared state and dependency injection

Three `@Observable` stores plus a per-session `FocusFilterStore` are created in `GBIFNearbyApp` and injected through `@Environment` so every tab observes the same source of truth.

| Store | Holds | Persistence | Drives |
|---|---|---|---|
| `LocationStore` | `currentLocation: CLLocation?`, `authStatus`, `manualLocation: CLLocationCoordinate2D?` | session | all tabs |
| `RadiusStore` | `radiusKm: Double` (0.1–100, default 5.0) | `@AppStorage` | all data tabs |
| `TaxonFilterStore` | `selected: KingdomFilter` = `.all`/`.animals`/`.plants`/`.fungi` | `@AppStorage` | all data tabs |
| `FocusFilterStore` | `datasetKey: Int?`, `speciesKey: Int?` | session only | all data tabs when set |

`KingdomFilter` maps to GBIF taxon keys: Animals=1, Plants=6, Fungi=5; `.all` omits the param.

Each view model observes the tuple `(location, radiusKm, kingdomFilter, focusFilter)` and refetches with a **400 ms debounce** when anything changes. Each view model keeps a single `Task<Void, Never>?` for its latest fetch and cancels it before launching the next, so dragging the slider does not stack requests.

## Persistent header (Map, Species, Gallery, Datasets)

Two-row component, materially blurred, so content scrolls under it:

```
┌────────────────────────────────────────────────┐
│  Radius   ●────────⊙─────────●     5.0 km     │   ← slider
│  [ All ] [ 🐾 ] [ 🌿 ] [ 🍄 ]                 │   ← kingdom chips
└────────────────────────────────────────────────┘
```

- Slider: `Slider(value: $radiusKm, in: 0.1...100)` with a logarithmic transformation for finer control at small radii (display value rounded to 1 decimal). Trailing label shows current value in user-selected units (km/mi); the API always receives km.
- Kingdom chips: single-select with an explicit "All" chip. Icons:
  - All — `globe.europe.africa`
  - Animals — `pawprint.fill`
  - Plants — `leaf.fill`
  - Fungi — `allergens` (SF Symbol that reads as mushroom; if needed, ship a custom symbol asset).
  Selected chip is filled with `.tint`; others are bordered.
- Below the header (only when active): `FocusFilterChip` showing "Filter: <species/dataset name> ✕". Tapping ✕ clears `FocusFilterStore`.

## Networking — `GBIFClient`

`actor` wrapping a single `URLSession`:

- Base URL: `https://api.gbif.org/v1` (image cache also under `/v1/image/cache/...`).
- Map tiles: `https://api.gbif.org/v2/map/...`.
- `URLCache(memoryCapacity: 32 MB, diskCapacity: 256 MB)` shared with `AsyncImage`.
- `JSONDecoder` with `.convertFromSnakeCase` and an ISO8601-with-fallback date strategy.
- `timeoutIntervalForRequest = 15 s`.
- User-Agent: `GBIFNearby/{version} (iOS; org.gbif.nearby)`.
- Single connection used for image cache requests (per GBIF docs).

Typed error: `enum GBIFError: Error { case network(URLError); case http(status: Int, message: String?); case decoding(DecodingError); case cancelled }`.

Methods (all `async throws`):

```swift
func occurrenceSearch(_ q: OccurrenceQuery) async throws -> Page<Occurrence>
func occurrenceFacet(_ q: OccurrenceQuery, facet: String, limit: Int) async throws -> [FacetBucket]
func occurrenceCount(_ q: OccurrenceQuery) async throws -> Int
func datasetSearch(query: String?, page: Int) async throws -> Page<Dataset>
func dataset(key: String) async throws -> Dataset
func species(key: Int) async throws -> Species
func vernacularNames(key: Int, language: String) async throws -> [VernacularName]
```

`OccurrenceQuery` is a struct that owns optional `lat/lng/radiusKm`, `kingdomKey`, `taxonKey`, `datasetKey`, `speciesKey`, `mediaType`, `limit`, `offset` and builds the canonical query string (`geo_distance=lat,lng,Xkm`, repeated params where needed).

For testability, view models depend on a `GBIFClienting` protocol — `GBIFClient` is the production implementation; tests use a `URLProtocol`-stubbed `URLSession` or a fake client.

## Image loading

All occurrence imagery loads through the GBIF image cache, never the raw `media.identifier` URL:

```
https://api.gbif.org/v1/image/cache/{WxH}/occurrence/{gbifId}/media/{md5(identifier)}
```

- `md5(identifier)` computed with `Insecure.MD5` from CryptoKit, hex-encoded lowercase.
- Sizes:
  - 100×100 for list thumbnails
  - 400× (width-only, preserves aspect) for gallery tiles
  - 1200× for the full-screen viewer (server max is 1200×1200)
- All loads via `AsyncImage` so the shared `URLCache` handles disk/memory caching automatically.

## Tab 1 — Map

### Layout
```
NavigationStack
  ZStack
    GBIFMapView (UIViewRepresentable wrapping MKMapView)
    VStack(top): RadiusHeader [+ optional FocusFilterChip]
    VStack(bottom-trailing): "Recenter on me" button
```

### `GBIFMapView`
A `UIViewRepresentable` because SwiftUI's native `Map` cannot host `MKTileOverlay`. Bindings: `location`, `radiusKm`, `taxonKey: Int?`, `datasetKey: String?`, `speciesKey: Int?`, `onSelectOccurrence`. `updateUIView` reconciles:

1. **Region** — recentered when `location` changes; span sized to `~3 × radius` so the radius circle isn't edge-to-edge.
2. **Radius circle** — single `MKCircle` overlay, semi-transparent stroke + fill (`MKCircleRenderer`).
3. **Density tile overlay** — `GBIFDensityTileOverlay: MKTileOverlay` with template:
   ```
   https://api.gbif.org/v2/map/occurrence/density/{z}/{x}/{y}@1x.png
     ?srs=EPSG:3857
     &style=classic.poly
     &bin=hex&hexPerTile=75
     [&taxonKey=…] [&datasetKey=…] [&speciesKey=…]
   ```
   When any filter changes the overlay is replaced (not reused) so iOS evicts its tile cache. `canReplaceMapContent = false` keeps Apple's base map underneath.
4. **Pins** — when the camera altitude indicates close zoom (< ~30 km diagonal), the `MapViewModel` fetches `/occurrence/search?geo_distance=…&hasCoordinate=true&limit=300` (with the active filters) and places `MKPointAnnotation`s with `clusteringIdentifier`. At higher zoom levels pins are cleared and the density overlay is sufficient. `regionDidChangeAnimated` triggers a 500 ms debounce.

### Pin interaction
Tap → modal `OccurrenceSheet` showing scientific name, vernacular (per language preference), dataset (tappable → Dataset detail), date, and a "View on GBIF" link in `SFSafariViewController`.

### Location flow
- On first appearance `LocationStore.requestWhenInUseAuthorization()`.
- `.notDetermined` → a soft overlay explaining why and offering the system prompt.
- `.denied/.restricted` → overlay "Location is off — tap to drop a pin instead." Tapping enters pin-drop mode; the dropped coordinate is published to `LocationStore.manualLocation` (what every other tab reads). `RadiusHeader` shows a small "📍 manual" badge while active.

## Tab 2 — Species

### Layout
```
NavigationStack
  VStack
    RadiusHeader
    List (ranked species rows)
      ↓ tap row
    SpeciesDetailView
```

### Fetch (`SpeciesViewModel`)
```
GET /occurrence/search
  ?geo_distance={lat},{lng},{radiusKm}km
  &kingdomKey={…}                    // omitted when .all
  [&datasetKey=…] [&speciesKey=…]    // when FocusFilter set
  &facet=speciesKey
  &facetLimit=100
  &facetMincount=1
  &limit=0
```
Returns ordered `[(speciesKey, count)]`.

### Enrichment
- Top 30 buckets enriched in parallel via `TaskGroup`:
  - `/species/{key}` for scientific name + authorship + higher taxa.
  - `vernacularNames(key:, language:)` (see Vernacular fallback below).
- Image thumbnail (lazy):
  - `/occurrence/search?speciesKey={k}&mediaType=StillImage&limit=1` → take `media[0]` → render via `image/cache/100x100/...`.
- Enriched rows merge back into the facet list preserving rank order.

### Vernacular fallback
```
let lang = userPreference ?? Locale.current.language.languageCode?.identifier ?? "en"
```
1. `GET /species/{key}/vernacularNames?language=<lang>` → first entry.
2. If empty and `lang != "en"`, retry with `language=en`.
3. If still empty, render scientific name only.

Per-session in-memory cache keyed by `(speciesKey, lang)`.

### Row
```
┌────────────────────────────────────────────┐
│ ◯  Bombus terrestris             1,243 ▸  │
│    Buff-tailed bumblebee                   │
└────────────────────────────────────────────┘
```
44×44 thumbnail (placeholder = kingdom SF Symbol). Title italic scientific name. Subtitle vernacular or empty. Trailing: count + chevron.

### `SpeciesDetailView`
- Header: image carousel from `/occurrence/search?speciesKey={k}&mediaType=StillImage&limit=12` (geo-near first, top up globally if < 6 results), images via `image/cache/1200x/...`.
- Scientific name + authorship + vernacular.
- Breadcrumb of higher taxa.
- Stats: total global occurrences, occurrences within current radius (one `occurrenceCount` call).
- IUCN status if returned by `/species/{key}/iucnRedListCategory`.
- "View on GBIF" → `gbif.org/species/{key}` (SFSafariViewController).
- "Show on map" → sets `FocusFilterStore.speciesKey` and switches to Map tab.

## Tab 3 — Gallery

### Layout
```
NavigationStack
  VStack
    RadiusHeader
    LazyVGrid (2–3 columns adaptive)
      ↓ tap tile
    OccurrenceDetailView
```

### Fetch (`GalleryViewModel`)
```
GET /occurrence/search
  ?geo_distance={lat},{lng},{radiusKm}km
  &mediaType=StillImage
  &hasCoordinate=true
  &kingdomKey={…}
  [&datasetKey=…] [&speciesKey=…]
  &limit=50&offset={page*50}
```
- Paginated; load next page when grid scrolls to the last row, until `endOfRecords` or the 500-tile cap.
- Flatten: each `result[].media[]` where `type == "StillImage"` becomes one tile keyed by `(occurrenceKey, mediaIndex)`. Drop occurrences with no usable still image.

### Tile
- Square, `image/cache/400x/...`, subtle bottom gradient overlay with the species name (italic) once the image renders.
- Loading placeholder = neutral tile + kingdom icon. Failure tile = broken-image SF Symbol.

### `OccurrenceDetailView`
- Full-bleed image, 1200× via cache, swipeable horizontally between adjacent tiles (`TabView(.page)`).
- Below: scientific name, vernacular, recorder, date, dataset (tappable → Dataset detail), license, "View on GBIF" (`gbif.org/occurrence/{key}` in SFSafariViewController).

## Tab 4 — Datasets

### Layout
```
NavigationStack(.searchable)
  VStack
    RadiusHeader
    DatasetsToolbar (Toggle: "Search all GBIF datasets")
    List (paginated)
      ↓ tap row
    DatasetDetailView
```

### Mode A — Vicinity-aware (default)
```
GET /occurrence/search
  ?geo_distance={lat},{lng},{radiusKm}km
  &kingdomKey={…}
  [&speciesKey=…]
  &facet=datasetKey
  &facetLimit=100
  &facetMincount=1
  &limit=0
```
Enrich top 30 buckets via `GET /dataset/{key}` for title, publisher, license. Free-text in the search field filters enriched rows client-side on `title`/`publisher` (case-insensitive contains). Header subtitle: "Datasets with records within {radius}".

### Mode B — Global
```
GET /dataset/search
  ?type=OCCURRENCE
  &q={searchText}
  &limit=20&offset={page*20}
```
Standard pagination. Header subtitle: "All GBIF occurrence datasets".

Mode is bound to `@AppStorage("datasetsGlobal")` (off = vicinity). Search input uses SwiftUI `.searchable(text:)` with a 300 ms debounce.

### Row
```
┌──────────────────────────────────────────────┐
│ ▣  iNaturalist Research-grade Observations  ▸│
│    iNaturalist · 123 records nearby          │   (Mode A)
│    OCCURRENCE · CC BY-NC 4.0                 │   (Mode B)
└──────────────────────────────────────────────┘
```

### `DatasetDetailView`
- Header: title, publisher (tap → `gbif.org/publisher/{key}` in SFSafariViewController).
- Description (formatted, expandable).
- Stats: total records, georeferenced records, records within current radius (one `occurrenceCount` call with `datasetKey={k}&geo_distance=…`). Reactive to slider.
- License & citation (copyable; "Copy citation" button).
- Contacts list (email rows → `mailto:`).
- Links row:
  - "View on GBIF" → `gbif.org/dataset/{key}` (SFSafariViewController)
  - "Show on map" → set `FocusFilterStore.datasetKey`, switch to Map tab
  - "Show in gallery" → set `FocusFilterStore.datasetKey`, switch to Gallery tab

## Tab 5 — About + Settings

`Form` with five sections:

- **About this app** — two short paragraphs (purpose, that data comes from GBIF).
- **About GBIF** — short paragraph + logo asset if licensing permits.
- **Settings**
  - **Vernacular language** — `Picker` (Use device language ({resolved}) / English / German / French / Spanish / Portuguese / Japanese / Chinese / …). Bound to `@AppStorage("vernacularLanguage")`; empty string = use locale.
  - **Distance units** — `Picker` Kilometers / Miles. Defaults to `Locale.current.measurementSystem`. Display-only; API always receives km.
  - **Manual location** — if active, "Using manual pin · Clear"; otherwise show authorization status + button to open Settings.app when denied.
- **Links** (each opens in `SFSafariViewController`):
  - `https://www.gbif.org`
  - `https://www.gbif.org/occurrence/search`
  - `https://techdocs.gbif.org/en/openapi/`
  - `https://www.gbif.org/citation-guidelines`
- **App** — version + build from `Bundle.main`, acknowledgements ("Data: GBIF.org · Map tiles: GBIF & Apple Maps").

## Error handling

- Typed `GBIFError` per `GBIFClient` call.
- View models hold `loadingState: Loading<T>` (`.idle / .loading / .loaded(T) / .failed(GBIFError)`).
- Failures render an inline non-modal banner with a "Retry" button — no alert popups.
- Every in-flight request is `Task.cancel()`-ed before a new one starts.

## Testing

**Unit (`GBIFNearbyTests`)**
- `GBIFClient` against canned JSON fixtures using a `URLProtocol` stub — no live network.
- Each view model (`MapViewModel`, `SpeciesViewModel`, `GalleryViewModel`, `DatasetsViewModel`) against a mocked `GBIFClienting` — exercises debounce, kingdom filter, focus filter, cancellation, loading-state transitions.
- Helpers: MD5 hex encoder, `OccurrenceQuery` → query string, vernacular fallback chain, `KingdomFilter` ↔ taxon key mapping.

**UI smoke (`GBIFNearbyUITests`)**
- Launch with simulated location ("San Francisco"), accept permission, switch each tab, drag slider, tap a species row, tap a gallery tile. No assertions on data content — only navigation + non-crash.

Coverage target: `Core/` and view models. SwiftUI views validated via previews + manual run, not snapshot tests.

## Privacy & permissions

- `NSLocationWhenInUseUsageDescription` = "GBIF Nearby uses your location to show species and datasets recorded around you."
- No analytics, no third-party SDKs, no account.
- All traffic to `api.gbif.org` over HTTPS — no ATS exceptions.
- `PrivacyInfo.xcprivacy` declares `NSPrivacyCollectedDataTypes = []` and `NSPrivacyAccessedAPITypes` for `UserDefaults` reason `CA92.1`.

## Performance

- Density tile URLs stable per `(z, x, y, taxonKey, …)` → free disk cache via `URLCache`.
- `AsyncImage` + shared `URLCache` for thumbnails and gallery tiles.
- `LazyVGrid` and `List` keep memory bounded.
- 400 ms debounce on `(radius, kingdom, location, focus)`; 500 ms debounce on map region changes; 300 ms debounce on dataset search input.
- Hard caps: occurrence pin fetch `limit=300`, species/dataset enrichment `top 30`, gallery `500 tiles`.

## Open items (deferred)

- iPad split-view layout.
- Offline data caching beyond `URLCache`.
- Saved locations / favorites.
- Push notifications.
- Localized UI strings.

## Out of scope for this spec

- TestFlight setup and App Store submission steps.
- CI configuration.
- Custom map styling beyond the default GBIF tile style.
