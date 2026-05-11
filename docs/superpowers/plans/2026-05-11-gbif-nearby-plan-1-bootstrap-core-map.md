# GBIF Nearby — Plan 1: Bootstrap + Core + Map

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stand up the iOS Xcode project, build the shared Core foundation (stores, GBIF API client, models, utilities, persistent header), and ship a working Map tab that shows GBIF density tiles + tappable pins centered on the user's location. Result: a runnable iOS app delivering the MVP.

**Architecture:** SwiftUI app for iOS 17+. Single Xcode target generated from a `project.yml` with [XcodeGen](https://github.com/yonaskolb/XcodeGen). Shared `@Observable` stores (Location, Radius, TaxonFilter, FocusFilter) injected via `@Environment`. A `GBIFClient` actor wraps `URLSession` and offers async/await endpoints. Views consume view models that observe the stores and refetch with a 400 ms debounce. Map tab wraps `MKMapView` via `UIViewRepresentable` so it can host an `MKTileOverlay` pointed at the GBIF density-tile endpoint, with annotation pins fetched from `/occurrence/search` at close zoom.

**Tech Stack:** Swift 5.10, SwiftUI, MapKit, CoreLocation, CryptoKit, SafariServices, Foundation. Test framework: Swift Testing (Xcode 16+). Project generation: XcodeGen. CLI build/test: `xcodebuild`.

---

## Spec

This plan implements the parts of [`docs/superpowers/specs/2026-05-11-gbif-nearby-ios-app-design.md`](../specs/2026-05-11-gbif-nearby-ios-app-design.md) needed for Phase 0 (bootstrap), Phase 1 (Core foundation), and Phase 2 (Map tab). Species, Gallery, Datasets, and About tabs are covered by follow-up plans.

## Test approach

- **Framework:** Swift Testing (`import Testing`, `@Test` macros, `#expect`/`#require`). Xcode 16+ includes it; no extra package needed.
- **Run tests from CLI:**
  ```
  xcodebuild test -scheme GBIFNearby -destination 'platform=iOS Simulator,name=iPhone 15'
  ```
  (If iPhone 15 is missing, substitute any installed simulator name from `xcrun simctl list devices available`.)
- **Network mocking:** Every test that exercises `GBIFClient` builds a `URLSession` configured with a `MockURLProtocol` so no real network calls happen. Handler closure inspects the outgoing `URLRequest` (assert on URL and query params) and returns a stubbed `(HTTPURLResponse, Data)`.
- **View model isolation:** All view models depend on `GBIFClienting` (protocol). Production wires in `GBIFClient`; tests wire in a `FakeGBIFClient` that records calls and returns canned values.
- **Stores:** Persisted-state tests reset `UserDefaults` using a test suite name.
- **Views:** SwiftUI views are validated via Xcode previews and manual run on a simulator — no snapshot/UI tests in this plan.

## File structure

This plan creates the following files. Subsequent plans will add Features/Species, Features/Gallery, Features/Datasets, Features/About.

| Path | Responsibility |
|---|---|
| `project.yml` | XcodeGen spec; single iOS app target + unit-test target |
| `Makefile` | One-line wrappers: `make project`, `make build`, `make test` |
| `GBIFNearby/App/GBIFNearbyApp.swift` | `@main` entry, constructs shared stores |
| `GBIFNearby/App/RootTabView.swift` | TabView with 5 tabs (Map live; others are placeholders) |
| `GBIFNearby/App/AppEnvironment.swift` | Bundled environment values for tests/previews |
| `GBIFNearby/Resources/Info.plist` | Bundle config + `NSLocationWhenInUseUsageDescription` |
| `GBIFNearby/Resources/Assets.xcassets/` | App icon + accent color placeholders |
| `GBIFNearby/Core/Util/MD5Hex.swift` | `Data.md5HexLowercased()` extension |
| `GBIFNearby/Core/Util/Debounce.swift` | `AsyncDebouncer` helper for view models |
| `GBIFNearby/Core/Util/GeoDistance.swift` | `geo_distance` query-string builder |
| `GBIFNearby/Core/Models/Models.swift` | All `Codable` API DTOs (`Occurrence`, `Page`, `FacetBucket`, etc.) |
| `GBIFNearby/Core/Models/KingdomFilter.swift` | Enum + taxon-key mapping |
| `GBIFNearby/Core/Networking/GBIFError.swift` | Typed error |
| `GBIFNearby/Core/Networking/Loading.swift` | Generic `Loading<T>` enum |
| `GBIFNearby/Core/Networking/OccurrenceQuery.swift` | Query struct → URL query items |
| `GBIFNearby/Core/Networking/GBIFClienting.swift` | Protocol surface |
| `GBIFNearby/Core/Networking/GBIFClient.swift` | Production actor |
| `GBIFNearby/Core/Location/LocationStore.swift` | `@Observable` wrapper around `CLLocationManager` |
| `GBIFNearby/Core/Radius/RadiusStore.swift` | `@Observable`, UserDefaults-backed |
| `GBIFNearby/Core/TaxonFilter/TaxonFilterStore.swift` | `@Observable`, UserDefaults-backed |
| `GBIFNearby/Core/FocusFilter/FocusFilterStore.swift` | `@Observable`, session-only |
| `GBIFNearby/Core/UI/RadiusHeader.swift` | Persistent slider + kingdom chips |
| `GBIFNearby/Core/UI/ErrorBanner.swift` | Inline retry banner |
| `GBIFNearby/Core/UI/FocusFilterChip.swift` | "Filter: ✕" chip |
| `GBIFNearby/Features/Map/MapTabView.swift` | NavigationStack + header + map |
| `GBIFNearby/Features/Map/MapViewModel.swift` | Pin fetch + state |
| `GBIFNearby/Features/Map/GBIFMapView.swift` | `UIViewRepresentable` wrapping `MKMapView` |
| `GBIFNearby/Features/Map/GBIFDensityTileOverlay.swift` | `MKTileOverlay` subclass |
| `GBIFNearby/Features/Map/OccurrenceSheet.swift` | Pin-tap modal |
| `GBIFNearbyTests/Core/Util/MD5HexTests.swift` | |
| `GBIFNearbyTests/Core/Util/GeoDistanceTests.swift` | |
| `GBIFNearbyTests/Core/Util/DebounceTests.swift` | |
| `GBIFNearbyTests/Core/Models/ModelsTests.swift` | JSON fixtures decode correctly |
| `GBIFNearbyTests/Core/Networking/OccurrenceQueryTests.swift` | |
| `GBIFNearbyTests/Core/Networking/GBIFClientTests.swift` | URLProtocol-mocked |
| `GBIFNearbyTests/Core/Networking/MockURLProtocol.swift` | Test helper |
| `GBIFNearbyTests/Core/Networking/FakeGBIFClient.swift` | Test helper |
| `GBIFNearbyTests/Core/Stores/RadiusStoreTests.swift` | |
| `GBIFNearbyTests/Core/Stores/TaxonFilterStoreTests.swift` | |
| `GBIFNearbyTests/Core/Stores/FocusFilterStoreTests.swift` | |
| `GBIFNearbyTests/Features/Map/MapViewModelTests.swift` | |
| `GBIFNearbyTests/Features/Map/GBIFDensityTileOverlayTests.swift` | URL building |
| `GBIFNearbyTests/Fixtures/*.json` | Canned API responses |

---

## Phase 0 — Project bootstrap

### Task 0.1: Install XcodeGen and write `project.yml`

**Files:**
- Create: `project.yml`
- Create: `Makefile`

- [ ] **Step 1: Install XcodeGen via Homebrew**

Run:
```bash
brew install xcodegen
```
Expected: `xcodegen --version` prints a version ≥ 2.40.

- [ ] **Step 2: Create `project.yml`**

File: `project.yml`
```yaml
name: GBIFNearby
options:
  bundleIdPrefix: org.gbif
  deploymentTarget:
    iOS: "17.0"
  createIntermediateGroups: true
  generateEmptyDirectories: true
settings:
  base:
    SWIFT_VERSION: "5.10"
    IPHONEOS_DEPLOYMENT_TARGET: "17.0"
    DEVELOPMENT_TEAM: ""
    CODE_SIGN_STYLE: Automatic
    ENABLE_USER_SCRIPT_SANDBOXING: NO
targets:
  GBIFNearby:
    type: application
    platform: iOS
    sources:
      - path: GBIFNearby
    resources:
      - GBIFNearby/Resources
    info:
      path: GBIFNearby/Resources/Info.plist
      properties:
        CFBundleDisplayName: GBIF Nearby
        CFBundleShortVersionString: "0.1.0"
        CFBundleVersion: "1"
        LSRequiresIPhoneOS: true
        UILaunchScreen:
          UIColorName: ""
        UISupportedInterfaceOrientations:
          - UIInterfaceOrientationPortrait
          - UIInterfaceOrientationLandscapeLeft
          - UIInterfaceOrientationLandscapeRight
        NSLocationWhenInUseUsageDescription: "GBIF Nearby uses your location to show species and datasets recorded around you."
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: org.gbif.nearby
        TARGETED_DEVICE_FAMILY: "1"
        GENERATE_INFOPLIST_FILE: NO
  GBIFNearbyTests:
    type: bundle.unit-test
    platform: iOS
    sources:
      - path: GBIFNearbyTests
    dependencies:
      - target: GBIFNearby
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: org.gbif.nearby.tests
schemes:
  GBIFNearby:
    build:
      targets:
        GBIFNearby: all
        GBIFNearbyTests: [test]
    test:
      targets:
        - GBIFNearbyTests
```

- [ ] **Step 3: Create `Makefile`**

File: `Makefile`
```makefile
.PHONY: project build test clean

DEST ?= 'platform=iOS Simulator,name=iPhone 15'
DD := build

project:
	xcodegen generate

build: project
	xcodebuild -scheme GBIFNearby -destination $(DEST) -derivedDataPath $(DD) -quiet build

test: project
	xcodebuild -scheme GBIFNearby -destination $(DEST) -derivedDataPath $(DD) -quiet test

clean:
	rm -rf GBIFNearby.xcodeproj build

app-path:
	@find $(DD)/Build/Products -name 'GBIFNearby.app' -print -quit
```

- [ ] **Step 4: Commit**

```bash
git add project.yml Makefile
git commit -m "chore: add XcodeGen project spec and Makefile"
```

---

### Task 0.2: Create minimal app source so XcodeGen generates a valid project

**Files:**
- Create: `GBIFNearby/App/GBIFNearbyApp.swift`
- Create: `GBIFNearby/App/RootTabView.swift`
- Create: `GBIFNearby/Resources/Info.plist`
- Create: `GBIFNearby/Resources/Assets.xcassets/Contents.json`
- Create: `GBIFNearby/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json`
- Create: `GBIFNearby/Resources/Assets.xcassets/AccentColor.colorset/Contents.json`
- Create: `GBIFNearbyTests/Info.plist` (required by XcodeGen unit-test bundle for code signing)
- Create: `GBIFNearbyTests/SmokeTest.swift`
- Modify: `project.yml` — add `info: { path: GBIFNearbyTests/Info.plist }` to `GBIFNearbyTests` target

- [ ] **Step 1: Create the app entry point**

File: `GBIFNearby/App/GBIFNearbyApp.swift`
```swift
import SwiftUI

@main
struct GBIFNearbyApp: App {
    var body: some Scene {
        WindowGroup {
            RootTabView()
        }
    }
}
```

- [ ] **Step 2: Create the placeholder tab bar**

File: `GBIFNearby/App/RootTabView.swift`
```swift
import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            Text("Map").tabItem { Label("Map", systemImage: "map") }
            Text("Species").tabItem { Label("Species", systemImage: "leaf") }
            Text("Gallery").tabItem { Label("Gallery", systemImage: "photo.on.rectangle") }
            Text("Datasets").tabItem { Label("Datasets", systemImage: "tray.full") }
            Text("About").tabItem { Label("About", systemImage: "info.circle") }
        }
    }
}

#Preview { RootTabView() }
```

- [ ] **Step 3: Create the Info.plist**

File: `GBIFNearby/Resources/Info.plist`
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>$(EXECUTABLE_NAME)</string>
    <key>CFBundleIdentifier</key>
    <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
    <key>CFBundleName</key>
    <string>$(PRODUCT_NAME)</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
</dict>
</plist>
```

(The display name, location usage description, and version come from `project.yml` via `info.properties`.)

- [ ] **Step 4: Create asset catalog stubs**

File: `GBIFNearby/Resources/Assets.xcassets/Contents.json`
```json
{ "info" : { "author" : "xcode", "version" : 1 } }
```

File: `GBIFNearby/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json`
```json
{
  "images" : [
    { "idiom" : "universal", "platform" : "ios", "size" : "1024x1024" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
```

File: `GBIFNearby/Resources/Assets.xcassets/AccentColor.colorset/Contents.json`
```json
{
  "colors" : [
    { "idiom" : "universal", "color" : { "platform" : "universal", "reference" : "systemGreenColor" } }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
```

- [ ] **Step 5: Create a smoke test so the test target compiles**

File: `GBIFNearbyTests/SmokeTest.swift`
```swift
import Testing
@testable import GBIFNearby

@Suite("Smoke")
struct SmokeTest {
    @Test("Module imports")
    func moduleImports() {
        // If this compiles, the test target is wired correctly.
        #expect(Bool(true))
    }
}
```

- [ ] **Step 6: Generate the Xcode project**

Run:
```bash
make project
```
Expected: prints `Created project at /Users/markus/code/games/gbif-nearby/GBIFNearby.xcodeproj` (or equivalent). A `GBIFNearby.xcodeproj` directory now exists.

- [ ] **Step 7: Build**

Run:
```bash
make build
```
Expected: build succeeds with no errors. Warnings about missing app icon assets are fine.

- [ ] **Step 8: Run tests**

Run:
```bash
make test
```
Expected: `Test Suite 'Smoke' passed`, 1 test passed.

- [ ] **Step 9: Commit**

```bash
git add GBIFNearby GBIFNearbyTests
git commit -m "feat: bootstrap empty SwiftUI app with five placeholder tabs"
```

---

### Task 0.3: Add `.gitignore` entries for the generated Xcode project

**Files:**
- Modify: `.gitignore`

- [ ] **Step 1: Append generated-project ignore**

Edit `.gitignore`, append at end:
```
# Generated by XcodeGen
GBIFNearby.xcodeproj/
```

(Generated `.xcodeproj` is reproducible from `project.yml`. Tracking it would invite merge conflicts.)

- [ ] **Step 2: Verify git status is clean**

Run:
```bash
git status
```
Expected: `.gitignore` shows as modified; `GBIFNearby.xcodeproj/` does not appear in untracked.

- [ ] **Step 3: Commit**

```bash
git add .gitignore
git commit -m "chore: gitignore generated Xcode project"
```

---

## Phase 1 — Core foundation

### Task 1.1: `Data.md5HexLowercased()` extension (TDD)

**Files:**
- Create: `GBIFNearby/Core/Util/MD5Hex.swift`
- Test: `GBIFNearbyTests/Core/Util/MD5HexTests.swift`

- [ ] **Step 1: Write the failing tests**

File: `GBIFNearbyTests/Core/Util/MD5HexTests.swift`
```swift
import Testing
import Foundation
@testable import GBIFNearby

@Suite("MD5Hex")
struct MD5HexTests {
    @Test("empty string")
    func empty() {
        #expect(Data().md5HexLowercased() == "d41d8cd98f00b204e9800998ecf8427e")
    }

    @Test("'hello'")
    func hello() {
        let data = "hello".data(using: .utf8)!
        #expect(data.md5HexLowercased() == "5d41402abc4b2a76b9719d911017c592")
    }

    @Test("URL identifier")
    func urlIdentifier() {
        let id = "https://example.org/photos/123.jpg"
        let data = id.data(using: .utf8)!
        // verified externally with `md5 -s '<id>'`
        #expect(data.md5HexLowercased().count == 32)
        #expect(data.md5HexLowercased().allSatisfy { "0123456789abcdef".contains($0) })
    }
}
```

- [ ] **Step 2: Regenerate the project so the test file is picked up**

Run:
```bash
make project
```

- [ ] **Step 3: Run to verify failure**

Run:
```bash
make test
```
Expected: build fails — `Value of type 'Data' has no member 'md5HexLowercased'`.

- [ ] **Step 4: Implement**

File: `GBIFNearby/Core/Util/MD5Hex.swift`
```swift
import Foundation
import CryptoKit

extension Data {
    func md5HexLowercased() -> String {
        let digest = Insecure.MD5.hash(data: self)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
```

- [ ] **Step 5: Run tests**

Run:
```bash
make test
```
Expected: 3 tests in `MD5Hex` pass.

- [ ] **Step 6: Commit**

```bash
git add GBIFNearby/Core/Util/MD5Hex.swift GBIFNearbyTests/Core/Util/MD5HexTests.swift
git commit -m "feat(core): add Data.md5HexLowercased() extension"
```

---

### Task 1.2: `GeoDistance` query-string formatter (TDD)

**Files:**
- Create: `GBIFNearby/Core/Util/GeoDistance.swift`
- Test: `GBIFNearbyTests/Core/Util/GeoDistanceTests.swift`

- [ ] **Step 1: Write the failing tests**

File: `GBIFNearbyTests/Core/Util/GeoDistanceTests.swift`
```swift
import Testing
@testable import GBIFNearby

@Suite("GeoDistance")
struct GeoDistanceTests {
    @Test("formats lat,lng,Xkm with 4-decimal precision")
    func basic() {
        let s = GeoDistance.queryValue(lat: 52.5200, lng: 13.4050, radiusKm: 5.0)
        #expect(s == "52.5200,13.4050,5km")
    }

    @Test("preserves sub-km precision to 1 decimal")
    func subKm() {
        let s = GeoDistance.queryValue(lat: 0.0, lng: 0.0, radiusKm: 0.1)
        #expect(s == "0.0000,0.0000,0.1km")
    }

    @Test("rounds radius to 1 decimal")
    func roundsRadius() {
        let s = GeoDistance.queryValue(lat: 1.0, lng: 2.0, radiusKm: 7.84)
        #expect(s == "1.0000,2.0000,7.8km")
    }

    @Test("supports negative coordinates")
    func negative() {
        let s = GeoDistance.queryValue(lat: -33.8688, lng: 151.2093, radiusKm: 12.0)
        #expect(s == "-33.8688,151.2093,12.0km")
    }
}
```

- [ ] **Step 2: Regenerate and run to verify failure**

Run:
```bash
make project && make test
```
Expected: build fails — `Cannot find 'GeoDistance' in scope`.

- [ ] **Step 3: Implement**

File: `GBIFNearby/Core/Util/GeoDistance.swift`
```swift
import Foundation

enum GeoDistance {
    static func queryValue(lat: Double, lng: Double, radiusKm: Double) -> String {
        let latS = String(format: "%.4f", lat)
        let lngS = String(format: "%.4f", lng)
        let kmS = String(format: "%.1f", radiusKm)
        return "\(latS),\(lngS),\(kmS)km"
    }
}
```

- [ ] **Step 4: Run tests**

Run:
```bash
make test
```
Expected: 4 tests pass.

- [ ] **Step 5: Commit**

```bash
git add GBIFNearby/Core/Util/GeoDistance.swift GBIFNearbyTests/Core/Util/GeoDistanceTests.swift
git commit -m "feat(core): add GeoDistance.queryValue formatter"
```

---

### Task 1.3: `AsyncDebouncer` helper (TDD)

**Files:**
- Create: `GBIFNearby/Core/Util/Debounce.swift`
- Test: `GBIFNearbyTests/Core/Util/DebounceTests.swift`

- [ ] **Step 1: Write the failing tests**

File: `GBIFNearbyTests/Core/Util/DebounceTests.swift`
```swift
import Testing
import Foundation
@testable import GBIFNearby

@Suite("AsyncDebouncer")
struct DebounceTests {
    @Test("fires only the last scheduled action after the delay")
    func collapseRapidCalls() async {
        let debouncer = AsyncDebouncer(delay: .milliseconds(100))
        actor Counter { var n = 0; func inc() { n += 1 } }
        let counter = Counter()
        await debouncer.schedule { await counter.inc() }
        await debouncer.schedule { await counter.inc() }
        await debouncer.schedule { await counter.inc() }
        try? await Task.sleep(for: .milliseconds(250))
        #expect(await counter.n == 1)
    }

    @Test("cancel prevents the pending action")
    func cancel() async {
        let debouncer = AsyncDebouncer(delay: .milliseconds(100))
        actor Flag { var fired = false; func set() { fired = true } }
        let flag = Flag()
        await debouncer.schedule { await flag.set() }
        await debouncer.cancel()
        try? await Task.sleep(for: .milliseconds(200))
        #expect(await flag.fired == false)
    }
}
```

- [ ] **Step 2: Regenerate and run to verify failure**

Run:
```bash
make project && make test
```
Expected: build fails — `Cannot find 'AsyncDebouncer' in scope`.

- [ ] **Step 3: Implement**

File: `GBIFNearby/Core/Util/Debounce.swift`
```swift
import Foundation

actor AsyncDebouncer {
    private let delay: Duration
    private var task: Task<Void, Never>?

    init(delay: Duration) {
        self.delay = delay
    }

    func schedule(_ action: @escaping @Sendable () async -> Void) {
        task?.cancel()
        task = Task {
            try? await Task.sleep(for: delay)
            if Task.isCancelled { return }
            await action()
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
    }
}
```

- [ ] **Step 4: Run tests**

Run:
```bash
make test
```
Expected: 2 tests pass.

- [ ] **Step 5: Commit**

```bash
git add GBIFNearby/Core/Util/Debounce.swift GBIFNearbyTests/Core/Util/DebounceTests.swift
git commit -m "feat(core): add AsyncDebouncer"
```

---

### Task 1.4: API DTOs and decoder fixture tests (TDD)

**Files:**
- Create: `GBIFNearby/Core/Models/Models.swift`
- Create: `GBIFNearby/Core/Models/KingdomFilter.swift`
- Create: `GBIFNearbyTests/Fixtures/occurrence-search.json`
- Create: `GBIFNearbyTests/Fixtures/occurrence-facet-species.json`
- Test: `GBIFNearbyTests/Core/Models/ModelsTests.swift`

- [ ] **Step 1: Capture real fixtures from the live GBIF API**

Run these and pipe into the fixtures directory (run from repo root):
```bash
mkdir -p GBIFNearbyTests/Fixtures
curl -s 'https://api.gbif.org/v1/occurrence/search?geo_distance=52.5200,13.4050,5km&limit=2&hasCoordinate=true' \
  > GBIFNearbyTests/Fixtures/occurrence-search.json
curl -s 'https://api.gbif.org/v1/occurrence/search?geo_distance=52.5200,13.4050,5km&facet=speciesKey&facetLimit=5&limit=0' \
  > GBIFNearbyTests/Fixtures/occurrence-facet-species.json
```
Expected: both files exist and contain valid JSON (verify with `head -c 200` on each).

- [ ] **Step 2: Write the failing model tests**

File: `GBIFNearbyTests/Core/Models/ModelsTests.swift`
```swift
import Testing
import Foundation
@testable import GBIFNearby

@Suite("Models")
struct ModelsTests {
    static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    private func fixture(_ name: String) throws -> Data {
        let url = Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures")!
        return try Data(contentsOf: url)
    }

    @Test("decodes /occurrence/search page")
    func decodesOccurrencePage() throws {
        let data = try fixture("occurrence-search")
        let page = try Self.decoder.decode(Page<Occurrence>.self, from: data)
        #expect(page.results.count <= 2)
        #expect(page.endOfRecords != nil)
    }

    @Test("decodes facet response")
    func decodesFacetResponse() throws {
        let data = try fixture("occurrence-facet-species")
        let page = try Self.decoder.decode(Page<Occurrence>.self, from: data)
        #expect(page.facets?.first?.field == "SPECIES_KEY" || page.facets?.first?.field == "speciesKey")
        #expect((page.facets?.first?.counts ?? []).isEmpty == false || page.count == 0)
    }

    @Test("KingdomFilter taxon-key mapping")
    func kingdomMapping() {
        #expect(KingdomFilter.all.taxonKey == nil)
        #expect(KingdomFilter.animals.taxonKey == 1)
        #expect(KingdomFilter.plants.taxonKey == 6)
        #expect(KingdomFilter.fungi.taxonKey == 5)
    }
}
```

NOTE: `Bundle.module` requires fixtures to be discoverable as resources. We'll wire that via the test target's resources path (the entire `GBIFNearbyTests` source tree is copied; folders named `Fixtures` end up at the bundle root). XcodeGen handles this when fixtures are under the test target's `path:`.

- [ ] **Step 3: Update `project.yml` to bundle fixture resources**

Edit `project.yml`, change the `GBIFNearbyTests` target block to:
```yaml
  GBIFNearbyTests:
    type: bundle.unit-test
    platform: iOS
    sources:
      - path: GBIFNearbyTests
        excludes:
          - "Fixtures/**"
    resources:
      - path: GBIFNearbyTests/Fixtures
    dependencies:
      - target: GBIFNearby
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: org.gbif.nearby.tests
```

- [ ] **Step 4: Regenerate and run to verify failure**

Run:
```bash
make project && make test
```
Expected: build fails — `Cannot find type 'Page' / 'Occurrence' / 'KingdomFilter' in scope`.

- [ ] **Step 5: Implement the models**

File: `GBIFNearby/Core/Models/Models.swift`
```swift
import Foundation

struct Page<Element: Codable & Sendable>: Codable, Sendable {
    let offset: Int?
    let limit: Int?
    let endOfRecords: Bool?
    let count: Int?
    let results: [Element]
    let facets: [FacetGroup]?
}

struct FacetGroup: Codable, Sendable {
    let field: String
    let counts: [FacetBucket]
}

struct FacetBucket: Codable, Sendable {
    let name: String
    let count: Int
}

struct Occurrence: Codable, Sendable, Identifiable {
    let key: Int
    let datasetKey: String?
    let speciesKey: Int?
    let species: String?
    let scientificName: String?
    let acceptedScientificName: String?
    let kingdom: String?
    let phylum: String?
    let `class`: String?
    let order: String?
    let family: String?
    let genus: String?
    let decimalLatitude: Double?
    let decimalLongitude: Double?
    let eventDate: String?
    let recordedBy: String?
    let basisOfRecord: String?
    let media: [Media]?

    var id: Int { key }

    enum CodingKeys: String, CodingKey {
        case key, datasetKey, speciesKey, species
        case scientificName, acceptedScientificName
        case kingdom, phylum, `class`, order, family, genus
        case decimalLatitude, decimalLongitude
        case eventDate, recordedBy, basisOfRecord, media
    }
}

struct Media: Codable, Sendable {
    let type: String?
    let format: String?
    let identifier: String?
    let title: String?
    let creator: String?
    let license: String?
}

struct Dataset: Codable, Sendable, Identifiable {
    let key: String
    let title: String
    let type: String?
    let license: String?
    let description: String?
    let publishingOrganizationKey: String?
    let publishingOrganizationTitle: String?
    let citation: Citation?
    let contacts: [DatasetContact]?

    var id: String { key }
}

struct Citation: Codable, Sendable {
    let text: String?
}

struct DatasetContact: Codable, Sendable {
    let firstName: String?
    let lastName: String?
    let email: [String]?
    let type: String?
}

struct Species: Codable, Sendable, Identifiable {
    let key: Int
    let scientificName: String?
    let canonicalName: String?
    let authorship: String?
    let kingdom: String?
    let phylum: String?
    let `class`: String?
    let order: String?
    let family: String?
    let genus: String?
    let rank: String?

    var id: Int { key }
}

struct VernacularName: Codable, Sendable {
    let vernacularName: String
    let language: String?
}
```

- [ ] **Step 6: Implement KingdomFilter**

File: `GBIFNearby/Core/Models/KingdomFilter.swift`
```swift
import Foundation

enum KingdomFilter: String, CaseIterable, Sendable, Codable {
    case all
    case animals
    case plants
    case fungi

    var taxonKey: Int? {
        switch self {
        case .all: return nil
        case .animals: return 1
        case .plants: return 6
        case .fungi: return 5
        }
    }

    var displayLabel: String {
        switch self {
        case .all: return "All"
        case .animals: return "Animals"
        case .plants: return "Plants"
        case .fungi: return "Fungi"
        }
    }

    var sfSymbol: String {
        switch self {
        case .all: return "globe.europe.africa"
        case .animals: return "pawprint.fill"
        case .plants: return "leaf.fill"
        case .fungi: return "allergens"
        }
    }
}
```

- [ ] **Step 7: Run tests**

Run:
```bash
make test
```
Expected: 3 model tests pass.

- [ ] **Step 8: Commit**

```bash
git add GBIFNearby/Core/Models GBIFNearbyTests/Fixtures GBIFNearbyTests/Core/Models project.yml
git commit -m "feat(core): add Codable DTOs and KingdomFilter"
```

---

### Task 1.5: `GBIFError` and `Loading<T>` enums

**Files:**
- Create: `GBIFNearby/Core/Networking/GBIFError.swift`
- Create: `GBIFNearby/Core/Networking/Loading.swift`

(No tests — these are trivial value types; they'll be exercised by later view-model tests.)

- [ ] **Step 1: Implement `GBIFError`**

File: `GBIFNearby/Core/Networking/GBIFError.swift`
```swift
import Foundation

enum GBIFError: Error, Sendable {
    case network(URLError)
    case http(status: Int, message: String?)
    case decoding(DecodingError)
    case cancelled

    var userMessage: String {
        switch self {
        case .network: return "No network connection."
        case .http(let status, let m): return m ?? "Server error (\(status))."
        case .decoding: return "Unexpected response from server."
        case .cancelled: return "Cancelled."
        }
    }
}
```

- [ ] **Step 2: Implement `Loading<T>`**

File: `GBIFNearby/Core/Networking/Loading.swift`
```swift
import Foundation

enum Loading<Value: Sendable>: Sendable {
    case idle
    case loading
    case loaded(Value)
    case failed(GBIFError)

    var value: Value? {
        if case .loaded(let v) = self { return v }
        return nil
    }

    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }
}
```

- [ ] **Step 3: Build**

Run:
```bash
make project && make build
```
Expected: build succeeds.

- [ ] **Step 4: Commit**

```bash
git add GBIFNearby/Core/Networking
git commit -m "feat(core): add GBIFError and Loading enums"
```

---

### Task 1.6: `OccurrenceQuery` query-string building (TDD)

**Files:**
- Create: `GBIFNearby/Core/Networking/OccurrenceQuery.swift`
- Test: `GBIFNearbyTests/Core/Networking/OccurrenceQueryTests.swift`

- [ ] **Step 1: Write the failing tests**

File: `GBIFNearbyTests/Core/Networking/OccurrenceQueryTests.swift`
```swift
import Testing
import Foundation
@testable import GBIFNearby

@Suite("OccurrenceQuery")
struct OccurrenceQueryTests {
    @Test("builds geo_distance + kingdom + facet params")
    func full() {
        var q = OccurrenceQuery()
        q.lat = 52.5200
        q.lng = 13.4050
        q.radiusKm = 5.0
        q.kingdomKey = 1
        q.facet = "speciesKey"
        q.facetLimit = 100
        q.facetMincount = 1
        q.limit = 0
        let items = q.queryItems()
        #expect(items.contains(URLQueryItem(name: "geo_distance", value: "52.5200,13.4050,5.0km")))
        #expect(items.contains(URLQueryItem(name: "kingdomKey", value: "1")))
        #expect(items.contains(URLQueryItem(name: "facet", value: "speciesKey")))
        #expect(items.contains(URLQueryItem(name: "facetLimit", value: "100")))
        #expect(items.contains(URLQueryItem(name: "facetMincount", value: "1")))
        #expect(items.contains(URLQueryItem(name: "limit", value: "0")))
    }

    @Test("omits geo_distance when lat/lng/radius missing")
    func noGeo() {
        var q = OccurrenceQuery()
        q.limit = 20
        let items = q.queryItems()
        #expect(items.contains { $0.name == "geo_distance" } == false)
    }

    @Test("includes mediaType and hasCoordinate")
    func mediaAndCoord() {
        var q = OccurrenceQuery()
        q.mediaType = "StillImage"
        q.hasCoordinate = true
        let items = q.queryItems()
        #expect(items.contains(URLQueryItem(name: "mediaType", value: "StillImage")))
        #expect(items.contains(URLQueryItem(name: "hasCoordinate", value: "true")))
    }

    @Test("includes datasetKey and speciesKey filters")
    func focusKeys() {
        var q = OccurrenceQuery()
        q.datasetKey = "abc-123"
        q.speciesKey = 42
        let items = q.queryItems()
        #expect(items.contains(URLQueryItem(name: "datasetKey", value: "abc-123")))
        #expect(items.contains(URLQueryItem(name: "speciesKey", value: "42")))
    }
}
```

- [ ] **Step 2: Regenerate and run to verify failure**

Run:
```bash
make project && make test
```
Expected: build fails — `Cannot find 'OccurrenceQuery' in scope`.

- [ ] **Step 3: Implement**

File: `GBIFNearby/Core/Networking/OccurrenceQuery.swift`
```swift
import Foundation

struct OccurrenceQuery: Sendable, Equatable {
    var lat: Double?
    var lng: Double?
    var radiusKm: Double?
    var kingdomKey: Int?
    var taxonKey: Int?
    var datasetKey: String?
    var speciesKey: Int?
    var mediaType: String?
    var hasCoordinate: Bool?
    var facet: String?
    var facetLimit: Int?
    var facetMincount: Int?
    var limit: Int?
    var offset: Int?

    func queryItems() -> [URLQueryItem] {
        var items: [URLQueryItem] = []
        if let lat, let lng, let radiusKm {
            items.append(.init(name: "geo_distance", value: GeoDistance.queryValue(lat: lat, lng: lng, radiusKm: radiusKm)))
        }
        if let kingdomKey { items.append(.init(name: "kingdomKey", value: String(kingdomKey))) }
        if let taxonKey { items.append(.init(name: "taxonKey", value: String(taxonKey))) }
        if let datasetKey { items.append(.init(name: "datasetKey", value: datasetKey)) }
        if let speciesKey { items.append(.init(name: "speciesKey", value: String(speciesKey))) }
        if let mediaType { items.append(.init(name: "mediaType", value: mediaType)) }
        if let hasCoordinate { items.append(.init(name: "hasCoordinate", value: hasCoordinate ? "true" : "false")) }
        if let facet { items.append(.init(name: "facet", value: facet)) }
        if let facetLimit { items.append(.init(name: "facetLimit", value: String(facetLimit))) }
        if let facetMincount { items.append(.init(name: "facetMincount", value: String(facetMincount))) }
        if let limit { items.append(.init(name: "limit", value: String(limit))) }
        if let offset { items.append(.init(name: "offset", value: String(offset))) }
        return items
    }
}
```

- [ ] **Step 4: Run tests**

Run:
```bash
make test
```
Expected: 4 tests pass.

- [ ] **Step 5: Commit**

```bash
git add GBIFNearby/Core/Networking/OccurrenceQuery.swift GBIFNearbyTests/Core/Networking/OccurrenceQueryTests.swift
git commit -m "feat(core): add OccurrenceQuery query-item builder"
```

---

### Task 1.7: `MockURLProtocol` test helper

**Files:**
- Create: `GBIFNearbyTests/Core/Networking/MockURLProtocol.swift`

- [ ] **Step 1: Write helper (no test for it; it's exercised by `GBIFClientTests`)**

File: `GBIFNearbyTests/Core/Networking/MockURLProtocol.swift`
```swift
import Foundation

final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    typealias Handler = @Sendable (URLRequest) throws -> (HTTPURLResponse, Data)
    nonisolated(unsafe) static var handler: Handler?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = MockURLProtocol.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.cancelled))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}

    static func makeSession() -> URLSession {
        let cfg = URLSessionConfiguration.ephemeral
        cfg.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: cfg)
    }

    static func stub(json: String, status: Int = 200) {
        handler = { req in
            let response = HTTPURLResponse(url: req.url!, statusCode: status, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
            return (response, Data(json.utf8))
        }
    }
}
```

- [ ] **Step 2: Build (no tests yet)**

Run:
```bash
make project && make build
```
Expected: build succeeds.

- [ ] **Step 3: Commit**

```bash
git add GBIFNearbyTests/Core/Networking/MockURLProtocol.swift
git commit -m "test: add MockURLProtocol helper"
```

---

### Task 1.8: `GBIFClienting` protocol + `GBIFClient` actor (TDD)

**Files:**
- Create: `GBIFNearby/Core/Networking/GBIFClienting.swift`
- Create: `GBIFNearby/Core/Networking/GBIFClient.swift`
- Test: `GBIFNearbyTests/Core/Networking/GBIFClientTests.swift`

- [ ] **Step 1: Write the failing tests**

File: `GBIFNearbyTests/Core/Networking/GBIFClientTests.swift`
```swift
import Testing
import Foundation
@testable import GBIFNearby

@Suite("GBIFClient")
struct GBIFClientTests {
    @Test("occurrenceSearch builds expected URL and decodes results")
    func search() async throws {
        MockURLProtocol.stub(json: """
        {"offset":0,"limit":2,"endOfRecords":false,"count":42,"results":[
          {"key":1,"decimalLatitude":52.5,"decimalLongitude":13.4,"scientificName":"X"},
          {"key":2,"decimalLatitude":52.6,"decimalLongitude":13.5,"scientificName":"Y"}
        ]}
        """)
        let client = GBIFClient(session: MockURLProtocol.makeSession())
        var query = OccurrenceQuery()
        query.lat = 52.5; query.lng = 13.4; query.radiusKm = 5.0
        query.limit = 2
        let page = try await client.occurrenceSearch(query)
        #expect(page.results.count == 2)
        #expect(page.results[0].key == 1)
    }

    @Test("occurrenceCount returns the count field")
    func count() async throws {
        MockURLProtocol.stub(json: """
        {"offset":0,"limit":0,"endOfRecords":true,"count":1234,"results":[]}
        """)
        let client = GBIFClient(session: MockURLProtocol.makeSession())
        var q = OccurrenceQuery()
        q.lat = 0; q.lng = 0; q.radiusKm = 1
        #expect(try await client.occurrenceCount(q) == 1234)
    }

    @Test("non-2xx HTTP throws GBIFError.http")
    func httpError() async {
        MockURLProtocol.handler = { req in
            let r = HTTPURLResponse(url: req.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (r, Data("oops".utf8))
        }
        let client = GBIFClient(session: MockURLProtocol.makeSession())
        await #expect(throws: GBIFError.self) {
            _ = try await client.occurrenceSearch(OccurrenceQuery())
        }
    }

    @Test("dataset(key:) hits /v1/dataset/{key}")
    func datasetByKey() async throws {
        MockURLProtocol.handler = { req in
            #expect(req.url!.path.hasSuffix("/dataset/abc-123"))
            let body = """
            {"key":"abc-123","title":"Sample Dataset","type":"OCCURRENCE","license":"CC0_1_0"}
            """
            let r = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (r, Data(body.utf8))
        }
        let client = GBIFClient(session: MockURLProtocol.makeSession())
        let ds = try await client.dataset(key: "abc-123")
        #expect(ds.title == "Sample Dataset")
    }
}
```

- [ ] **Step 2: Regenerate and run to verify failure**

Run:
```bash
make project && make test
```
Expected: build fails — `Cannot find 'GBIFClient' in scope`.

- [ ] **Step 3: Implement the protocol**

File: `GBIFNearby/Core/Networking/GBIFClienting.swift`
```swift
import Foundation

protocol GBIFClienting: Sendable {
    func occurrenceSearch(_ query: OccurrenceQuery) async throws -> Page<Occurrence>
    func occurrenceCount(_ query: OccurrenceQuery) async throws -> Int
    func dataset(key: String) async throws -> Dataset
    func datasetSearch(query: String?, page: Int) async throws -> Page<Dataset>
    func species(key: Int) async throws -> Species
    func vernacularNames(key: Int, language: String) async throws -> [VernacularName]
}
```

- [ ] **Step 4: Implement the actor**

File: `GBIFNearby/Core/Networking/GBIFClient.swift`
```swift
import Foundation

actor GBIFClient: GBIFClienting {
    private static let base = URL(string: "https://api.gbif.org/v1")!
    private let session: URLSession
    private let decoder: JSONDecoder

    init(session: URLSession = GBIFClient.defaultSession()) {
        self.session = session
        let d = JSONDecoder()
        // GBIF v1 returns camelCase already, so no key strategy needed.
        self.decoder = d
    }

    static func defaultSession() -> URLSession {
        let cfg = URLSessionConfiguration.default
        cfg.urlCache = URLCache(memoryCapacity: 32 * 1024 * 1024, diskCapacity: 256 * 1024 * 1024)
        cfg.requestCachePolicy = .useProtocolCachePolicy
        cfg.timeoutIntervalForRequest = 15
        let version = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "0"
        cfg.httpAdditionalHeaders = ["User-Agent": "GBIFNearby/\(version) (iOS; org.gbif.nearby)"]
        return URLSession(configuration: cfg)
    }

    // MARK: - Endpoints

    func occurrenceSearch(_ query: OccurrenceQuery) async throws -> Page<Occurrence> {
        try await get("occurrence/search", items: query.queryItems())
    }

    func occurrenceCount(_ query: OccurrenceQuery) async throws -> Int {
        var q = query
        q.limit = 0
        let page: Page<Occurrence> = try await get("occurrence/search", items: q.queryItems())
        return page.count ?? 0
    }

    func dataset(key: String) async throws -> Dataset {
        try await get("dataset/\(key)", items: [])
    }

    func datasetSearch(query: String?, page: Int) async throws -> Page<Dataset> {
        var items: [URLQueryItem] = [
            .init(name: "type", value: "OCCURRENCE"),
            .init(name: "limit", value: "20"),
            .init(name: "offset", value: String(page * 20)),
        ]
        if let q = query, q.isEmpty == false {
            items.append(.init(name: "q", value: q))
        }
        return try await get("dataset/search", items: items)
    }

    func species(key: Int) async throws -> Species {
        try await get("species/\(key)", items: [])
    }

    func vernacularNames(key: Int, language: String) async throws -> [VernacularName] {
        let page: Page<VernacularName> = try await get("species/\(key)/vernacularNames", items: [.init(name: "language", value: language)])
        return page.results
    }

    // MARK: - Plumbing

    private func get<T: Decodable & Sendable>(_ path: String, items: [URLQueryItem]) async throws -> T {
        var comps = URLComponents(url: Self.base.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        if items.isEmpty == false { comps.queryItems = items }
        var req = URLRequest(url: comps.url!)
        req.httpMethod = "GET"
        do {
            let (data, response) = try await session.data(for: req)
            guard let http = response as? HTTPURLResponse else {
                throw GBIFError.http(status: 0, message: "Non-HTTP response")
            }
            guard (200..<300).contains(http.statusCode) else {
                let msg = String(data: data, encoding: .utf8)
                throw GBIFError.http(status: http.statusCode, message: msg)
            }
            do {
                return try decoder.decode(T.self, from: data)
            } catch let e as DecodingError {
                throw GBIFError.decoding(e)
            }
        } catch let e as GBIFError {
            throw e
        } catch let e as URLError where e.code == .cancelled {
            throw GBIFError.cancelled
        } catch let e as URLError {
            throw GBIFError.network(e)
        }
    }
}
```

- [ ] **Step 5: Run tests**

Run:
```bash
make test
```
Expected: 4 `GBIFClient` tests pass.

- [ ] **Step 6: Commit**

```bash
git add GBIFNearby/Core/Networking/GBIFClienting.swift GBIFNearby/Core/Networking/GBIFClient.swift GBIFNearbyTests/Core/Networking/GBIFClientTests.swift
git commit -m "feat(core): add GBIFClient actor with occurrence/dataset/species endpoints"
```

---

### Task 1.9: `FakeGBIFClient` test helper

**Files:**
- Create: `GBIFNearbyTests/Core/Networking/FakeGBIFClient.swift`

- [ ] **Step 1: Implement the fake**

File: `GBIFNearbyTests/Core/Networking/FakeGBIFClient.swift`
```swift
import Foundation
@testable import GBIFNearby

actor FakeGBIFClient: GBIFClienting {
    var recordedSearches: [OccurrenceQuery] = []
    var recordedCounts: [OccurrenceQuery] = []
    var recordedDatasetSearches: [(query: String?, page: Int)] = []
    var recordedDatasetKeys: [String] = []
    var recordedSpeciesKeys: [Int] = []
    var recordedVernacularRequests: [(key: Int, lang: String)] = []

    var searchHandler: (@Sendable (OccurrenceQuery) async throws -> Page<Occurrence>)?
    var countHandler: (@Sendable (OccurrenceQuery) async throws -> Int)?
    var datasetHandler: (@Sendable (String) async throws -> Dataset)?
    var datasetSearchHandler: (@Sendable (String?, Int) async throws -> Page<Dataset>)?
    var speciesHandler: (@Sendable (Int) async throws -> Species)?
    var vernacularHandler: (@Sendable (Int, String) async throws -> [VernacularName])?

    func setSearch(_ h: @escaping @Sendable (OccurrenceQuery) async throws -> Page<Occurrence>) { searchHandler = h }
    func setCount(_ h: @escaping @Sendable (OccurrenceQuery) async throws -> Int) { countHandler = h }
    func setDataset(_ h: @escaping @Sendable (String) async throws -> Dataset) { datasetHandler = h }
    func setDatasetSearch(_ h: @escaping @Sendable (String?, Int) async throws -> Page<Dataset>) { datasetSearchHandler = h }
    func setSpecies(_ h: @escaping @Sendable (Int) async throws -> Species) { speciesHandler = h }
    func setVernacular(_ h: @escaping @Sendable (Int, String) async throws -> [VernacularName]) { vernacularHandler = h }

    func occurrenceSearch(_ query: OccurrenceQuery) async throws -> Page<Occurrence> {
        recordedSearches.append(query)
        return try await (searchHandler ?? { _ in Page(offset: 0, limit: 0, endOfRecords: true, count: 0, results: [], facets: nil) })(query)
    }
    func occurrenceCount(_ query: OccurrenceQuery) async throws -> Int {
        recordedCounts.append(query)
        return try await (countHandler ?? { _ in 0 })(query)
    }
    func dataset(key: String) async throws -> Dataset {
        recordedDatasetKeys.append(key)
        guard let h = datasetHandler else { throw GBIFError.cancelled }
        return try await h(key)
    }
    func datasetSearch(query: String?, page: Int) async throws -> Page<Dataset> {
        recordedDatasetSearches.append((query, page))
        return try await (datasetSearchHandler ?? { _, _ in Page(offset: 0, limit: 0, endOfRecords: true, count: 0, results: [], facets: nil) })(query, page)
    }
    func species(key: Int) async throws -> Species {
        recordedSpeciesKeys.append(key)
        guard let h = speciesHandler else { throw GBIFError.cancelled }
        return try await h(key)
    }
    func vernacularNames(key: Int, language: String) async throws -> [VernacularName] {
        recordedVernacularRequests.append((key, language))
        return try await (vernacularHandler ?? { _, _ in [] })(key, language)
    }
}
```

- [ ] **Step 2: Build**

Run:
```bash
make project && make build
```
Expected: build succeeds.

- [ ] **Step 3: Commit**

```bash
git add GBIFNearbyTests/Core/Networking/FakeGBIFClient.swift
git commit -m "test: add FakeGBIFClient for view-model tests"
```

---

### Task 1.10: `LocationStore`

**Files:**
- Create: `GBIFNearby/Core/Location/LocationStore.swift`

(No unit test — `CLLocationManager` is hard to test in isolation. Validated manually on the simulator.)

- [ ] **Step 1: Implement**

File: `GBIFNearby/Core/Location/LocationStore.swift`
```swift
import Foundation
import CoreLocation
import Observation

@MainActor
@Observable
final class LocationStore: NSObject {
    enum Source { case device, manual }
    var current: CLLocationCoordinate2D?
    var source: Source = .device
    var authStatus: CLAuthorizationStatus = .notDetermined
    var lastError: Error?

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        authStatus = manager.authorizationStatus
    }

    func requestAuthorization() {
        manager.requestWhenInUseAuthorization()
    }

    func startUpdating() {
        manager.startUpdatingLocation()
    }

    func setManual(_ coord: CLLocationCoordinate2D) {
        source = .manual
        current = coord
        manager.stopUpdatingLocation()
    }

    func clearManual() {
        source = .device
        startUpdating()
    }
}

extension LocationStore: @preconcurrency CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authStatus = manager.authorizationStatus
        if authStatus == .authorizedWhenInUse || authStatus == .authorizedAlways {
            startUpdating()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard source == .device, let loc = locations.last else { return }
        current = loc.coordinate
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        lastError = error
    }
}
```

- [ ] **Step 2: Build**

Run:
```bash
make project && make build
```
Expected: build succeeds.

- [ ] **Step 3: Commit**

```bash
git add GBIFNearby/Core/Location/LocationStore.swift
git commit -m "feat(core): add LocationStore wrapping CLLocationManager"
```

---

### Task 1.11: `RadiusStore` with `@AppStorage` persistence (TDD for the persistence path)

**Files:**
- Create: `GBIFNearby/Core/Radius/RadiusStore.swift`
- Test: `GBIFNearbyTests/Core/Stores/RadiusStoreTests.swift`

- [ ] **Step 1: Write the failing tests**

File: `GBIFNearbyTests/Core/Stores/RadiusStoreTests.swift`
```swift
import Testing
import Foundation
@testable import GBIFNearby

@MainActor
@Suite("RadiusStore")
struct RadiusStoreTests {
    private func make() -> (RadiusStore, UserDefaults) {
        let suite = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        return (RadiusStore(defaults: suite), suite)
    }

    @Test("default is 5 km")
    func defaultValue() {
        let (store, _) = make()
        #expect(store.radiusKm == 5.0)
    }

    @Test("clamps to 0.1...100")
    func clamps() {
        let (store, _) = make()
        store.radiusKm = 0.01
        #expect(store.radiusKm == 0.1)
        store.radiusKm = 250
        #expect(store.radiusKm == 100)
    }

    @Test("persists to UserDefaults")
    func persists() {
        let (store, defaults) = make()
        store.radiusKm = 12.3
        #expect(defaults.double(forKey: "radiusKm") == 12.3)
    }

    @Test("reads existing value")
    func reads() {
        let suite = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        suite.set(42.0, forKey: "radiusKm")
        let store = RadiusStore(defaults: suite)
        #expect(store.radiusKm == 42.0)
    }
}
```

- [ ] **Step 2: Regenerate and run to verify failure**

Run:
```bash
make project && make test
```
Expected: build fails — `Cannot find 'RadiusStore' in scope`.

- [ ] **Step 3: Implement**

File: `GBIFNearby/Core/Radius/RadiusStore.swift`
```swift
import Foundation
import Observation

@MainActor
@Observable
final class RadiusStore {
    static let key = "radiusKm"
    static let minValue: Double = 0.1
    static let maxValue: Double = 100.0
    static let defaultValue: Double = 5.0

    private let defaults: UserDefaults

    var radiusKm: Double {
        didSet {
            let clamped = min(max(radiusKm, Self.minValue), Self.maxValue)
            if clamped != radiusKm {
                radiusKm = clamped
                return
            }
            defaults.set(radiusKm, forKey: Self.key)
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let stored = defaults.double(forKey: Self.key)
        self.radiusKm = stored == 0 ? Self.defaultValue : stored
    }
}
```

- [ ] **Step 4: Run tests**

Run:
```bash
make test
```
Expected: 4 tests pass.

- [ ] **Step 5: Commit**

```bash
git add GBIFNearby/Core/Radius/RadiusStore.swift GBIFNearbyTests/Core/Stores/RadiusStoreTests.swift
git commit -m "feat(core): add RadiusStore"
```

---

### Task 1.12: `TaxonFilterStore` (TDD)

**Files:**
- Create: `GBIFNearby/Core/TaxonFilter/TaxonFilterStore.swift`
- Test: `GBIFNearbyTests/Core/Stores/TaxonFilterStoreTests.swift`

- [ ] **Step 1: Write the failing tests**

File: `GBIFNearbyTests/Core/Stores/TaxonFilterStoreTests.swift`
```swift
import Testing
import Foundation
@testable import GBIFNearby

@MainActor
@Suite("TaxonFilterStore")
struct TaxonFilterStoreTests {
    private func make() -> (TaxonFilterStore, UserDefaults) {
        let suite = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        return (TaxonFilterStore(defaults: suite), suite)
    }

    @Test("default is .all")
    func defaultValue() {
        let (store, _) = make()
        #expect(store.selected == .all)
    }

    @Test("persists selection")
    func persists() {
        let (store, defaults) = make()
        store.selected = .plants
        #expect(defaults.string(forKey: "kingdomFilter") == "plants")
    }

    @Test("restores selection")
    func restores() {
        let suite = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        suite.set("fungi", forKey: "kingdomFilter")
        let store = TaxonFilterStore(defaults: suite)
        #expect(store.selected == .fungi)
    }
}
```

- [ ] **Step 2: Regenerate and run to verify failure**

Run:
```bash
make project && make test
```
Expected: build fails — `Cannot find 'TaxonFilterStore' in scope`.

- [ ] **Step 3: Implement**

File: `GBIFNearby/Core/TaxonFilter/TaxonFilterStore.swift`
```swift
import Foundation
import Observation

@MainActor
@Observable
final class TaxonFilterStore {
    static let key = "kingdomFilter"
    private let defaults: UserDefaults

    var selected: KingdomFilter {
        didSet { defaults.set(selected.rawValue, forKey: Self.key) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let raw = defaults.string(forKey: Self.key), let value = KingdomFilter(rawValue: raw) {
            self.selected = value
        } else {
            self.selected = .all
        }
    }
}
```

- [ ] **Step 4: Run tests**

Run:
```bash
make test
```
Expected: 3 tests pass.

- [ ] **Step 5: Commit**

```bash
git add GBIFNearby/Core/TaxonFilter/TaxonFilterStore.swift GBIFNearbyTests/Core/Stores/TaxonFilterStoreTests.swift
git commit -m "feat(core): add TaxonFilterStore"
```

---

### Task 1.13: `FocusFilterStore` (TDD)

**Files:**
- Create: `GBIFNearby/Core/FocusFilter/FocusFilterStore.swift`
- Test: `GBIFNearbyTests/Core/Stores/FocusFilterStoreTests.swift`

- [ ] **Step 1: Write the failing tests**

File: `GBIFNearbyTests/Core/Stores/FocusFilterStoreTests.swift`
```swift
import Testing
@testable import GBIFNearby

@MainActor
@Suite("FocusFilterStore")
struct FocusFilterStoreTests {
    @Test("starts empty")
    func empty() {
        let store = FocusFilterStore()
        #expect(store.datasetKey == nil)
        #expect(store.speciesKey == nil)
        #expect(store.isActive == false)
    }

    @Test("setting datasetKey activates filter")
    func dataset() {
        let store = FocusFilterStore()
        store.set(datasetKey: "abc-123", label: "Sample Dataset")
        #expect(store.datasetKey == "abc-123")
        #expect(store.label == "Sample Dataset")
        #expect(store.isActive == true)
    }

    @Test("clear resets everything")
    func clear() {
        let store = FocusFilterStore()
        store.set(speciesKey: 7, label: "Some species")
        store.clear()
        #expect(store.datasetKey == nil)
        #expect(store.speciesKey == nil)
        #expect(store.label == nil)
        #expect(store.isActive == false)
    }
}
```

- [ ] **Step 2: Regenerate and run to verify failure**

Run:
```bash
make project && make test
```
Expected: build fails — `Cannot find 'FocusFilterStore' in scope`.

- [ ] **Step 3: Implement**

File: `GBIFNearby/Core/FocusFilter/FocusFilterStore.swift`
```swift
import Foundation
import Observation

@MainActor
@Observable
final class FocusFilterStore {
    var datasetKey: String?
    var speciesKey: Int?
    var label: String?

    var isActive: Bool { datasetKey != nil || speciesKey != nil }

    func set(datasetKey: String, label: String) {
        self.datasetKey = datasetKey
        self.speciesKey = nil
        self.label = label
    }

    func set(speciesKey: Int, label: String) {
        self.speciesKey = speciesKey
        self.datasetKey = nil
        self.label = label
    }

    func clear() {
        datasetKey = nil
        speciesKey = nil
        label = nil
    }
}
```

- [ ] **Step 4: Run tests**

Run:
```bash
make test
```
Expected: 3 tests pass.

- [ ] **Step 5: Commit**

```bash
git add GBIFNearby/Core/FocusFilter/FocusFilterStore.swift GBIFNearbyTests/Core/Stores/FocusFilterStoreTests.swift
git commit -m "feat(core): add FocusFilterStore"
```

---

### Task 1.14: `RadiusHeader` view

**Files:**
- Create: `GBIFNearby/Core/UI/RadiusHeader.swift`

(Visual; validated via SwiftUI preview + manual run.)

- [ ] **Step 1: Implement**

File: `GBIFNearby/Core/UI/RadiusHeader.swift`
```swift
import SwiftUI

struct RadiusHeader: View {
    @Environment(RadiusStore.self) private var radiusStore
    @Environment(TaxonFilterStore.self) private var taxonStore

    var body: some View {
        @Bindable var radiusStore = radiusStore
        @Bindable var taxonStore = taxonStore
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Text("Radius").font(.caption).foregroundStyle(.secondary)
                Slider(value: $radiusStore.radiusKm, in: RadiusStore.minValue...RadiusStore.maxValue)
                Text(formatted(radiusStore.radiusKm))
                    .font(.caption.monospacedDigit())
                    .frame(width: 64, alignment: .trailing)
            }
            HStack(spacing: 8) {
                ForEach(KingdomFilter.allCases, id: \.self) { k in
                    Button {
                        taxonStore.selected = k
                    } label: {
                        Label(k.displayLabel, systemImage: k.sfSymbol)
                            .labelStyle(.iconOnly)
                            .font(.title3)
                            .padding(8)
                            .frame(minWidth: 44, minHeight: 32)
                            .background(taxonStore.selected == k ? Color.accentColor.opacity(0.2) : Color(.secondarySystemBackground), in: Capsule())
                            .overlay(Capsule().stroke(taxonStore.selected == k ? Color.accentColor : .clear, lineWidth: 1.5))
                    }
                    .accessibilityLabel(k.displayLabel)
                    .buttonStyle(.plain)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.bar)
    }

    private func formatted(_ km: Double) -> String {
        String(format: "%.1f km", km)
    }
}

#Preview {
    RadiusHeader()
        .environment(RadiusStore())
        .environment(TaxonFilterStore())
}
```

- [ ] **Step 2: Build**

Run:
```bash
make project && make build
```
Expected: build succeeds.

- [ ] **Step 3: Commit**

```bash
git add GBIFNearby/Core/UI/RadiusHeader.swift
git commit -m "feat(core): add persistent RadiusHeader view"
```

---

### Task 1.15: `ErrorBanner` and `FocusFilterChip` views

**Files:**
- Create: `GBIFNearby/Core/UI/ErrorBanner.swift`
- Create: `GBIFNearby/Core/UI/FocusFilterChip.swift`

- [ ] **Step 1: Implement `ErrorBanner`**

File: `GBIFNearby/Core/UI/ErrorBanner.swift`
```swift
import SwiftUI

struct ErrorBanner: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.yellow)
            Text(message).font(.footnote)
            Spacer(minLength: 0)
            Button("Retry", action: onRetry).font(.footnote.bold())
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 16)
    }
}

