# GBIF Nearby — Plan 2: Species tab

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the Species tab — a ranked list of species occurring within the current radius (filtered by kingdom + focus filter), with thumbnails, vernacular names, and a tap-through detail view that includes an image carousel and a "Show on map" handoff.

**Architecture:** A `SpeciesViewModel` (`@MainActor @Observable`) fetches a `speciesKey` facet from `/occurrence/search`, then enriches the top buckets in parallel via `/species/{key}`, `/species/{key}/vernacularNames`, and a thumbnail occurrence-search per species. Image URLs always go through the GBIF image cache (`/v1/image/cache/{WxH}/occurrence/{gbifId}/media/{md5(identifier)}`). Tab-to-tab handoff uses a new `TabSelectionStore`.

**Tech Stack:** Same as Plan 1 — SwiftUI iOS 17+, Swift Testing, no third-party deps.

---

## Spec

This plan implements the "Tab 2 — Species" section of [`docs/superpowers/specs/2026-05-11-gbif-nearby-ios-app-design.md`](../specs/2026-05-11-gbif-nearby-ios-app-design.md) plus the supporting "Image loading" helper.

## File structure

| Path | Responsibility |
|---|---|
| `GBIFNearby/Core/Util/ImageCacheURL.swift` | Builds `image/cache` URLs from `(occurrenceKey, identifier, size)` |
| `GBIFNearby/Core/Util/VernacularResolver.swift` | Pure function: user pref → device locale → "en" fallback |
| `GBIFNearby/Core/Settings/SettingsStore.swift` | `@Observable` UserDefaults-backed settings (vernacular language) |
| `GBIFNearby/Core/TabSelection/TabSelectionStore.swift` | `@Observable` holding the currently-selected tab |
| `GBIFNearby/Features/Species/SpeciesRowItem.swift` | Aggregate row model (facet + enriched fields) |
| `GBIFNearby/Features/Species/SpeciesViewModel.swift` | Facet fetch + enrichment + thumbnail fetch + state |
| `GBIFNearby/Features/Species/SpeciesListRow.swift` | One row in the species list |
| `GBIFNearby/Features/Species/SpeciesTabView.swift` | NavigationStack + header + list + states |
| `GBIFNearby/Features/Species/SpeciesDetailView.swift` | Detail screen with carousel + breadcrumb + stats + actions |
| Modify: `GBIFNearby/App/AppEnvironment.swift` | Add `settingsStore`, `tabSelectionStore` |
| Modify: `GBIFNearby/App/GBIFNearbyApp.swift` | Inject the two new stores |
| Modify: `GBIFNearby/App/RootTabView.swift` | Bind TabView selection to `TabSelectionStore`, wire `SpeciesTabView` |
| Tests: `GBIFNearbyTests/Core/Util/ImageCacheURLTests.swift` | |
| Tests: `GBIFNearbyTests/Core/Util/VernacularResolverTests.swift` | |
| Tests: `GBIFNearbyTests/Core/Settings/SettingsStoreTests.swift` | |
| Tests: `GBIFNearbyTests/Features/Species/SpeciesViewModelTests.swift` | |

Tab enum (`Tab`) lives in `TabSelectionStore.swift` since it is its primary concern.

## Conventions

- **Build/test from CLI** (avoid `make build/test DEST=…` — the Makefile leaves `$(DEST)` unquoted and the comma in the destination splits in the shell):
  ```
  xcodegen generate
  xcodebuild -scheme GBIFNearby -destination "platform=iOS Simulator,name=iPhone 16e" -derivedDataPath build test -quiet
  xcodebuild -scheme GBIFNearby -destination "platform=iOS Simulator,name=iPhone 16e" -derivedDataPath build build -quiet
  ```
- **TDD where there's logic:** red → green → commit per task.
- **One commit per task** (the engineer may push at any milestone).
- **Test count baseline:** 37 passing before Task 1.

---

## Task 1: `ImageCacheURL` helper (TDD)

**Files:**
- Create: `GBIFNearby/Core/Util/ImageCacheURL.swift`
- Test: `GBIFNearbyTests/Core/Util/ImageCacheURLTests.swift`

- [ ] **Step 1: Write failing tests**

File: `GBIFNearbyTests/Core/Util/ImageCacheURLTests.swift`
```swift
import Testing
import Foundation
@testable import GBIFNearby

@Suite("ImageCacheURL")
struct ImageCacheURLTests {
    @Test("width-only size")
    func widthOnly() {
        let url = ImageCacheURL.build(occurrenceKey: 12345,
                                      identifier: "https://example.org/img.jpg",
                                      size: .width(400))
        // md5("https://example.org/img.jpg") is deterministic; assert the structure.
        #expect(url.absoluteString.hasPrefix("https://api.gbif.org/v1/image/cache/400x/occurrence/12345/media/"))
        let tail = url.absoluteString.replacingOccurrences(of: "https://api.gbif.org/v1/image/cache/400x/occurrence/12345/media/", with: "")
        #expect(tail.count == 32)
        #expect(tail.allSatisfy { "0123456789abcdef".contains($0) })
    }

    @Test("square size")
    func square() {
        let url = ImageCacheURL.build(occurrenceKey: 1,
                                      identifier: "x",
                                      size: .square(100))
        #expect(url.absoluteString.hasPrefix("https://api.gbif.org/v1/image/cache/100x100/occurrence/1/media/"))
    }

    @Test("md5 matches known reference")
    func md5Reference() {
        // md5("hello") = 5d41402abc4b2a76b9719d911017c592
        let url = ImageCacheURL.build(occurrenceKey: 7,
                                      identifier: "hello",
                                      size: .width(200))
        #expect(url.absoluteString == "https://api.gbif.org/v1/image/cache/200x/occurrence/7/media/5d41402abc4b2a76b9719d911017c592")
    }
}
```

- [ ] **Step 2: Regenerate & run — expect failure**

```
xcodegen generate
xcodebuild -scheme GBIFNearby -destination "platform=iOS Simulator,name=iPhone 16e" -derivedDataPath build test -quiet
```
Expected: `Cannot find 'ImageCacheURL' in scope`.

- [ ] **Step 3: Implement**

File: `GBIFNearby/Core/Util/ImageCacheURL.swift`
```swift
import Foundation

enum ImageCacheURL {
    enum Size {
        case width(Int)          // e.g. 400× (preserves aspect)
        case square(Int)         // e.g. 100×100
        var path: String {
            switch self {
            case .width(let w): return "\(w)x"
            case .square(let n): return "\(n)x\(n)"
            }
        }
    }

    static func build(occurrenceKey: Int, identifier: String, size: Size) -> URL {
        let md5 = Data(identifier.utf8).md5HexLowercased()
        return URL(string: "https://api.gbif.org/v1/image/cache/\(size.path)/occurrence/\(occurrenceKey)/media/\(md5)")!
    }
}
```

- [ ] **Step 4: Run — expect 3 new pass; total 40**

```
xcodebuild -scheme GBIFNearby -destination "platform=iOS Simulator,name=iPhone 16e" -derivedDataPath build test -quiet
```

- [ ] **Step 5: Commit**

```bash
git add GBIFNearby/Core/Util/ImageCacheURL.swift GBIFNearbyTests/Core/Util/ImageCacheURLTests.swift
git commit -m "feat(core): add ImageCacheURL helper"
```

---

## Task 2: `VernacularResolver` (TDD)

**Files:**
- Create: `GBIFNearby/Core/Util/VernacularResolver.swift`
- Test: `GBIFNearbyTests/Core/Util/VernacularResolverTests.swift`

- [ ] **Step 1: Write failing tests**

File: `GBIFNearbyTests/Core/Util/VernacularResolverTests.swift`
```swift
import Testing
import Foundation
@testable import GBIFNearby

@Suite("VernacularResolver")
struct VernacularResolverTests {
    @Test("user preference wins")
    func userPref() {
        let lang = VernacularResolver.effectiveLanguage(userPreference: "fr",
                                                        deviceLanguageCode: "de")
        #expect(lang == "fr")
    }

    @Test("device locale when no preference")
    func deviceLocale() {
        let lang = VernacularResolver.effectiveLanguage(userPreference: nil,
                                                        deviceLanguageCode: "de")
        #expect(lang == "de")
    }

    @Test("empty preference falls through to locale")
    func emptyPref() {
        let lang = VernacularResolver.effectiveLanguage(userPreference: "",
                                                        deviceLanguageCode: "es")
        #expect(lang == "es")
    }

    @Test("English fallback when nothing set")
    func englishFallback() {
        let lang = VernacularResolver.effectiveLanguage(userPreference: nil,
                                                        deviceLanguageCode: nil)
        #expect(lang == "en")
    }

    @Test("choose: first hit in preferred language")
    func chooseFirstHit() {
        let names = [
            VernacularName(vernacularName: "Buff-tailed bumblebee", language: "en"),
            VernacularName(vernacularName: "Erdhummel", language: "de"),
        ]
        let chosen = VernacularResolver.choose(from: names, language: "de")
        #expect(chosen == "Erdhummel")
    }

    @Test("choose: language miss falls back to English")
    func chooseFallbackEn() {
        let names = [
            VernacularName(vernacularName: "Buff-tailed bumblebee", language: "en"),
            VernacularName(vernacularName: "Erdhummel", language: "de"),
        ]
        let chosen = VernacularResolver.choose(from: names, language: "fr")
        #expect(chosen == "Buff-tailed bumblebee")
    }

    @Test("choose: nothing matches — returns nil")
    func chooseNoMatch() {
        let names = [VernacularName(vernacularName: "Erdhummel", language: "de")]
        let chosen = VernacularResolver.choose(from: names, language: "fr")
        #expect(chosen == nil)
    }
}
```

- [ ] **Step 2: Regenerate & run — expect failure**

- [ ] **Step 3: Implement**

File: `GBIFNearby/Core/Util/VernacularResolver.swift`
```swift
import Foundation

enum VernacularResolver {
    /// Resolves the effective language code for vernacular name lookup.
    /// - User preference (if non-empty) wins.
    /// - Otherwise, device locale's language code.
    /// - Otherwise, "en".
    static func effectiveLanguage(userPreference: String?, deviceLanguageCode: String?) -> String {
        if let pref = userPreference, pref.isEmpty == false { return pref }
        if let code = deviceLanguageCode, code.isEmpty == false { return code }
        return "en"
    }

    /// Picks a vernacular name from a list: first match in the requested language,
    /// otherwise first match in English, otherwise nil.
    static func choose(from names: [VernacularName], language: String) -> String? {
        if let hit = names.first(where: { $0.language == language }) {
            return hit.vernacularName
        }
        if language != "en", let en = names.first(where: { $0.language == "en" }) {
            return en.vernacularName
        }
        return nil
    }
}
```

- [ ] **Step 4: Run — expect 7 new pass; total 47**

- [ ] **Step 5: Commit**

```bash
git add GBIFNearby/Core/Util/VernacularResolver.swift GBIFNearbyTests/Core/Util/VernacularResolverTests.swift
git commit -m "feat(core): add VernacularResolver language fallback"
```

---

## Task 3: `SettingsStore` (TDD)

**Files:**
- Create: `GBIFNearby/Core/Settings/SettingsStore.swift`
- Test: `GBIFNearbyTests/Core/Settings/SettingsStoreTests.swift`

- [ ] **Step 1: Write failing tests**

File: `GBIFNearbyTests/Core/Settings/SettingsStoreTests.swift`
```swift
import Testing
import Foundation
@testable import GBIFNearby

@MainActor
@Suite("SettingsStore")
struct SettingsStoreTests {
    private func make() -> (SettingsStore, UserDefaults) {
        let suite = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        return (SettingsStore(defaults: suite), suite)
    }

    @Test("vernacularLanguage default is nil")
    func defaultValue() {
        let (s, _) = make()
        #expect(s.vernacularLanguage == nil)
    }

    @Test("persists when set")
    func persists() {
        let (s, d) = make()
        s.vernacularLanguage = "de"
        #expect(d.string(forKey: "vernacularLanguage") == "de")
    }

    @Test("setting empty string clears")
    func clearsOnEmpty() {
        let (s, d) = make()
        s.vernacularLanguage = "de"
        s.vernacularLanguage = ""
        #expect(s.vernacularLanguage == nil)
        #expect(d.string(forKey: "vernacularLanguage") == nil)
    }

    @Test("restores from defaults")
    func restores() {
        let suite = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        suite.set("fr", forKey: "vernacularLanguage")
        let s = SettingsStore(defaults: suite)
        #expect(s.vernacularLanguage == "fr")
    }
}
```

- [ ] **Step 2: Regenerate & run — expect failure**

- [ ] **Step 3: Implement**

File: `GBIFNearby/Core/Settings/SettingsStore.swift`
```swift
import Foundation
import Observation

@MainActor
@Observable
final class SettingsStore {
    static let vernacularLanguageKey = "vernacularLanguage"
    private let defaults: UserDefaults

    var vernacularLanguage: String? {
        didSet {
            if let v = vernacularLanguage, v.isEmpty == false {
                defaults.set(v, forKey: Self.vernacularLanguageKey)
            } else {
                vernacularLanguage = nil
                defaults.removeObject(forKey: Self.vernacularLanguageKey)
            }
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.vernacularLanguage = defaults.string(forKey: Self.vernacularLanguageKey)
    }
}
```

- [ ] **Step 4: Run — expect 4 new pass; total 51**

- [ ] **Step 5: Commit**

```bash
git add GBIFNearby/Core/Settings/SettingsStore.swift GBIFNearbyTests/Core/Settings/SettingsStoreTests.swift
git commit -m "feat(core): add SettingsStore"
```