#Preview {
    ErrorBanner(message: "No network connection.") {}
}
```

- [ ] **Step 2: Implement `FocusFilterChip`**

File: `GBIFNearby/Core/UI/FocusFilterChip.swift`
```swift
import SwiftUI

struct FocusFilterChip: View {
    @Environment(FocusFilterStore.self) private var focus

    var body: some View {
        if focus.isActive, let label = focus.label {
            HStack(spacing: 6) {
                Text("Filter:").font(.caption).foregroundStyle(.secondary)
                Text(label).font(.caption).lineLimit(1)
                Button {
                    focus.clear()
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(Color(.secondarySystemBackground), in: Capsule())
            .padding(.horizontal, 16).padding(.vertical, 4)
        }
    }
}

#Preview {
    let store = FocusFilterStore()
    store.set(datasetKey: "abc", label: "iNaturalist Research-grade")
    return FocusFilterChip().environment(store)
}
```

- [ ] **Step 3: Build**

Run:
```bash
make project && make build
```
Expected: build succeeds.

- [ ] **Step 4: Commit**

```bash
git add GBIFNearby/Core/UI/ErrorBanner.swift GBIFNearby/Core/UI/FocusFilterChip.swift
git commit -m "feat(core): add ErrorBanner and FocusFilterChip views"
```

---

### Task 1.16: Wire stores into the app + verify header renders

**Files:**
- Create: `GBIFNearby/App/AppEnvironment.swift`
- Modify: `GBIFNearby/App/GBIFNearbyApp.swift`
- Modify: `GBIFNearby/App/RootTabView.swift`

- [ ] **Step 1: Create `AppEnvironment`**

File: `GBIFNearby/App/AppEnvironment.swift`
```swift
import SwiftUI

@MainActor
struct AppEnvironment {
    let locationStore: LocationStore
    let radiusStore: RadiusStore
    let taxonStore: TaxonFilterStore
    let focusStore: FocusFilterStore
    let client: any GBIFClienting

    static func production() -> AppEnvironment {
        AppEnvironment(
            locationStore: LocationStore(),
            radiusStore: RadiusStore(),
            taxonStore: TaxonFilterStore(),
            focusStore: FocusFilterStore(),
            client: GBIFClient()
        )
    }
}
```

- [ ] **Step 2: Wire it into `GBIFNearbyApp`**

Replace `GBIFNearby/App/GBIFNearbyApp.swift` with:
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

- [ ] **Step 3: Show the header on every tab (placeholders for now)**

Replace `GBIFNearby/App/RootTabView.swift` with:
```swift
import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            placeholder("Map (next task)")
                .tabItem { Label("Map", systemImage: "map") }
            placeholder("Species")
                .tabItem { Label("Species", systemImage: "leaf") }
            placeholder("Gallery")
                .tabItem { Label("Gallery", systemImage: "photo.on.rectangle") }
            placeholder("Datasets")
                .tabItem { Label("Datasets", systemImage: "tray.full") }
            placeholder("About")
                .tabItem { Label("About", systemImage: "info.circle") }
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
}
```

- [ ] **Step 4: Build and run on simulator**

Run:
```bash
make build
xcrun simctl boot 'iPhone 15' 2>/dev/null || true
open -a Simulator
xcrun simctl install booted "$(make -s app-path)"
xcrun simctl launch booted org.gbif.nearby
```
Expected: app launches; tab bar with 5 tabs; persistent header with slider + 4 chips visible on each tab.

- [ ] **Step 5: Commit**

```bash
git add GBIFNearby/App
git commit -m "feat(app): inject shared stores and render persistent header on every tab"
```

---

## Phase 2 — Map tab

### Task 2.1: `GBIFDensityTileOverlay` — URL template (TDD)

**Files:**
- Create: `GBIFNearby/Features/Map/GBIFDensityTileOverlay.swift`
- Test: `GBIFNearbyTests/Features/Map/GBIFDensityTileOverlayTests.swift`

- [ ] **Step 1: Write the failing tests**

File: `GBIFNearbyTests/Features/Map/GBIFDensityTileOverlayTests.swift`
```swift
import Testing
import Foundation
import MapKit
@testable import GBIFNearby