---

## Task 4: `TabSelectionStore` + wire into `AppEnvironment`

**Files:**
- Create: `GBIFNearby/Core/TabSelection/TabSelectionStore.swift`
- Modify: `GBIFNearby/App/AppEnvironment.swift`
- Modify: `GBIFNearby/App/GBIFNearbyApp.swift`
- Modify: `GBIFNearby/App/RootTabView.swift`

(No automated tests — this is a wire-up.)

- [ ] **Step 1: Create the store**

File: `GBIFNearby/Core/TabSelection/TabSelectionStore.swift`
```swift
import Foundation
import Observation

enum Tab: String, CaseIterable, Sendable {
    case map, species, gallery, datasets, about
}

@MainActor
@Observable
final class TabSelectionStore {
    var current: Tab = .map
}
```

- [ ] **Step 2: Update `AppEnvironment`**

Edit `GBIFNearby/App/AppEnvironment.swift` to:
```swift
import SwiftUI

@MainActor
struct AppEnvironment {
    let locationStore: LocationStore
    let radiusStore: RadiusStore
    let taxonStore: TaxonFilterStore
    let focusStore: FocusFilterStore
    let settingsStore: SettingsStore
    let tabSelectionStore: TabSelectionStore
    let client: any GBIFClienting

    static func production() -> AppEnvironment {
        AppEnvironment(
            locationStore: LocationStore(),
            radiusStore: RadiusStore(),
            taxonStore: TaxonFilterStore(),
            focusStore: FocusFilterStore(),
            settingsStore: SettingsStore(),
            tabSelectionStore: TabSelectionStore(),
            client: GBIFClient()
        )
    }
}
```

- [ ] **Step 3: Update `GBIFNearbyApp.swift` injections**

Edit so the WindowGroup injects both new stores:
```swift
import SwiftUI

@main
struct GBIFNearbyApp: App {
    @State private var env = AppEnvironment.production()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(env.locationStore)
                .environment(env.radiusStore)
                .environment(env.taxonStore)
                .environment(env.focusStore)
                .environment(env.settingsStore)
                .environment(env.tabSelectionStore)
                .environment(\.gbifClient, env.client)
                .task { env.locationStore.requestAuthorization() }
        }
    }
}

private struct GBIFClientKey: EnvironmentKey {
    static let defaultValue: any GBIFClienting = GBIFClient()
}

extension EnvironmentValues {
    var gbifClient: any GBIFClienting {
        get { self[GBIFClientKey.self] }
        set { self[GBIFClientKey.self] = newValue }
    }
}
```

- [ ] **Step 4: Bind TabView selection in `RootTabView`**

Edit `GBIFNearby/App/RootTabView.swift` to:
```swift
import SwiftUI

struct RootTabView: View {
    @Environment(TabSelectionStore.self) private var tabSelection

    var body: some View {
        @Bindable var tabSelection = tabSelection
        TabView(selection: $tabSelection.current) {
            placeholder("Map (next task)")
                .tabItem { Label("Map", systemImage: "map") }
                .tag(Tab.map)
            placeholder("Species")
                .tabItem { Label("Species", systemImage: "leaf") }
                .tag(Tab.species)
            placeholder("Gallery")
                .tabItem { Label("Gallery", systemImage: "photo.on.rectangle") }
                .tag(Tab.gallery)
            placeholder("Datasets")
                .tabItem { Label("Datasets", systemImage: "tray.full") }
                .tag(Tab.datasets)
            placeholder("About")
                .tabItem { Label("About", systemImage: "info.circle") }
                .tag(Tab.about)
        }
    }

    private func placeholder(_ label: String) -> some View {
        NavigationStack {
            VStack(spacing: 0) {
                RadiusHeader()
                FocusFilterChip()
                Spacer()
                Text(label).foregroundStyle(.secondary)
                Spacer()
            }
        }
    }
}

#Preview {
    RootTabView()
        .environment(LocationStore())
        .environment(RadiusStore())
        .environment(TaxonFilterStore())
        .environment(FocusFilterStore())
        .environment(SettingsStore())
        .environment(TabSelectionStore())
}
```

IMPORTANT: The Map tab is back to `placeholder("Map (next task)")` in this step because we'll re-wire `MapTabView` at the end after the Species pieces compile cleanly. WAIT — that's wrong. The Map tab is already live. Restore it now:

Replace the first `placeholder("Map (next task)")` block with:
```swift
MapTabView()
    .tabItem { Label("Map", systemImage: "map") }
    .tag(Tab.map)
```

So the final `RootTabView` body is:
```swift
TabView(selection: $tabSelection.current) {
    MapTabView()
        .tabItem { Label("Map", systemImage: "map") }
        .tag(Tab.map)
    placeholder("Species")
        .tabItem { Label("Species", systemImage: "leaf") }
        .tag(Tab.species)
    placeholder("Gallery")
        .tabItem { Label("Gallery", systemImage: "photo.on.rectangle") }
        .tag(Tab.gallery)
    placeholder("Datasets")
        .tabItem { Label("Datasets", systemImage: "tray.full") }
        .tag(Tab.datasets)
    placeholder("About")
        .tabItem { Label("About", systemImage: "info.circle") }
        .tag(Tab.about)
}
```

- [ ] **Step 5: Build + test**

```
xcodegen generate
xcodebuild -scheme GBIFNearby -destination "platform=iOS Simulator,name=iPhone 16e" -derivedDataPath build test -quiet
```
Expected: 51 tests still pass (no new tests in this task).

- [ ] **Step 6: Commit**

```bash
git add GBIFNearby/Core/TabSelection GBIFNearby/App
git commit -m "feat(app): add SettingsStore + TabSelectionStore; bind TabView selection"
```

---

## Task 5: `SpeciesRowItem` aggregate model

**Files:**
- Create: `GBIFNearby/Features/Species/SpeciesRowItem.swift`