@Suite("GBIFDensityTileOverlay")
struct GBIFDensityTileOverlayTests {
    @Test("base URL when no filters")
    func base() {
        let overlay = GBIFDensityTileOverlay(taxonKey: nil, datasetKey: nil)
        let url = overlay.url(forTilePath: .init(x: 1, y: 2, z: 3, contentScaleFactor: 1))
        let str = url.absoluteString
        #expect(str.contains("/v2/map/occurrence/density/3/1/2@1x.png"))
        #expect(str.contains("srs=EPSG:3857"))
        #expect(str.contains("style=classic.poly"))
        #expect(str.contains("bin=hex"))
        #expect(str.contains("hexPerTile=75"))
        #expect(str.contains("taxonKey=") == false)
        #expect(str.contains("datasetKey=") == false)
    }

    @Test("appends taxonKey when set")
    func taxonKey() {
        let overlay = GBIFDensityTileOverlay(taxonKey: 6, datasetKey: nil)
        let url = overlay.url(forTilePath: .init(x: 0, y: 0, z: 0, contentScaleFactor: 1))
        #expect(url.absoluteString.contains("taxonKey=6"))
    }

    @Test("appends datasetKey when set")
    func datasetKey() {
        let overlay = GBIFDensityTileOverlay(taxonKey: nil, datasetKey: "abc-123")
        let url = overlay.url(forTilePath: .init(x: 0, y: 0, z: 0, contentScaleFactor: 1))
        #expect(url.absoluteString.contains("datasetKey=abc-123"))
    }
}
```

- [ ] **Step 2: Regenerate and run to verify failure**

Run:
```bash
make project && make test
```
Expected: build fails — `Cannot find 'GBIFDensityTileOverlay' in scope`.

- [ ] **Step 3: Implement**

File: `GBIFNearby/Features/Map/GBIFDensityTileOverlay.swift`
```swift
import Foundation
import MapKit

final class GBIFDensityTileOverlay: MKTileOverlay {
    let taxonKey: Int?
    let datasetKey: String?
    let speciesKey: Int?

    init(taxonKey: Int?, datasetKey: String?, speciesKey: Int? = nil) {
        self.taxonKey = taxonKey
        self.datasetKey = datasetKey
        self.speciesKey = speciesKey
        super.init(urlTemplate: nil)
        self.canReplaceMapContent = false
        self.tileSize = CGSize(width: 256, height: 256)
        self.minimumZ = 0
        self.maximumZ = 18
    }

    override func url(forTilePath path: MKTileOverlayPath) -> URL {
        var comps = URLComponents(string: "https://api.gbif.org/v2/map/occurrence/density/\(path.z)/\(path.x)/\(path.y)@1x.png")!
        var items: [URLQueryItem] = [
            .init(name: "srs", value: "EPSG:3857"),
            .init(name: "style", value: "classic.poly"),
            .init(name: "bin", value: "hex"),
            .init(name: "hexPerTile", value: "75"),
        ]
        if let taxonKey { items.append(.init(name: "taxonKey", value: String(taxonKey))) }
        if let datasetKey { items.append(.init(name: "datasetKey", value: datasetKey)) }
        if let speciesKey { items.append(.init(name: "speciesKey", value: String(speciesKey))) }
        comps.queryItems = items
        return comps.url!
    }
}
```

- [ ] **Step 4: Run tests**

Run:
```bash
make test
```
Expected: 3 tests pass.

- [ ] **Step 5: Commit**

```bash
git add GBIFNearby/Features/Map/GBIFDensityTileOverlay.swift GBIFNearbyTests/Features/Map/GBIFDensityTileOverlayTests.swift
git commit -m "feat(map): add GBIFDensityTileOverlay"
```

---

### Task 2.2: `MapViewModel` — pin fetching (TDD)

**Files:**
- Create: `GBIFNearby/Features/Map/MapViewModel.swift`
- Test: `GBIFNearbyTests/Features/Map/MapViewModelTests.swift`

- [ ] **Step 1: Write the failing tests**

File: `GBIFNearbyTests/Features/Map/MapViewModelTests.swift`
```swift
import Testing
import Foundation
import CoreLocation
@testable import GBIFNearby