(No tests — it's a value-type aggregate.)

- [ ] **Step 1: Implement**

File: `GBIFNearby/Features/Species/SpeciesRowItem.swift`
```swift
import Foundation

/// One row in the Species list — facet bucket plus optional enriched details.
struct SpeciesRowItem: Identifiable, Sendable, Equatable {
    let speciesKey: Int
    let count: Int
    var scientificName: String?
    var canonicalName: String?
    var authorship: String?
    var vernacularName: String?
    var kingdom: String?
    var thumbnail: ThumbnailRef?

    var id: Int { speciesKey }
}

struct ThumbnailRef: Sendable, Equatable {
    let occurrenceKey: Int
    let mediaIdentifier: String
}
```

- [ ] **Step 2: Build**

```
xcodegen generate
xcodebuild -scheme GBIFNearby -destination "platform=iOS Simulator,name=iPhone 16e" -derivedDataPath build build -quiet
```

- [ ] **Step 3: Commit**

```bash
git add GBIFNearby/Features/Species/SpeciesRowItem.swift
git commit -m "feat(species): add SpeciesRowItem aggregate model"
```

---

## Task 6: `SpeciesViewModel.refresh` — facet fetch only (TDD)

**Files:**
- Create: `GBIFNearby/Features/Species/SpeciesViewModel.swift`
- Test: `GBIFNearbyTests/Features/Species/SpeciesViewModelTests.swift`

- [ ] **Step 1: Write failing tests**

File: `GBIFNearbyTests/Features/Species/SpeciesViewModelTests.swift`
```swift
import Testing
import Foundation
import CoreLocation
@testable import GBIFNearby

@MainActor
@Suite("SpeciesViewModel — facet")
struct SpeciesViewModelTests {
    private func bucket(_ key: String, _ count: Int) -> FacetBucket {
        FacetBucket(name: key, count: count)
    }

    @Test("refresh forwards geo_distance + kingdom + facet params, decodes rows")
    func refresh() async {
        let fake = FakeGBIFClient()
        await fake.setSearch { q in
            #expect(q.lat == 52.5)
            #expect(q.lng == 13.4)
            #expect(q.radiusKm == 5.0)
            #expect(q.kingdomKey == 6)
            #expect(q.facet == "speciesKey")
            #expect(q.facetLimit == 100)
            #expect(q.facetMincount == 1)
            #expect(q.limit == 0)
            return Page(offset: 0, limit: 0, endOfRecords: true, count: 12,
                        results: [],
                        facets: [FacetGroup(field: "SPECIES_KEY",
                                            counts: [self.bucket("5231190", 42),
                                                     self.bucket("5219404", 13)])])
        }
        let vm = SpeciesViewModel(client: fake, settings: SettingsStore())
        await vm.refresh(at: CLLocationCoordinate2D(latitude: 52.5, longitude: 13.4),
                        radiusKm: 5.0, kingdomKey: 6, datasetKey: nil, speciesKey: nil)
        switch vm.rows {
        case .loaded(let items):
            #expect(items.count == 2)
            #expect(items[0].speciesKey == 5231190)
            #expect(items[0].count == 42)
            #expect(items[1].speciesKey == 5219404)
            #expect(items[1].count == 13)
        default: Issue.record("expected loaded, got \(vm.rows)")
        }
    }

    @Test("network error sets failed state")
    func error() async {
        let fake = FakeGBIFClient()
        await fake.setSearch { _ in throw GBIFError.http(status: 502, message: nil) }
        let vm = SpeciesViewModel(client: fake, settings: SettingsStore())
        await vm.refresh(at: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                        radiusKm: 1.0, kingdomKey: nil, datasetKey: nil, speciesKey: nil)
        if case .failed = vm.rows {} else { Issue.record("expected failed") }
    }

    @Test("empty facet returns loaded empty list (not failed)")
    func empty() async {
        let fake = FakeGBIFClient()
        await fake.setSearch { _ in
            Page(offset: 0, limit: 0, endOfRecords: true, count: 0,
                 results: [], facets: [FacetGroup(field: "SPECIES_KEY", counts: [])])
        }
        let vm = SpeciesViewModel(client: fake, settings: SettingsStore())
        await vm.refresh(at: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                        radiusKm: 1.0, kingdomKey: nil, datasetKey: nil, speciesKey: nil)
        switch vm.rows {
        case .loaded(let items): #expect(items.isEmpty)
        default: Issue.record("expected loaded empty")
        }
    }
}
```

- [ ] **Step 2: Regenerate & run — expect failure**

- [ ] **Step 3: Implement**

File: `GBIFNearby/Features/Species/SpeciesViewModel.swift`
```swift
import Foundation
import CoreLocation
import Observation

@MainActor
@Observable
final class SpeciesViewModel {
    private let client: any GBIFClienting
    private let settings: SettingsStore
    private var task: Task<Void, Never>?

    var rows: Loading<[SpeciesRowItem]> = .idle

    init(client: any GBIFClienting, settings: SettingsStore) {
        self.client = client
        self.settings = settings
    }

    /// Fetch the speciesKey facet for the current filters; do not enrich yet.
    func refresh(at coord: CLLocationCoordinate2D, radiusKm: Double,
                 kingdomKey: Int?, datasetKey: String?, speciesKey: Int?) async {
        task?.cancel()
        rows = .loading

        var q = OccurrenceQuery()
        q.lat = coord.latitude
        q.lng = coord.longitude
        q.radiusKm = radiusKm
        q.kingdomKey = kingdomKey
        q.datasetKey = datasetKey
        q.speciesKey = speciesKey
        q.facet = "speciesKey"
        q.facetLimit = 100
        q.facetMincount = 1
        q.limit = 0

        let task = Task { [client] in
            do {
                let page = try await client.occurrenceSearch(q)
                if Task.isCancelled { return }
                let buckets = page.facets?.first?.counts ?? []
                let items: [SpeciesRowItem] = buckets.compactMap { b in
                    guard let key = Int(b.name) else { return nil }
                    return SpeciesRowItem(speciesKey: key, count: b.count)
                }
                self.rows = .loaded(items)
            } catch let error as GBIFError {
                if Task.isCancelled { return }
                self.rows = .failed(error)
            } catch {
                self.rows = .failed(.network(URLError(.unknown)))
            }
        }
        self.task = task
        await task.value
    }
}
```

- [ ] **Step 4: Run — expect 3 new pass; total 54**

- [ ] **Step 5: Commit**

```bash
git add GBIFNearby/Features/Species/SpeciesViewModel.swift GBIFNearbyTests/Features/Species/SpeciesViewModelTests.swift
git commit -m "feat(species): add SpeciesViewModel.refresh facet fetch"
```

---

## Task 7: SpeciesViewModel enrichment (`/species/{key}` + vernacular) (TDD)

**Files:**
- Modify: `GBIFNearby/Features/Species/SpeciesViewModel.swift`
- Modify: `GBIFNearbyTests/Features/Species/SpeciesViewModelTests.swift`

- [ ] **Step 1: Append failing tests**

Add to the end of `SpeciesViewModelTests.swift` before the final `}`:
```swift

    private func sampleSpecies(key: Int, sci: String, kingdom: String = "Plantae") -> Species {
        Species(key: key, scientificName: sci, canonicalName: sci, authorship: "L., 1758",
                kingdom: kingdom, phylum: nil, class: nil, order: nil, family: nil,
                genus: nil, rank: "SPECIES")
    }

    @Test("enrichTopRows fills scientific + vernacular + kingdom")
    func enrich() async {
        let fake = FakeGBIFClient()
        await fake.setSearch { _ in
            Page(offset: 0, limit: 0, endOfRecords: true, count: 0, results: [],
                 facets: [FacetGroup(field: "SPECIES_KEY",
                                     counts: [self.bucket("1", 5), self.bucket("2", 3)])])
        }
        let vmFake = fake
        await vmFake.setSpecies { key in
            self.sampleSpecies(key: key, sci: "Species \(key)")
        }
        await vmFake.setVernacular { key, lang in
            #expect(lang == "de")
            return [VernacularName(vernacularName: "Art \(key)", language: "de")]
        }

        let settings = SettingsStore()
        settings.vernacularLanguage = "de"
        let vm = SpeciesViewModel(client: vmFake, settings: settings)
        await vm.refresh(at: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                        radiusKm: 1, kingdomKey: nil, datasetKey: nil, speciesKey: nil)
        await vm.enrichTopRows(limit: 30)

        guard case .loaded(let items) = vm.rows else {
            Issue.record("expected loaded"); return
        }
        #expect(items.count == 2)
        #expect(items[0].scientificName == "Species 1")
        #expect(items[0].vernacularName == "Art 1")
        #expect(items[0].kingdom == "Plantae")
    }

    @Test("vernacular falls back to English when locale miss")
    func vernacularFallback() async {
        let fake = FakeGBIFClient()
        await fake.setSearch { _ in
            Page(offset: 0, limit: 0, endOfRecords: true, count: 0, results: [],
                 facets: [FacetGroup(field: "SPECIES_KEY", counts: [self.bucket("1", 5)])])
        }
        await fake.setSpecies { key in self.sampleSpecies(key: key, sci: "Sp \(key)") }
        await fake.setVernacular { _, lang in
            // Return empty for "fr", populated for "en"
            if lang == "en" { return [VernacularName(vernacularName: "Daisy", language: "en")] }
            return []
        }
        let settings = SettingsStore()
        settings.vernacularLanguage = "fr"
        let vm = SpeciesViewModel(client: fake, settings: settings)
        await vm.refresh(at: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                        radiusKm: 1, kingdomKey: nil, datasetKey: nil, speciesKey: nil)
        await vm.enrichTopRows(limit: 30)

        guard case .loaded(let items) = vm.rows else { Issue.record("expected loaded"); return }
        #expect(items[0].vernacularName == "Daisy")
    }
```

- [ ] **Step 2: Regenerate & run — expect compile failure (`enrichTopRows` missing)**

- [ ] **Step 3: Implement**

Replace `SpeciesViewModel.swift` with:
```swift
import Foundation
import CoreLocation
import Observation

@MainActor
@Observable
final class SpeciesViewModel {
    private let client: any GBIFClienting
    private let settings: SettingsStore
    private var task: Task<Void, Never>?
    private var enrichTask: Task<Void, Never>?
    private var vernacularCache: [VernacularCacheKey: String?] = [:]

    var rows: Loading<[SpeciesRowItem]> = .idle

    init(client: any GBIFClienting, settings: SettingsStore) {
        self.client = client
        self.settings = settings
    }

    func refresh(at coord: CLLocationCoordinate2D, radiusKm: Double,
                 kingdomKey: Int?, datasetKey: String?, speciesKey: Int?) async {
        task?.cancel()
        enrichTask?.cancel()
        rows = .loading

        var q = OccurrenceQuery()
        q.lat = coord.latitude
        q.lng = coord.longitude
        q.radiusKm = radiusKm
        q.kingdomKey = kingdomKey
        q.datasetKey = datasetKey
        q.speciesKey = speciesKey
        q.facet = "speciesKey"
        q.facetLimit = 100
        q.facetMincount = 1
        q.limit = 0

        let task = Task { [client] in
            do {
                let page = try await client.occurrenceSearch(q)
                if Task.isCancelled { return }
                let buckets = page.facets?.first?.counts ?? []
                let items: [SpeciesRowItem] = buckets.compactMap { b in
                    guard let key = Int(b.name) else { return nil }
                    return SpeciesRowItem(speciesKey: key, count: b.count)
                }
                self.rows = .loaded(items)
            } catch let error as GBIFError {
                if Task.isCancelled { return }
                self.rows = .failed(error)
            } catch {
                self.rows = .failed(.network(URLError(.unknown)))
            }
        }
        self.task = task
        await task.value
    }

    /// Concurrently enrich the first `limit` rows with /species/{key} and vernacular lookups.
    func enrichTopRows(limit: Int = 30) async {
        guard case .loaded(let items) = rows else { return }
        let lang = VernacularResolver.effectiveLanguage(
            userPreference: settings.vernacularLanguage,
            deviceLanguageCode: Locale.current.language.languageCode?.identifier
        )
        let head = Array(items.prefix(limit))
        let tail = Array(items.dropFirst(limit))
        let cacheSnapshot = vernacularCache
        let captureClient = client

        let enriched = await withTaskGroup(of: (Int, SpeciesRowItem).self, returning: [SpeciesRowItem].self) { group in
            for (index, item) in head.enumerated() {
                group.addTask { @Sendable in
                    var row = item
                    if let s = try? await captureClient.species(key: item.speciesKey) {
                        row.scientificName = s.scientificName ?? s.canonicalName
                        row.canonicalName = s.canonicalName
                        row.authorship = s.authorship
                        row.kingdom = s.kingdom
                    }
                    let cacheKey = VernacularCacheKey(speciesKey: item.speciesKey, language: lang)
                    if let cached = cacheSnapshot[cacheKey] {
                        row.vernacularName = cached
                    } else {
                        row.vernacularName = await Self.resolveVernacular(
                            speciesKey: item.speciesKey, language: lang, client: captureClient)
                    }
                    return (index, row)
                }
            }
            var result = head
            for await (index, row) in group {
                if index < result.count { result[index] = row }
            }
            return result
        }

        if Task.isCancelled { return }
        rows = .loaded(enriched + tail)
        for row in enriched {
            let cacheKey = VernacularCacheKey(speciesKey: row.speciesKey, language: lang)
            vernacularCache[cacheKey] = row.vernacularName
        }
    }

    private static func resolveVernacular(speciesKey: Int, language: String, client: any GBIFClienting) async -> String? {
        let names = (try? await client.vernacularNames(key: speciesKey, language: language)) ?? []
        if let chosen = VernacularResolver.choose(from: names, language: language) { return chosen }
        if language != "en" {
            let en = (try? await client.vernacularNames(key: speciesKey, language: "en")) ?? []
            return VernacularResolver.choose(from: en, language: "en")
        }
        return nil
    }
}

private struct VernacularCacheKey: Hashable {
    let speciesKey: Int
    let language: String
}
```

- [ ] **Step 4: Run — expect 2 new pass; total 56**

- [ ] **Step 5: Commit**

```bash
git add GBIFNearby/Features/Species/SpeciesViewModel.swift GBIFNearbyTests/Features/Species/SpeciesViewModelTests.swift
git commit -m "feat(species): enrich top rows with /species and vernacular fallback"
```

---

## Task 8: SpeciesViewModel thumbnail fetch (TDD)

**Files:**
- Modify: `GBIFNearby/Features/Species/SpeciesViewModel.swift`
- Modify: `GBIFNearbyTests/Features/Species/SpeciesViewModelTests.swift`

- [ ] **Step 1: Append failing test**

Add to the test file:
```swift

    @Test("fetchThumbnails populates ThumbnailRef from /occurrence/search?speciesKey=...&mediaType=StillImage")
    func thumbnails() async {
        let fake = FakeGBIFClient()
        await fake.setSearch { q in
            if q.speciesKey == 1, q.mediaType == "StillImage", q.limit == 1 {
                let occ = Occurrence(key: 9001, datasetKey: nil, speciesKey: 1, species: nil,
                                     scientificName: nil, acceptedScientificName: nil,
                                     kingdom: nil, phylum: nil, class: nil, order: nil, family: nil, genus: nil,
                                     decimalLatitude: nil, decimalLongitude: nil,
                                     eventDate: nil, recordedBy: nil, basisOfRecord: nil,
                                     media: [Media(type: "StillImage", format: nil,
                                                   identifier: "https://example.org/img.jpg",
                                                   title: nil, creator: nil, license: nil)])
                return Page(offset: 0, limit: 1, endOfRecords: true, count: 1, results: [occ], facets: nil)
            }
            // Facet response for refresh()
            return Page(offset: 0, limit: 0, endOfRecords: true, count: 0, results: [],
                        facets: [FacetGroup(field: "SPECIES_KEY", counts: [self.bucket("1", 5)])])
        }
        let vm = SpeciesViewModel(client: fake, settings: SettingsStore())
        await vm.refresh(at: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                        radiusKm: 1, kingdomKey: nil, datasetKey: nil, speciesKey: nil)
        await vm.fetchThumbnails(limit: 30)

        guard case .loaded(let items) = vm.rows else { Issue.record("expected loaded"); return }
        #expect(items[0].thumbnail?.occurrenceKey == 9001)
        #expect(items[0].thumbnail?.mediaIdentifier == "https://example.org/img.jpg")
    }
```

- [ ] **Step 2: Regenerate & run — expect compile failure (`fetchThumbnails` missing)**

- [ ] **Step 3: Implement — append method to `SpeciesViewModel`**

Add to `SpeciesViewModel` (before the `private` cache key struct):
```swift
    /// For each of the first `limit` rows, look up one occurrence with a still image
    /// and store a ThumbnailRef. Runs concurrently.
    func fetchThumbnails(limit: Int = 30) async {
        guard case .loaded(let items) = rows else { return }
        let head = Array(items.prefix(limit))
        let tail = Array(items.dropFirst(limit))

        let captureClient = client
        let task = Task<[SpeciesRowItem], Never> { [head] in
            await withTaskGroup(of: (Int, SpeciesRowItem).self, returning: [SpeciesRowItem].self) { group in
                for (index, item) in head.enumerated() {
                    group.addTask {
                        var enriched = item
                        if enriched.thumbnail != nil { return (index, enriched) }
                        var q = OccurrenceQuery()
                        q.speciesKey = item.speciesKey
                        q.mediaType = "StillImage"
                        q.limit = 1
                        let page = try? await captureClient.occurrenceSearch(q)
                        if let occ = page?.results.first,
                           let media = occ.media?.first(where: { $0.type == "StillImage" }),
                           let id = media.identifier {
                            enriched.thumbnail = ThumbnailRef(occurrenceKey: occ.key, mediaIdentifier: id)
                        }
                        return (index, enriched)
                    }
                }
                var result = head
                for await (index, item) in group {
                    if index < result.count { result[index] = item }
                }
                return result
            }
        }
        let enriched = await task.value
        if Task.isCancelled { return }
        rows = .loaded(enriched + tail)
    }
```

- [ ] **Step 4: Run — expect 1 new pass; total 57**

- [ ] **Step 5: Commit**

```bash
git add GBIFNearby/Features/Species/SpeciesViewModel.swift GBIFNearbyTests/Features/Species/SpeciesViewModelTests.swift
git commit -m "feat(species): fetch thumbnails for top rows"
```

---

## Task 9: `SpeciesListRow` view

**Files:**
- Create: `GBIFNearby/Features/Species/SpeciesListRow.swift`

(No automated test — visual.)

- [ ] **Step 1: Implement**

File: `GBIFNearby/Features/Species/SpeciesListRow.swift`
```swift
import SwiftUI

struct SpeciesListRow: View {
    let item: SpeciesRowItem

    var body: some View {
        HStack(spacing: 12) {
            thumbnail
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 2) {
                Text(item.scientificName ?? item.canonicalName ?? "#\(item.speciesKey)")
                    .font(.body.italic())
                    .lineLimit(1)
                if let vernacular = item.vernacularName {
                    Text(vernacular).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            Text(item.count, format: .number)
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let t = item.thumbnail {
            let url = ImageCacheURL.build(occurrenceKey: t.occurrenceKey,
                                          identifier: t.mediaIdentifier,
                                          size: .square(100))
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image): image.resizable().aspectRatio(contentMode: .fill)
                case .empty: placeholder
                case .failure: placeholder
                @unknown default: placeholder
                }
            }
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
        ZStack {
            Color(.tertiarySystemFill)
            Image(systemName: kingdomIcon)
                .foregroundStyle(.secondary)
        }
    }

    private var kingdomIcon: String {
        switch item.kingdom?.lowercased() {
        case "animalia": return "pawprint.fill"
        case "plantae": return "leaf.fill"
        case "fungi": return "allergens"
        default: return "circle.dotted"
        }
    }
}

#Preview {
    List {
        SpeciesListRow(item: SpeciesRowItem(speciesKey: 1, count: 42,
                                            scientificName: "Bellis perennis",
                                            canonicalName: "Bellis perennis",
                                            authorship: "L., 1758",
                                            vernacularName: "Common daisy",
                                            kingdom: "Plantae",
                                            thumbnail: nil))
    }
}
```

- [ ] **Step 2: Build**

- [ ] **Step 3: Commit**

```bash
git add GBIFNearby/Features/Species/SpeciesListRow.swift
git commit -m "feat(species): add SpeciesListRow view"
```

---

## Task 10: `SpeciesTabView` — list + states + debounced refresh

**Files:**
- Create: `GBIFNearby/Features/Species/SpeciesTabView.swift`

- [ ] **Step 1: Implement**

File: `GBIFNearby/Features/Species/SpeciesTabView.swift`
```swift
import SwiftUI
import CoreLocation

struct SpeciesTabView: View {
    @Environment(LocationStore.self) private var location
    @Environment(RadiusStore.self) private var radius
    @Environment(TaxonFilterStore.self) private var taxon
    @Environment(FocusFilterStore.self) private var focus
    @Environment(SettingsStore.self) private var settings
    @Environment(\.gbifClient) private var client

    @State private var viewModel: SpeciesViewModel?
    @State private var debouncer = AsyncDebouncer(delay: .milliseconds(400))

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                RadiusHeader()
                FocusFilterChip()
                content
            }
            .navigationTitle("Species")
            .navigationBarTitleDisplayMode(.inline)
            .task { ensureViewModel() }
            .onChange(of: radius.radiusKm) { _, _ in scheduleFetch() }
            .onChange(of: taxon.selected) { _, _ in scheduleFetch() }
            .onChange(of: focus.datasetKey) { _, _ in scheduleFetch() }
            .onChange(of: focus.speciesKey) { _, _ in scheduleFetch() }
            .onChange(of: location.current?.latitude) { _, _ in scheduleFetch() }
            .onChange(of: location.current?.longitude) { _, _ in scheduleFetch() }
            .onChange(of: settings.vernacularLanguage) { _, _ in scheduleFetch() }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel?.rows ?? .idle {
        case .idle, .loading:
            shimmer
        case .loaded(let items):
            if items.isEmpty {
                empty
            } else {
                List {
                    ForEach(items) { item in
                        NavigationLink {
                            SpeciesDetailView(item: item)
                        } label: {
                            SpeciesListRow(item: item)
                        }
                    }
                }
                .listStyle(.plain)
                .refreshable {
                    await fetchAll()
                }
            }
        case .failed(let err):
            VStack {
                ErrorBanner(message: err.userMessage) {
                    Task { await fetchAll() }
                }
                Spacer()
            }
        }
    }

    private var shimmer: some View {
        List(0..<8, id: \.self) { _ in
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 8).fill(Color(.tertiarySystemFill)).frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: 4) {
                    RoundedRectangle(cornerRadius: 3).fill(Color(.tertiarySystemFill)).frame(height: 12)
                    RoundedRectangle(cornerRadius: 3).fill(Color(.tertiarySystemFill)).frame(width: 120, height: 10)
                }
            }
            .redacted(reason: .placeholder)
            .padding(.vertical, 2)
        }
        .listStyle(.plain)
    }

    private var empty: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "leaf").font(.largeTitle).foregroundStyle(.secondary)
            Text("No species recorded within \(String(format: "%.1f", radius.radiusKm)) km.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Text("Try a larger radius or different group.")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .padding()
    }

    private func ensureViewModel() {
        if viewModel == nil {
            viewModel = SpeciesViewModel(client: client, settings: settings)
        }
        Task { await fetchAll() }
    }

    private func scheduleFetch() {
        Task {
            await debouncer.schedule { await self.fetchAll() }
        }
    }

    private func fetchAll() async {
        guard let center = location.current, let vm = viewModel else { return }
        await vm.refresh(at: center,
                         radiusKm: radius.radiusKm,
                         kingdomKey: taxon.selected.taxonKey,
                         datasetKey: focus.datasetKey,
                         speciesKey: focus.speciesKey)
        await vm.enrichTopRows(limit: 30)
        await vm.fetchThumbnails(limit: 30)
    }
}
```

Note: `SpeciesDetailView` is referenced but defined later in Task 12. To keep this commit building, add a temporary stub:

At the bottom of `SpeciesTabView.swift`, append:
```swift
private struct SpeciesDetailView_TempStub: View {
    let item: SpeciesRowItem
    var body: some View { Text("Detail for #\(item.speciesKey)") }
}
```

Then replace `SpeciesDetailView(item: item)` in the `NavigationLink` with `SpeciesDetailView_TempStub(item: item)` for now. (Task 12 deletes the stub and reverts the call site.)

- [ ] **Step 2: Build (no new tests)**

- [ ] **Step 3: Commit**

```bash
git add GBIFNearby/Features/Species/SpeciesTabView.swift
git commit -m "feat(species): add SpeciesTabView with list, states, debounced refresh"
```

---

## Task 11: Wire `SpeciesTabView` into `RootTabView`

**Files:**
- Modify: `GBIFNearby/App/RootTabView.swift`

- [ ] **Step 1: Replace the Species placeholder**

In `RootTabView.swift`, replace:
```swift
placeholder("Species")
    .tabItem { Label("Species", systemImage: "leaf") }
    .tag(Tab.species)
```
with:
```swift
SpeciesTabView()
    .tabItem { Label("Species", systemImage: "leaf") }
    .tag(Tab.species)
```

- [ ] **Step 2: Build + tests**

```
xcodegen generate
xcodebuild -scheme GBIFNearby -destination "platform=iOS Simulator,name=iPhone 16e" -derivedDataPath build test -quiet
```

Expected: 57 tests still pass.

- [ ] **Step 3: Smoke-launch (best effort)**

```bash
xcrun simctl boot 'iPhone 16e' 2>/dev/null || true
xcrun simctl uninstall booted org.gbif.nearby 2>/dev/null || true
xcrun simctl install booted "$(find build/Build/Products -name 'GBIFNearby.app' -print -quit)"
xcrun simctl launch booted org.gbif.nearby
```

Set a simulated location (Berlin, San Francisco, etc.) in the simulator and grant permission. Tap the Species tab. Expect: shimmer briefly, then a ranked list with species names and counts. Thumbnails fill in shortly after.

- [ ] **Step 4: Commit**

```bash
git add GBIFNearby/App/RootTabView.swift
git commit -m "feat(species): wire SpeciesTabView into RootTabView"
```

---

## Task 12: `SpeciesDetailView` — header + breadcrumb + stats

**Files:**
- Create: `GBIFNearby/Features/Species/SpeciesDetailView.swift`
- Modify: `GBIFNearby/Features/Species/SpeciesTabView.swift` (remove temp stub)

- [ ] **Step 1: Implement detail view (no carousel yet)**

File: `GBIFNearby/Features/Species/SpeciesDetailView.swift`
```swift
import SwiftUI
import SafariServices

struct SpeciesDetailView: View {
    let item: SpeciesRowItem
    @Environment(LocationStore.self) private var location
    @Environment(RadiusStore.self) private var radius
    @Environment(\.gbifClient) private var client

    @State private var globalCount: Int?
    @State private var nearbyCount: Int?
    @State private var showSafari = false

    var body: some View {
        Form {
            Section {
                if let name = item.scientificName ?? item.canonicalName {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(name).font(.title3.italic())
                        if let a = item.authorship {
                            Text(a).font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                }
                if let v = item.vernacularName {
                    Text(v).foregroundStyle(.secondary)
                }
            }

            if let kingdom = item.kingdom {
                Section("Classification") {
                    Text(kingdom)
                }
            }

            Section("Occurrences") {
                statRow("Within \(String(format: "%.1f", radius.radiusKm)) km", value: item.count)
                statRow("Total on GBIF", value: globalCount)
                statRow("Within radius (live)", value: nearbyCount)
            }

            Section {
                Button("View on GBIF.org") { showSafari = true }
            }
        }
        .navigationTitle("Species")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showSafari) {
            SafariView(url: URL(string: "https://www.gbif.org/species/\(item.speciesKey)")!)
                .ignoresSafeArea()
        }
        .task { await loadCounts() }
    }

    @ViewBuilder
    private func statRow(_ label: String, value: Int?) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            if let v = value {
                Text(v, format: .number).monospacedDigit()
            } else {
                ProgressView().controlSize(.mini)
            }
        }
    }

    private func loadCounts() async {
        async let global: Int? = {
            var q = OccurrenceQuery()
            q.speciesKey = item.speciesKey
            return try? await client.occurrenceCount(q)
        }()
        async let nearby: Int? = {
            guard let coord = location.current else { return nil }
            var q = OccurrenceQuery()
            q.speciesKey = item.speciesKey
            q.lat = coord.latitude
            q.lng = coord.longitude
            q.radiusKm = radius.radiusKm
            return try? await client.occurrenceCount(q)
        }()
        let (g, n) = await (global, nearby)
        globalCount = g
        nearbyCount = n
    }
}
```

- [ ] **Step 2: Remove the temp stub from `SpeciesTabView.swift`**

Delete the `SpeciesDetailView_TempStub` struct at the bottom of the file. Replace `SpeciesDetailView_TempStub(item: item)` with `SpeciesDetailView(item: item)` in the `NavigationLink`.

- [ ] **Step 3: Build + tests (57 still pass)**

- [ ] **Step 4: Commit**

```bash
git add GBIFNearby/Features/Species/SpeciesDetailView.swift GBIFNearby/Features/Species/SpeciesTabView.swift
git commit -m "feat(species): add SpeciesDetailView with stats"
```

---

## Task 13: `SpeciesDetailView` — image carousel

**Files:**
- Modify: `GBIFNearby/Features/Species/SpeciesDetailView.swift`

- [ ] **Step 1: Add carousel state + load**

At the top of `SpeciesDetailView`, add:
```swift
    @State private var carouselImages: [ThumbnailRef] = []
```

In `loadCounts()` (rename it `loadDetails()` and also wire it in `.task`), append a third `async let`:

Replace `loadCounts()` with:
```swift
    private func loadDetails() async {
        async let global: Int? = {
            var q = OccurrenceQuery()
            q.speciesKey = item.speciesKey
            return try? await client.occurrenceCount(q)
        }()
        async let nearby: Int? = {
            guard let coord = location.current else { return nil }
            var q = OccurrenceQuery()
            q.speciesKey = item.speciesKey
            q.lat = coord.latitude
            q.lng = coord.longitude
            q.radiusKm = radius.radiusKm
            return try? await client.occurrenceCount(q)
        }()
        async let media: [ThumbnailRef] = {
            // Local first; top up globally if too few.
            var q = OccurrenceQuery()
            q.speciesKey = item.speciesKey
            q.mediaType = "StillImage"
            q.limit = 12
            if let coord = location.current {
                q.lat = coord.latitude
                q.lng = coord.longitude
                q.radiusKm = radius.radiusKm
            }
            var refs = extract(page: try? await client.occurrenceSearch(q))
            if refs.count < 6 {
                var fallback = OccurrenceQuery()
                fallback.speciesKey = item.speciesKey
                fallback.mediaType = "StillImage"
                fallback.limit = 12
                refs += extract(page: try? await client.occurrenceSearch(fallback))
            }
            return Array(refs.prefix(12))
        }()

        let (g, n, m) = await (global, nearby, media)
        globalCount = g
        nearbyCount = n
        carouselImages = m
    }

    private func extract(page: Page<Occurrence>?) -> [ThumbnailRef] {
        guard let results = page?.results else { return [] }
        var out: [ThumbnailRef] = []
        for occ in results {
            for media in occ.media ?? [] where media.type == "StillImage" {
                if let id = media.identifier {
                    out.append(ThumbnailRef(occurrenceKey: occ.key, mediaIdentifier: id))
                }
            }
        }
        return out
    }
```

Replace `.task { await loadCounts() }` with `.task { await loadDetails() }`.

- [ ] **Step 2: Add the carousel section to the form body**

Insert as the first `Section` (before the name/authorship section):
```swift
            if carouselImages.isEmpty == false {
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Array(carouselImages.enumerated()), id: \.offset) { _, ref in
                                let url = ImageCacheURL.build(occurrenceKey: ref.occurrenceKey,
                                                              identifier: ref.mediaIdentifier,
                                                              size: .width(400))
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .success(let image):
                                        image.resizable().aspectRatio(contentMode: .fill)
                                    default:
                                        Color(.tertiarySystemFill)
                                    }
                                }
                                .frame(width: 160, height: 160)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                    .listRowInsets(EdgeInsets())
                }
                .listRowBackground(Color.clear)
            }
```

- [ ] **Step 3: Build + tests (57 still pass)**

- [ ] **Step 4: Commit**

```bash
git add GBIFNearby/Features/Species/SpeciesDetailView.swift
git commit -m "feat(species): add image carousel to SpeciesDetailView"
```

---

## Task 14: "Show on map" handoff

**Files:**
- Modify: `GBIFNearby/Features/Species/SpeciesDetailView.swift`

- [ ] **Step 1: Add Show-on-map button**

In `SpeciesDetailView`, add the environment objects:
```swift
    @Environment(FocusFilterStore.self) private var focus
    @Environment(TabSelectionStore.self) private var tabSelection
```

Insert a new section after the "View on GBIF.org" section:
```swift
            Section {
                Button {
                    let label = item.scientificName ?? item.canonicalName ?? "#\(item.speciesKey)"
                    focus.set(speciesKey: item.speciesKey, label: label)
                    tabSelection.current = .map
                } label: {
                    Label("Show on map", systemImage: "map")
                }
            }
```

- [ ] **Step 2: Build + tests (57 still pass)**

- [ ] **Step 3: Smoke test on simulator**

Re-install and launch. Tap a species row → tap "Show on map". Expect: TabView switches to Map, header shows the focus-filter chip with the species name and a ✕ to clear.

- [ ] **Step 4: Commit**

```bash
git add GBIFNearby/Features/Species/SpeciesDetailView.swift
git commit -m "feat(species): add 'Show on map' handoff via FocusFilter + TabSelection"
```

---

## Closeout

After Plan 2:

- `xcodebuild ... test -quiet` runs **57 tests**.
- The Species tab is fully wired: ranked list, thumbnails, vernacular names with locale fallback, detail screen with image carousel and "Show on map".
- `RootTabView` now uses `TabSelectionStore` to enable programmatic tab switching.
- `SettingsStore` is in place but only the `vernacularLanguage` setting is consumed; the settings UI itself ships in Plan 5 (About + Settings).

Push when ready:
```bash
git push origin main
```

**Next plan:** `2026-05-11-gbif-nearby-plan-3-gallery-tab.md` — Pinterest-style occurrence-image grid using paginated `/occurrence/search?mediaType=StillImage`, full-screen viewer with swipe, all images via the GBIF image cache.