@MainActor
@Suite("MapViewModel")
struct MapViewModelTests {
    @Test("fetchPins forwards geo_distance and kingdom + decodes pins")
    func fetchPins() async {
        let fake = FakeGBIFClient()
        await fake.setSearch { q in
            #expect(q.lat == 52.5)
            #expect(q.lng == 13.4)
            #expect(q.radiusKm == 5.0)
            #expect(q.kingdomKey == 6)
            #expect(q.hasCoordinate == true)
            #expect(q.limit == 300)
            return Page(offset: 0, limit: 300, endOfRecords: true, count: 1,
                        results: [Occurrence(key: 99, datasetKey: nil, speciesKey: 7, species: "Bellis perennis",
                                             scientificName: "Bellis perennis", acceptedScientificName: nil,
                                             kingdom: "Plantae", phylum: nil, class: nil, order: nil, family: nil, genus: nil,
                                             decimalLatitude: 52.5001, decimalLongitude: 13.4001,
                                             eventDate: nil, recordedBy: nil, basisOfRecord: nil, media: nil)],
                        facets: nil)
        }
        let vm = MapViewModel(client: fake)
        await vm.fetchPins(at: CLLocationCoordinate2D(latitude: 52.5, longitude: 13.4),
                           radiusKm: 5.0, kingdomKey: 6, datasetKey: nil, speciesKey: nil)
        switch vm.pins {
        case .loaded(let arr): #expect(arr.count == 1); #expect(arr[0].key == 99)
        default: Issue.record("expected loaded state, got \(vm.pins)")
        }
        #expect(await fake.recordedSearches.count == 1)
    }

    @Test("on error sets failed state")
    func error() async {
        let fake = FakeGBIFClient()
        await fake.setSearch { _ in throw GBIFError.http(status: 503, message: nil) }
        let vm = MapViewModel(client: fake)
        await vm.fetchPins(at: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                           radiusKm: 1.0, kingdomKey: nil, datasetKey: nil, speciesKey: nil)
        if case .failed = vm.pins {} else {
            Issue.record("expected failed state")
        }
    }

    @Test("clearPins resets to idle")
    func clearPins() async {
        let vm = MapViewModel(client: FakeGBIFClient())
        vm.clearPins()
        if case .idle = vm.pins {} else {
            Issue.record("expected idle")
        }
    }
}
```

- [ ] **Step 2: Regenerate and run to verify failure**

Run:
```bash
make project && make test
```
Expected: build fails — `Cannot find 'MapViewModel' in scope`.

- [ ] **Step 3: Implement**

File: `GBIFNearby/Features/Map/MapViewModel.swift`
```swift
import Foundation
import CoreLocation
import Observation

@MainActor
@Observable
final class MapViewModel {
    private let client: any GBIFClienting
    private var task: Task<Void, Never>?

    var pins: Loading<[Occurrence]> = .idle

    init(client: any GBIFClienting) {
        self.client = client
    }

    func fetchPins(at coord: CLLocationCoordinate2D, radiusKm: Double,
                   kingdomKey: Int?, datasetKey: String?, speciesKey: Int?) async {
        task?.cancel()
        pins = .loading
        var q = OccurrenceQuery()
        q.lat = coord.latitude
        q.lng = coord.longitude
        q.radiusKm = radiusKm
        q.kingdomKey = kingdomKey
        q.datasetKey = datasetKey
        q.speciesKey = speciesKey
        q.hasCoordinate = true
        q.limit = 300
        let task = Task { [client] in
            do {
                let page = try await client.occurrenceSearch(q)
                if Task.isCancelled { return }
                self.pins = .loaded(page.results.filter { $0.decimalLatitude != nil && $0.decimalLongitude != nil })
            } catch let error as GBIFError {
                if Task.isCancelled { return }
                self.pins = .failed(error)
            } catch {
                self.pins = .failed(.network(URLError(.unknown)))
            }
        }
        self.task = task
        await task.value
    }

    func clearPins() {
        task?.cancel()
        pins = .idle
    }
}
```

- [ ] **Step 4: Run tests**

Run:
```bash
make test
```
Expected: 3 tests pass.

- [ ] **Step 5: Commit**

```bash
git add GBIFNearby/Features/Map/MapViewModel.swift GBIFNearbyTests/Features/Map/MapViewModelTests.swift
git commit -m "feat(map): add MapViewModel with pin fetching"
```

---

### Task 2.3: `GBIFMapView` — UIViewRepresentable with region + circle + density overlay

**Files:**
- Create: `GBIFNearby/Features/Map/GBIFMapView.swift`

(No automated test — UIKit map view; validated manually.)

- [ ] **Step 1: Implement**

File: `GBIFNearby/Features/Map/GBIFMapView.swift`
```swift
import SwiftUI
import MapKit

struct GBIFMapView: UIViewRepresentable {
    var center: CLLocationCoordinate2D
    var radiusKm: Double
    var taxonKey: Int?
    var datasetKey: String?
    var speciesKey: Int?
    var pins: [Occurrence]
    var onPinTap: (Occurrence) -> Void
    var onLongPress: ((CLLocationCoordinate2D) -> Void)?
    var onRegionChange: ((MKCoordinateRegion) -> Void)?

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.showsUserLocation = true
        map.pointOfInterestFilter = .excludingAll
        let lp = UILongPressGestureRecognizer(target: context.coordinator,
                                              action: #selector(Coordinator.longPress(_:)))
        lp.minimumPressDuration = 0.6
        map.addGestureRecognizer(lp)
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.applyRegion(map)
        context.coordinator.applyCircle(map)
        context.coordinator.applyTileOverlay(map)
        context.coordinator.applyPins(map)
    }

    @MainActor
    final class Coordinator: NSObject, MKMapViewDelegate {
        var parent: GBIFMapView
        private var currentOverlayKey: String?
        private var currentCenter: CLLocationCoordinate2D?
        private var currentRadius: Double?

        init(_ parent: GBIFMapView) {
            self.parent = parent
        }

        func applyRegion(_ map: MKMapView) {
            // Recenter when center coord meaningfully changes.
            let c = parent.center
            if currentCenter == nil || !same(currentCenter!, c) || currentRadius != parent.radiusKm {
                let span = max(parent.radiusKm, 0.5) * 3000 // meters, ~3x diameter
                let region = MKCoordinateRegion(center: c, latitudinalMeters: span, longitudinalMeters: span)
                map.setRegion(region, animated: currentCenter != nil)
                currentCenter = c
                currentRadius = parent.radiusKm
            }
        }

        func applyCircle(_ map: MKMapView) {
            map.overlays
                .compactMap { $0 as? MKCircle }
                .forEach(map.removeOverlay)
            let circle = MKCircle(center: parent.center, radius: parent.radiusKm * 1000)
            map.addOverlay(circle, level: .aboveRoads)
        }

        func applyTileOverlay(_ map: MKMapView) {
            let key = "tax=\(parent.taxonKey?.description ?? "-")|ds=\(parent.datasetKey ?? "-")|sp=\(parent.speciesKey?.description ?? "-")"
            guard key != currentOverlayKey else { return }
            map.overlays
                .compactMap { $0 as? GBIFDensityTileOverlay }
                .forEach(map.removeOverlay)
            let overlay = GBIFDensityTileOverlay(taxonKey: parent.taxonKey,
                                                 datasetKey: parent.datasetKey,
                                                 speciesKey: parent.speciesKey)
            map.addOverlay(overlay, level: .aboveLabels)
            currentOverlayKey = key
        }

        func applyPins(_ map: MKMapView) {
            let existing = map.annotations.compactMap { $0 as? OccurrencePin }
            map.removeAnnotations(existing)
            let pins = parent.pins.compactMap { occ -> OccurrencePin? in
                guard let lat = occ.decimalLatitude, let lng = occ.decimalLongitude else { return nil }
                return OccurrencePin(occurrence: occ, coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng))
            }
            map.addAnnotations(pins)
        }

        @objc func longPress(_ gr: UILongPressGestureRecognizer) {
            guard gr.state == .began, let map = gr.view as? MKMapView else { return }
            let pt = gr.location(in: map)
            let coord = map.convert(pt, toCoordinateFrom: map)
            parent.onLongPress?(coord)
        }

        // MARK: Delegate

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let circle = overlay as? MKCircle {
                let r = MKCircleRenderer(circle: circle)
                r.fillColor = UIColor.systemGreen.withAlphaComponent(0.10)
                r.strokeColor = UIColor.systemGreen.withAlphaComponent(0.7)
                r.lineWidth = 1
                return r
            }
            if let tile = overlay as? MKTileOverlay {
                return MKTileOverlayRenderer(tileOverlay: tile)
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation { return nil }
            guard let pin = annotation as? OccurrencePin else { return nil }
            let id = "occurrence"
            let v = (mapView.dequeueReusableAnnotationView(withIdentifier: id) as? MKMarkerAnnotationView)
                ?? MKMarkerAnnotationView(annotation: pin, reuseIdentifier: id)
            v.annotation = pin
            v.clusteringIdentifier = "occ"
            v.markerTintColor = .systemGreen
            v.canShowCallout = false
            return v
        }

        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            guard let pin = view.annotation as? OccurrencePin else { return }
            parent.onPinTap(pin.occurrence)
            mapView.deselectAnnotation(view.annotation, animated: false)
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            parent.onRegionChange?(mapView.region)
        }

        private func same(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Bool {
            abs(a.latitude - b.latitude) < 1e-5 && abs(a.longitude - b.longitude) < 1e-5
        }
    }
}

final class OccurrencePin: NSObject, MKAnnotation {
    let occurrence: Occurrence
    let coordinate: CLLocationCoordinate2D
    var title: String? { occurrence.scientificName ?? occurrence.species }
    init(occurrence: Occurrence, coordinate: CLLocationCoordinate2D) {
        self.occurrence = occurrence
        self.coordinate = coordinate
    }
}
```

- [ ] **Step 2: Build**

Run:
```bash
make project && make build
```
Expected: build succeeds.

- [ ] **Step 3: Commit**

```bash
git add GBIFNearby/Features/Map/GBIFMapView.swift
git commit -m "feat(map): add GBIFMapView UIViewRepresentable with circle + density tiles + pins"
```

---

### Task 2.4: `OccurrenceSheet` — pin-tap modal

**Files:**
- Create: `GBIFNearby/Features/Map/OccurrenceSheet.swift`

- [ ] **Step 1: Implement**

File: `GBIFNearby/Features/Map/OccurrenceSheet.swift`
```swift
import SwiftUI
import SafariServices

struct OccurrenceSheet: View {
    let occurrence: Occurrence
    @State private var showSafari = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if let name = occurrence.scientificName ?? occurrence.species {
                        Text(name).font(.title3.italic())
                    }
                    if let kingdom = occurrence.kingdom { row("Kingdom", kingdom) }
                    if let family = occurrence.family { row("Family", family) }
                    if let date = occurrence.eventDate { row("Date", date) }
                    if let recorder = occurrence.recordedBy { row("Recorded by", recorder) }
                    if let basis = occurrence.basisOfRecord { row("Basis", basis) }
                }
                Section {
                    Button("View on GBIF.org") { showSafari = true }
                }
            }
            .navigationTitle("Occurrence #\(occurrence.key)")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showSafari) {
                SafariView(url: URL(string: "https://www.gbif.org/occurrence/\(occurrence.key)")!)
                    .ignoresSafeArea()
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).multilineTextAlignment(.trailing)
        }
    }
}

struct SafariView: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }
    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}
```

- [ ] **Step 2: Build**

Run:
```bash
make project && make build
```
Expected: build succeeds.

- [ ] **Step 3: Commit**

```bash
git add GBIFNearby/Features/Map/OccurrenceSheet.swift
git commit -m "feat(map): add OccurrenceSheet pin-tap modal"
```

---

### Task 2.5: `MapTabView` — wire everything together

**Files:**
- Create: `GBIFNearby/Features/Map/MapTabView.swift`
- Modify: `GBIFNearby/App/RootTabView.swift`

- [ ] **Step 1: Implement `MapTabView`**

File: `GBIFNearby/Features/Map/MapTabView.swift`
```swift
import SwiftUI
import CoreLocation
import MapKit

struct MapTabView: View {
    @Environment(LocationStore.self) private var location
    @Environment(RadiusStore.self) private var radius
    @Environment(TaxonFilterStore.self) private var taxon
    @Environment(FocusFilterStore.self) private var focus
    @Environment(\.gbifClient) private var client

    @State private var viewModel: MapViewModel?
    @State private var selectedOccurrence: Occurrence?
    @State private var pinDebouncer = AsyncDebouncer(delay: .milliseconds(400))
    @State private var lastRegion: MKCoordinateRegion?
    @State private var pinFetchEnabled = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                map
                VStack(spacing: 0) {
                    RadiusHeader()
                    FocusFilterChip()
                    if case .failed(let err) = viewModel?.pins ?? .idle {
                        ErrorBanner(message: err.userMessage) {
                            Task { await fetchIfReady() }
                        }
                    }
                }
            }
            .sheet(item: $selectedOccurrence) { occ in
                OccurrenceSheet(occurrence: occ)
            }
            .task { ensureViewModel() }
            .onChange(of: radius.radiusKm) { _, _ in scheduleFetch() }
            .onChange(of: taxon.selected) { _, _ in scheduleFetch() }
            .onChange(of: focus.datasetKey) { _, _ in scheduleFetch() }
            .onChange(of: focus.speciesKey) { _, _ in scheduleFetch() }
            .onChange(of: location.current?.latitude) { _, _ in scheduleFetch() }
            .onChange(of: location.current?.longitude) { _, _ in scheduleFetch() }
            .navigationTitle("Map")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    @ViewBuilder
    private var map: some View {
        if let center = location.current {
            GBIFMapView(
                center: center,
                radiusKm: radius.radiusKm,
                taxonKey: taxon.selected.taxonKey,
                datasetKey: focus.datasetKey,
                speciesKey: focus.speciesKey,
                pins: viewModel?.pins.value ?? [],
                onPinTap: { selectedOccurrence = $0 },
                onLongPress: { coord in location.setManual(coord) },
                onRegionChange: { region in
                    lastRegion = region
                    pinFetchEnabled = region.span.latitudeDelta < 0.5 // ~55 km diag
                    scheduleFetch()
                }
            )
        } else {
            LocationPrompt()
        }
    }

    private func ensureViewModel() {
        if viewModel == nil {
            viewModel = MapViewModel(client: client)
        }
        Task { await fetchIfReady() }
    }

    private func scheduleFetch() {
        Task {
            await pinDebouncer.schedule { await self.fetchIfReady() }
        }
    }

    private func fetchIfReady() async {
        guard let center = location.current, let vm = viewModel else { return }
        if pinFetchEnabled == false {
            vm.clearPins()
            return
        }
        await vm.fetchPins(at: center,
                           radiusKm: radius.radiusKm,
                           kingdomKey: taxon.selected.taxonKey,
                           datasetKey: focus.datasetKey,
                           speciesKey: focus.speciesKey)
    }
}

private struct LocationPrompt: View {
    @Environment(LocationStore.self) private var location
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "location.circle").font(.system(size: 56)).foregroundStyle(.secondary)
            switch location.authStatus {
            case .notDetermined:
                Text("GBIF Nearby uses your location to show records around you.")
                    .multilineTextAlignment(.center)
                Button("Allow location") { location.requestAuthorization() }
                    .buttonStyle(.borderedProminent)
            case .denied, .restricted:
                Text("Location access is off. You can long-press the map to drop a pin instead, or enable location in Settings.")
                    .multilineTextAlignment(.center)
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    Link("Open Settings", destination: url)
                }
            default:
                ProgressView("Finding your location…")
            }
            Spacer()
        }
        .padding(24)
    }
}
```

- [ ] **Step 2: Wire `MapTabView` into `RootTabView`**

Replace the Map tab placeholder in `GBIFNearby/App/RootTabView.swift`. The new file:
```swift
import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            MapTabView()
                .tabItem { Label("Map", systemImage: "map") }
            placeholder("Species")
                .tabItem { Label("Species", systemImage: "leaf") }
            placeholder("Gallery")
                .tabItem { Label("Gallery", systemImage: "photo.on.rectangle") }
            placeholder("Datasets")
                .tabItem { Label("Datasets", systemImage: "tray.full") }
            placeholder("About")
                .tabItem { Label("About", systemImage: "info.circle") }
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
}
```

- [ ] **Step 3: Build and run on simulator**

Run:
```bash
make build
xcrun simctl boot 'iPhone 15' 2>/dev/null || true
open -a Simulator
xcrun simctl install booted "$(make -s app-path)"
xcrun simctl launch booted org.gbif.nearby
```

Then, in the simulator menu: **Features → Location → Apple** (or any city preset). Grant location permission when prompted.

Expected:
- Map tab shows a base Apple map centered on the chosen location.
- A faint green circle indicates the current radius.
- A density-tile overlay loads (green hex bins) once the radius circle resolves at appropriate zoom.
- Zooming in past ~55 km diagonal triggers pin loading; tapping a pin opens the `OccurrenceSheet`.
- Dragging the slider in the header re-centers the radius circle and triggers a refetch.
- Switching kingdoms swaps the overlay and pin set.

- [ ] **Step 4: Commit**

```bash
git add GBIFNearby/Features/Map/MapTabView.swift GBIFNearby/App/RootTabView.swift
git commit -m "feat(map): assemble MapTabView with location prompts, density tiles, pins, debounce"
```

---

### Task 2.6: Manual pin-drop mode end-to-end smoke

**Files:** (none — purely manual verification)

This task verifies that the manual location flow works without code changes.

- [ ] **Step 1: Reset simulator's GBIF Nearby app state**

Run:
```bash
xcrun simctl uninstall booted org.gbif.nearby
make build
xcrun simctl install booted "$(make -s app-path)"
xcrun simctl launch booted org.gbif.nearby
```

- [ ] **Step 2: Deny location permission on first prompt**

When iOS asks for location, tap "Don't Allow".

Expected: `LocationPrompt` shows "Location access is off…" with an Open Settings link.

- [ ] **Step 3: Tap the Map tab (still no location), then long-press anywhere on the map view**

Long press anywhere on a visible portion of the map (the prompt overlay won't intercept the gesture in this build — that's fine for now: the next plan tightens the empty-state UX).

Expected: at this point the prompt covers the map, so long-press doesn't reach it. **Document this as a known limitation** to address in the Plan 5 polish phase. For the smoke test, instead grant location in Settings to verify the device-location path works.

- [ ] **Step 4: Grant location, verify pins appear**

In Settings → Privacy → Location Services → GBIF Nearby, set to "While Using". Return to the app. The map should center on the device's simulated location and density tiles + (on zoom-in) pins should appear.

- [ ] **Step 5: Commit a note about the manual-mode limitation**

Edit `README.md`, append at the bottom:
```markdown
## Known limitations (in development)

- Manual long-press pin-drop is implemented but is currently hidden behind the location-permission prompt when permission is denied. To be fixed in a later milestone.
```

```bash
git add README.md
git commit -m "docs: note manual pin-drop limitation"
```

---

### Task 2.7: Add a snapshot of the design's location-permission text to Info.plist source

**Files:**
- Verify: `project.yml` and built `Info.plist`

This is a sanity check, not a code change.

- [ ] **Step 1: Verify the usage string is present**

Run:
```bash
make build
plutil -p "$(make -s app-path)/Info.plist" | grep -i location
```
Expected: prints
```
"NSLocationWhenInUseUsageDescription" => "GBIF Nearby uses your location to show species and datasets recorded around you."
```

If missing, recheck `project.yml` step 2 of Task 0.1 and run `make project` again.

- [ ] **Step 2: No commit needed unless something changed.**

---

## Closeout

At the end of Plan 1 the repository should be in this state:

- `make test` passes ~30 tests across Util, Models, Networking, Stores, Map.
- `make build` succeeds.
- Running on a simulator (with a simulated location set) yields a working Map tab: base map, radius circle, density tiles, tappable pins at close zoom, header slider/chips that drive refetch.
- All other tabs render the persistent header above a placeholder.
- Single commit per task, clean history.

After verifying, push:

```bash
git push origin main
```

**Next plan:** `2026-05-11-gbif-nearby-plan-2-species-tab.md` will build the Species tab on top of this Core (facet fetch → enrichment → vernacular fallback → species detail → image carousel via occurrence API).
