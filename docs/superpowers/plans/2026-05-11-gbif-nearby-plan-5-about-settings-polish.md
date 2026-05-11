# GBIF Nearby — Plan 5: About + Settings + polish

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the final tab (About + Settings), add the distance-unit preference (km/mi), wire up the iOS privacy manifest, and fix the manual pin-drop UX limitation noted in Plan 1.

**Architecture:** A new `SettingsStore.distanceUnit` preference + a tiny `DistanceFormatter` utility used everywhere the radius is displayed. About tab is a `Form` with five static-ish sections (About this app, About GBIF, Settings, Links, App). Privacy manifest is a plist in the app resources. The pin-drop fix swaps the full-screen `LocationPrompt` for a non-blocking banner when permission is denied, and falls back to a world-view map center so `long-press` is reachable.

**Tech Stack:** Same as Plans 1–4.

---

## Spec

Implements the "Tab 5 — About + Settings", "Privacy & permissions", and the "Distance units" setting of [`docs/superpowers/specs/2026-05-11-gbif-nearby-ios-app-design.md`](../specs/2026-05-11-gbif-nearby-ios-app-design.md). Closes the manual-pin-drop limitation documented in `README.md`.

IUCN Red List status (Plan 2 deferral) is intentionally **not** in this plan — the `/species/{key}/iucnRedListCategory` payload shape varies and it's worth its own focused effort. Can land in a follow-up.

## File structure

| Path | Responsibility |
|---|---|
| `GBIFNearby/Core/Settings/SettingsStore.swift` | Add `distanceUnit` field |
| `GBIFNearby/Core/Settings/DistanceUnit.swift` | New enum (rawValue-backed) |
| `GBIFNearby/Core/Util/DistanceFormatter.swift` | New formatter `format(km:unit:)` |
| `GBIFNearby/Core/UI/RadiusHeader.swift` | Use formatter |
| `GBIFNearby/Features/Species/SpeciesTabView.swift` | Empty-state copy via formatter |
| `GBIFNearby/Features/Species/SpeciesDetailView.swift` | "Within X" labels via formatter |
| `GBIFNearby/Features/Gallery/GalleryTabView.swift` | Empty-state copy via formatter |
| `GBIFNearby/Features/Datasets/DatasetsTabView.swift` | Empty-state copy via formatter |
| `GBIFNearby/Features/Datasets/DatasetDetailView.swift` | "Within X" labels via formatter |
| `GBIFNearby/Features/About/AboutTabView.swift` | New tab body |
| `GBIFNearby/App/RootTabView.swift` | Replace About placeholder |
| `GBIFNearby/Features/Map/MapTabView.swift` | Banner + default-map fallback |
| `GBIFNearby/Resources/PrivacyInfo.xcprivacy` | Privacy manifest |
| `project.yml` | Reference `PrivacyInfo.xcprivacy` if needed (it's auto-bundled with the Resources path) |
| Tests: `GBIFNearbyTests/Core/Settings/SettingsStoreTests.swift` | Add `distanceUnit` tests |
| Tests: `GBIFNearbyTests/Core/Util/DistanceFormatterTests.swift` | |

## Conventions

- **Build/test:**
  ```
  xcodegen generate
  xcodebuild -scheme GBIFNearby -destination "platform=iOS Simulator,name=iPhone 16e" -derivedDataPath build test -quiet
  ```
- **Baseline before Task 1:** 71 passing.
- One commit per task.
- TDD on logic; views validated via build + manual smoke.
- **No push** until controller pushes at end of plan.

---

## Task 1: `DistanceUnit` + extend `SettingsStore` (TDD)

**Files:**
- Create: `GBIFNearby/Core/Settings/DistanceUnit.swift`
- Modify: `GBIFNearby/Core/Settings/SettingsStore.swift`
- Modify: `GBIFNearbyTests/Core/Settings/SettingsStoreTests.swift`

- [ ] **Step 1: Failing tests**

Append to `SettingsStoreTests.swift` before the suite's closing `}`:
```swift

    @Test("distanceUnit default derives from locale measurement system")
    func distanceUnitDefault() {
        let suite = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let s = SettingsStore(defaults: suite)
        // The default depends on the runtime locale; we just assert it's a valid value.
        #expect(DistanceUnit.allCases.contains(s.distanceUnit))
    }

    @Test("distanceUnit persists when set")
    func distanceUnitPersists() {
        let (s, d) = make()
        s.distanceUnit = .miles
        #expect(d.string(forKey: "distanceUnit") == "miles")
        s.distanceUnit = .kilometers
        #expect(d.string(forKey: "distanceUnit") == "kilometers")
    }

    @Test("distanceUnit restores from defaults")
    func distanceUnitRestores() {
        let suite = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        suite.set("miles", forKey: "distanceUnit")
        let s = SettingsStore(defaults: suite)
        #expect(s.distanceUnit == .miles)
    }
```

- [ ] **Step 2: Run — expect compile failure (`DistanceUnit` missing)**

- [ ] **Step 3: Implement `DistanceUnit`**

File: `GBIFNearby/Core/Settings/DistanceUnit.swift`
```swift
import Foundation

enum DistanceUnit: String, CaseIterable, Sendable, Codable {
    case kilometers
    case miles

    var displayName: String {
        switch self {
        case .kilometers: return "Kilometers"
        case .miles: return "Miles"
        }
    }

    var symbol: String {
        switch self {
        case .kilometers: return "km"
        case .miles: return "mi"
        }
    }

    static func fromLocale() -> DistanceUnit {
        Locale.current.measurementSystem == .metric ? .kilometers : .miles
    }
}
```

- [ ] **Step 4: Extend `SettingsStore`**

Replace `GBIFNearby/Core/Settings/SettingsStore.swift` with:
```swift
import Foundation
import Observation

@MainActor
@Observable
final class SettingsStore {
    static let vernacularLanguageKey = "vernacularLanguage"
    static let datasetsGlobalKey = "datasetsGlobal"
    static let distanceUnitKey = "distanceUnit"
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

    var datasetsGlobal: Bool {
        didSet { defaults.set(datasetsGlobal, forKey: Self.datasetsGlobalKey) }
    }

    var distanceUnit: DistanceUnit {
        didSet { defaults.set(distanceUnit.rawValue, forKey: Self.distanceUnitKey) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.vernacularLanguage = defaults.string(forKey: Self.vernacularLanguageKey)
        self.datasetsGlobal = defaults.bool(forKey: Self.datasetsGlobalKey)
        if let raw = defaults.string(forKey: Self.distanceUnitKey),
           let value = DistanceUnit(rawValue: raw) {
            self.distanceUnit = value
        } else {
            self.distanceUnit = DistanceUnit.fromLocale()
        }
    }
}
```

- [ ] **Step 5: Run — expect 3 new pass; total 74**

- [ ] **Step 6: Commit**

```bash
git add GBIFNearby/Core/Settings GBIFNearbyTests/Core/Settings/SettingsStoreTests.swift
git commit -m "feat(core): add DistanceUnit enum + SettingsStore.distanceUnit"
```

---

## Task 2: `DistanceFormatter` (TDD)

**Files:**
- Create: `GBIFNearby/Core/Util/DistanceFormatter.swift`
- Test: `GBIFNearbyTests/Core/Util/DistanceFormatterTests.swift`

- [ ] **Step 1: Failing tests**

File: `GBIFNearbyTests/Core/Util/DistanceFormatterTests.swift`
```swift
import Testing
import Foundation
@testable import GBIFNearby

@Suite("DistanceFormatter")
struct DistanceFormatterTests {
    @Test("kilometers passes through with 1 decimal + km suffix")
    func km() {
        #expect(DistanceFormatter.format(km: 5.0, unit: .kilometers) == "5.0 km")
        #expect(DistanceFormatter.format(km: 0.1, unit: .kilometers) == "0.1 km")
        #expect(DistanceFormatter.format(km: 12.34, unit: .kilometers) == "12.3 km")
    }

    @Test("miles converts via 0.621371 with 1 decimal + mi suffix")
    func miles() {
        // 5 km = 3.106855 mi → 3.1 mi
        #expect(DistanceFormatter.format(km: 5.0, unit: .miles) == "3.1 mi")
        // 1 km = 0.621371 mi → 0.6 mi
        #expect(DistanceFormatter.format(km: 1.0, unit: .miles) == "0.6 mi")
        // 100 km = 62.1371 mi → 62.1 mi
        #expect(DistanceFormatter.format(km: 100.0, unit: .miles) == "62.1 mi")
    }

    @Test("zero radius renders 0.0 in both units")
    func zero() {
        #expect(DistanceFormatter.format(km: 0, unit: .kilometers) == "0.0 km")
        #expect(DistanceFormatter.format(km: 0, unit: .miles) == "0.0 mi")
    }
}
```

- [ ] **Step 2: Run — expect compile failure**

- [ ] **Step 3: Implement**

File: `GBIFNearby/Core/Util/DistanceFormatter.swift`
```swift
import Foundation

enum DistanceFormatter {
    static func format(km: Double, unit: DistanceUnit) -> String {
        switch unit {
        case .kilometers:
            return String(format: "%.1f km", km)
        case .miles:
            return String(format: "%.1f mi", km * 0.621371)
        }
    }
}
```

- [ ] **Step 4: Run — expect 3 new pass; total 77**

- [ ] **Step 5: Commit**

```bash
git add GBIFNearby/Core/Util/DistanceFormatter.swift GBIFNearbyTests/Core/Util/DistanceFormatterTests.swift
git commit -m "feat(core): add DistanceFormatter"
```

---

## Task 3: Apply `DistanceFormatter` across display points

**Files:**
- Modify: `GBIFNearby/Core/UI/RadiusHeader.swift`
- Modify: `GBIFNearby/Features/Species/SpeciesTabView.swift`
- Modify: `GBIFNearby/Features/Species/SpeciesDetailView.swift`
- Modify: `GBIFNearby/Features/Gallery/GalleryTabView.swift`
- Modify: `GBIFNearby/Features/Datasets/DatasetsTabView.swift`
- Modify: `GBIFNearby/Features/Datasets/DatasetDetailView.swift`

All these files currently hard-code `String(format: "%.1f km", radius.radiusKm)`. Replace with `DistanceFormatter.format(km: radius.radiusKm, unit: settings.distanceUnit)`, importing `SettingsStore` from `@Environment` where it isn't already.

- [ ] **Step 1: `RadiusHeader`**

In `GBIFNearby/Core/UI/RadiusHeader.swift`:
- Add `@Environment(SettingsStore.self) private var settings` to the struct.
- Replace `Text(formatted(radiusStore.radiusKm))` with `Text(DistanceFormatter.format(km: radiusStore.radiusKm, unit: settings.distanceUnit))`.
- Delete the private `formatted(_:)` helper since it's now unused.
- Update the `#Preview` to inject a `SettingsStore()`:
```swift
#Preview {
    RadiusHeader()
        .environment(RadiusStore())
        .environment(TaxonFilterStore())
        .environment(SettingsStore())
}
```

- [ ] **Step 2: `SpeciesTabView`**

In `SpeciesTabView.swift`:
- Add `@Environment(SettingsStore.self) private var settings` if not already present (it already is — used for vernacularLanguage).
- In the empty-state `Text`, replace `"No species recorded within \(String(format: "%.1f", radius.radiusKm)) km."` with `"No species recorded within \(DistanceFormatter.format(km: radius.radiusKm, unit: settings.distanceUnit))."`

- [ ] **Step 3: `SpeciesDetailView`**

In `SpeciesDetailView.swift`:
- Add `@Environment(SettingsStore.self) private var settings`.
- Replace `"Within \(String(format: "%.1f", radius.radiusKm)) km"` with `"Within \(DistanceFormatter.format(km: radius.radiusKm, unit: settings.distanceUnit))"` (both occurrences — the stat row label and any other place).

- [ ] **Step 4: `GalleryTabView`**

In `GalleryTabView.swift`:
- Add `@Environment(SettingsStore.self) private var settings`.
- In the empty-state `Text`, replace `"No photos within \(String(format: "%.1f", radius.radiusKm)) km."` with `"No photos within \(DistanceFormatter.format(km: radius.radiusKm, unit: settings.distanceUnit))."`

- [ ] **Step 5: `DatasetsTabView`**

In `DatasetsTabView.swift`:
- `@Environment(SettingsStore.self) private var settings` is already present.
- Replace the vicinity empty-state copy with `"No datasets have records within \(DistanceFormatter.format(km: radius.radiusKm, unit: settings.distanceUnit))."`

- [ ] **Step 6: `DatasetDetailView`**

In `DatasetDetailView.swift`:
- Add `@Environment(SettingsStore.self) private var settings`.
- Replace `"Within \(String(format: "%.1f", radius.radiusKm)) km"` with `"Within \(DistanceFormatter.format(km: radius.radiusKm, unit: settings.distanceUnit))"`.

- [ ] **Step 7: Build + tests (77 still pass)**

- [ ] **Step 8: Commit**

```bash
git add GBIFNearby/Core/UI/RadiusHeader.swift GBIFNearby/Features
git commit -m "feat(ui): use DistanceFormatter everywhere a radius is shown"
```

---

## Task 4: `AboutTabView` shell + static sections

**Files:**
- Create: `GBIFNearby/Features/About/AboutTabView.swift`

This task creates the file with all five sections in place but the **Settings** section and **Links** section using only placeholders / static text. Tasks 5 and 6 flesh them out.

- [ ] **Step 1: Implement**

File: `GBIFNearby/Features/About/AboutTabView.swift`
```swift
import SwiftUI

struct AboutTabView: View {
    var body: some View {
        NavigationStack {
            Form {
                Section("About this app") {
                    Text("GBIF Nearby shows GBIF biodiversity data recorded around your current location. Drag the radius slider in the header to change the search distance, and tap the kingdom chips to focus on Animals, Plants, or Fungi.")
                        .font(.footnote)
                    Text("Browse occurrences on the Map, a ranked Species list with vernacular names, a photo Gallery, and the underlying Datasets — all live from the GBIF API.")
                        .font(.footnote)
                }

                Section("About GBIF") {
                    Text("GBIF — the Global Biodiversity Information Facility — is an international network and data infrastructure funded by the world's governments and aimed at providing anyone, anywhere, open access to data about all types of life on Earth.")
                        .font(.footnote)
                }

                Section("Settings") {
                    Text("Settings come in Task 5.").foregroundStyle(.tertiary)
                }

                Section("Links") {
                    Text("Links come in Task 6.").foregroundStyle(.tertiary)
                }

                Section("App") {
                    HStack {
                        Text("Version").foregroundStyle(.secondary)
                        Spacer()
                        Text(appVersion).monospacedDigit()
                    }
                    HStack {
                        Text("Build").foregroundStyle(.secondary)
                        Spacer()
                        Text(appBuild).monospacedDigit()
                    }
                    Text("Data: GBIF.org · Map tiles: GBIF & Apple Maps")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    private var appBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
    }
}

#Preview { AboutTabView() }
```

- [ ] **Step 2: Build (no new tests)**

- [ ] **Step 3: Commit**

```bash
git add GBIFNearby/Features/About/AboutTabView.swift
git commit -m "feat(about): add AboutTabView shell with About + GBIF + App sections"
```

---

## Task 5: AboutTabView — Settings section

**Files:**
- Modify: `GBIFNearby/Features/About/AboutTabView.swift`

- [ ] **Step 1: Replace the Settings section placeholder**

In `AboutTabView`, replace
```swift
                Section("Settings") {
                    Text("Settings come in Task 5.").foregroundStyle(.tertiary)
                }
```
with the full settings section. The struct also needs to consume the environment objects. Add at the top of the struct:
```swift
    @Environment(SettingsStore.self) private var settings
    @Environment(LocationStore.self) private var location
```

And the section:
```swift
                Section("Settings") {
                    @Bindable var settings = settings

                    Picker("Vernacular language", selection: Binding(
                        get: { settings.vernacularLanguage ?? "" },
                        set: { settings.vernacularLanguage = $0.isEmpty ? nil : $0 }
                    )) {
                        Text("Use device language").tag("")
                        Divider()
                        ForEach(Self.languageOptions, id: \.code) { opt in
                            Text(opt.label).tag(opt.code)
                        }
                    }

                    Picker("Distance unit", selection: $settings.distanceUnit) {
                        ForEach(DistanceUnit.allCases, id: \.self) { unit in
                            Text(unit.displayName).tag(unit)
                        }
                    }

                    locationRow
                }
```

Add the helper data and `locationRow` near the bottom of the struct:
```swift
    private struct LanguageOption: Hashable {
        let code: String
        let label: String
    }

    private static let languageOptions: [LanguageOption] = [
        .init(code: "en", label: "English"),
        .init(code: "de", label: "Deutsch"),
        .init(code: "fr", label: "Français"),
        .init(code: "es", label: "Español"),
        .init(code: "pt", label: "Português"),
        .init(code: "it", label: "Italiano"),
        .init(code: "nl", label: "Nederlands"),
        .init(code: "sv", label: "Svenska"),
        .init(code: "ja", label: "日本語"),
        .init(code: "zh", label: "中文"),
        .init(code: "ru", label: "Русский"),
    ]

    @ViewBuilder
    private var locationRow: some View {
        switch location.source {
        case .manual:
            HStack {
                Label("Manual pin", systemImage: "mappin.circle.fill")
                Spacer()
                Button("Clear") { location.clearManual() }
                    .foregroundStyle(.tint)
            }
        case .device:
            HStack {
                Text("Location").foregroundStyle(.secondary)
                Spacer()
                Text(authStatusText).foregroundStyle(.secondary).font(.footnote)
            }
            if location.authStatus == .denied || location.authStatus == .restricted {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    Link("Open Settings", destination: url)
                }
            }
        }
    }

    private var authStatusText: String {
        switch location.authStatus {
        case .notDetermined: return "Not requested"
        case .denied: return "Denied"
        case .restricted: return "Restricted"
        case .authorizedWhenInUse: return "While using"
        case .authorizedAlways: return "Always"
        @unknown default: return "Unknown"
        }
    }
```

Also add `import UIKit` at the top of the file to access `UIApplication.openSettingsURLString` and `import CoreLocation` for the `CLAuthorizationStatus` constants used in the switch.

Update the `#Preview` to:
```swift
#Preview {
    AboutTabView()
        .environment(SettingsStore())
        .environment(LocationStore())
}
```

- [ ] **Step 2: Build + tests (77 still pass)**

- [ ] **Step 3: Commit**

```bash
git add GBIFNearby/Features/About/AboutTabView.swift
git commit -m "feat(about): add Settings section (language, distance unit, location)"
```

---

## Task 6: AboutTabView — Links section

**Files:**
- Modify: `GBIFNearby/Features/About/AboutTabView.swift`

- [ ] **Step 1: Replace Links placeholder**

Add state for the safari sheet at the top of the struct:
```swift
    @State private var safariURL: SafariLink?
```

Helper struct (add near the other helpers):
```swift
    private struct SafariLink: Identifiable, Hashable {
        let url: URL
        var id: URL { url }
    }
```

Replace
```swift
                Section("Links") {
                    Text("Links come in Task 6.").foregroundStyle(.tertiary)
                }
```
with:
```swift
                Section("Links") {
                    linkRow(title: "Open GBIF.org", urlString: "https://www.gbif.org")
                    linkRow(title: "GBIF Occurrence search", urlString: "https://www.gbif.org/occurrence/search")
                    linkRow(title: "GBIF API documentation", urlString: "https://techdocs.gbif.org/en/openapi/")
                    linkRow(title: "GBIF data use guidelines", urlString: "https://www.gbif.org/citation-guidelines")
                }
```

Add the helper method:
```swift
    @ViewBuilder
    private func linkRow(title: String, urlString: String) -> some View {
        if let url = URL(string: urlString) {
            Button {
                safariURL = SafariLink(url: url)
            } label: {
                HStack {
                    Text(title)
                    Spacer()
                    Image(systemName: "safari").foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
        }
    }
```

Add the sheet modifier near the existing `.navigationTitle("About")` modifier:
```swift
            .sheet(item: $safariURL) { link in
                SafariView(url: link.url).ignoresSafeArea()
            }
```

- [ ] **Step 2: Build + tests (77 still pass)**

- [ ] **Step 3: Commit**

```bash
git add GBIFNearby/Features/About/AboutTabView.swift
git commit -m "feat(about): add Links section (gbif.org, search, docs, citation guidelines)"
```

---

## Task 7: Wire `AboutTabView` into `RootTabView`

**Files:**
- Modify: `GBIFNearby/App/RootTabView.swift`

- [ ] **Step 1: Replace placeholder**

Replace:
```swift
placeholder("About")
    .tabItem { Label("About", systemImage: "info.circle") }
    .tag(Tab.about)
```
with:
```swift
AboutTabView()
    .tabItem { Label("About", systemImage: "info.circle") }
    .tag(Tab.about)
```

Now the `placeholder(_:)` helper is unused — delete it and also delete its `private func placeholder(_ label: String)` definition since RootTabView no longer needs it.

- [ ] **Step 2: Build + tests (77 still pass)**

- [ ] **Step 3: Smoke install + launch**

```bash
xcrun simctl boot 'iPhone 16e' 2>/dev/null || true
xcrun simctl uninstall booted org.gbif.nearby 2>/dev/null || true
xcrun simctl install booted "$(find build/Build/Products -name 'GBIFNearby.app' -print -quit)"
xcrun simctl launch booted org.gbif.nearby
```

Verify the About tab loads with all five sections populated and the language/distance pickers persist across tab switches.

- [ ] **Step 4: Commit**

```bash
git add GBIFNearby/App/RootTabView.swift
git commit -m "feat(about): wire AboutTabView into RootTabView and remove placeholder helper"
```

---

## Task 8: `PrivacyInfo.xcprivacy`

**Files:**
- Create: `GBIFNearby/Resources/PrivacyInfo.xcprivacy`

The privacy manifest declares no data collection and the small set of accessed APIs (UserDefaults for settings; file timestamps via URLCache).

- [ ] **Step 1: Create manifest**

File: `GBIFNearby/Resources/PrivacyInfo.xcprivacy`
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSPrivacyCollectedDataTypes</key>
    <array/>
    <key>NSPrivacyTracking</key>
    <false/>
    <key>NSPrivacyTrackingDomains</key>
    <array/>
    <key>NSPrivacyAccessedAPITypes</key>
    <array>
        <dict>
            <key>NSPrivacyAccessedAPIType</key>
            <string>NSPrivacyAccessedAPICategoryUserDefaults</string>
            <key>NSPrivacyAccessedAPITypeReasons</key>
            <array>
                <string>CA92.1</string>
            </array>
        </dict>
        <dict>
            <key>NSPrivacyAccessedAPIType</key>
            <string>NSPrivacyAccessedAPICategoryFileTimestamp</string>
            <key>NSPrivacyAccessedAPITypeReasons</key>
            <array>
                <string>C617.1</string>
            </array>
        </dict>
    </array>
</dict>
</plist>
```

- [ ] **Step 2: Confirm bundling**

XcodeGen's `resources: GBIFNearby/Resources` in `project.yml` already bundles every file in that folder. Regenerate and build:
```
xcodegen generate
xcodebuild -scheme GBIFNearby -destination "platform=iOS Simulator,name=iPhone 16e" -derivedDataPath build build -quiet
```

Then verify the manifest landed inside the .app:
```bash
APP=$(find build/Build/Products -name 'GBIFNearby.app' -print -quit)
ls "$APP" | grep -i privacy
```
Expected: `PrivacyInfo.xcprivacy` appears in the .app's root.

If it doesn't appear, modify `project.yml` to explicitly list the resource. Otherwise no project.yml change is needed.

- [ ] **Step 3: Commit**

```bash
git add GBIFNearby/Resources/PrivacyInfo.xcprivacy project.yml
git commit -m "feat(privacy): add PrivacyInfo.xcprivacy (no data collected; UserDefaults + FileTimestamp)"
```

(If `project.yml` was not modified, the `git add project.yml` part is a no-op and the commit still works.)

---

## Task 9: Manual pin-drop UX fix

**Files:**
- Modify: `GBIFNearby/Features/Map/MapTabView.swift`
- Modify: `README.md`

Current behaviour (Plan 1 known limitation): when location is denied, a full-screen `LocationPrompt` covers the map, so the `UILongPressGestureRecognizer` on `GBIFMapView` never receives touches.

Fix:
- When `authStatus` is `.denied` or `.restricted` (and no manual pin yet), render the `GBIFMapView` at a wide default center, with a non-blocking banner across the top explaining "Long-press anywhere to drop a pin or open Settings".
- Keep the full-screen `LocationPrompt` only for `.notDetermined` (the initial permission prompt).

- [ ] **Step 1: Update `MapTabView.map` and `LocationPrompt`**

Replace the entire `private var map: some View` block and the `LocationPrompt` struct in `GBIFNearby/Features/Map/MapTabView.swift` with:

```swift
    @ViewBuilder
    private var map: some View {
        if let center = location.current {
            mapView(center: center)
        } else {
            switch location.authStatus {
            case .denied, .restricted:
                ZStack(alignment: .top) {
                    mapView(center: Self.defaultCenter)
                    deniedBanner
                        .padding(.top, 8)
                        .padding(.horizontal, 12)
                }
            default:
                LocationPrompt()
            }
        }
    }

    // Sensible default when permission is denied and the user hasn't dropped a pin yet.
    // GBIFMapView zooms based on the current radius (default 5 km → ~15 km span), so a
    // "wide world view" wouldn't render here; the user pans/pinches and long-presses to relocate.
    private static let defaultCenter = CLLocationCoordinate2D(latitude: 52.52, longitude: 13.40) // Berlin

    @ViewBuilder
    private func mapView(center: CLLocationCoordinate2D) -> some View {
        GBIFMapView(
            center: center,
            radiusKm: radius.radiusKm,
            taxonKey: taxon.selected.taxonKey,
            datasetKey: focus.datasetKey,
            speciesKey: focus.speciesKey,
            pins: viewModel?.pins.value ?? [],
            mapType: mapType,
            recenterID: recenterID,
            onPinTap: { selectedOccurrence = $0 },
            onLongPress: { coord in location.setManual(coord) },
            onRegionChange: { region in
                pinFetchEnabled = region.span.latitudeDelta < 0.2
                scheduleRegionFetch()
            }
        )
    }

    @ViewBuilder
    private var deniedBanner: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Location is off")
                .font(.footnote.bold())
            Text("Long-press anywhere on the map to drop a pin, or enable location in Settings.")
                .font(.caption)
                .foregroundStyle(.secondary)
            if let url = URL(string: UIApplication.openSettingsURLString) {
                Link("Open Settings", destination: url).font(.caption)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
        .padding(.top, 88) // sits below RadiusHeader + chip rows
    }
```

And shrink `LocationPrompt` to only cover the `.notDetermined` case (already correct; the switch above limits it to that path):
```swift
private struct LocationPrompt: View {
    @Environment(LocationStore.self) private var location
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "location.circle").font(.system(size: 56)).foregroundStyle(.secondary)
            Text("GBIF Nearby uses your location to show records around you.")
                .multilineTextAlignment(.center)
            Button("Allow location") { location.requestAuthorization() }
                .buttonStyle(.borderedProminent)
            Spacer()
        }
        .padding(24)
    }
}
```

Make sure `import UIKit` is present at the top of the file (for `UIApplication.openSettingsURLString`). It's already imported transitively via SwiftUI, but add it explicitly to be safe.

- [ ] **Step 2: Update README**

In `README.md`, replace the "Known limitations (in development)" block with:
```markdown
## Status

Plans 1–5 shipped: the app has a working Map, Species, Gallery, Datasets, and About tab, plus a privacy manifest and configurable radius / kingdom / distance-unit / vernacular-language settings.
```

(Delete the old known-limitations bullet about pin-drop being unreachable.)

- [ ] **Step 3: Build + tests (77 still pass)**

- [ ] **Step 4: Smoke install + launch**

```bash
xcrun simctl boot 'iPhone 16e' 2>/dev/null || true
xcrun simctl uninstall booted org.gbif.nearby 2>/dev/null || true
xcrun simctl install booted "$(find build/Build/Products -name 'GBIFNearby.app' -print -quit)"
xcrun simctl launch booted org.gbif.nearby
```

If interactive, set the simulator to deny location, launch the app, verify a non-blocking banner appears over a wide world-view map, long-press to drop a pin, see data load around it.

- [ ] **Step 5: Commit**

```bash
git add GBIFNearby/Features/Map/MapTabView.swift README.md
git commit -m "fix(map): non-blocking banner + world-view fallback when location is denied"
```

---

## Closeout

After Plan 5:

- 77 tests pass (6 new — 3 distance unit + 3 distance formatter).
- About tab live with all five sections (About, GBIF, Settings, Links, App).
- Distance unit setting persists and is honored everywhere the radius is displayed.
- Privacy manifest bundled.
- Manual pin-drop is reachable when location is denied.

Push:
```bash
git push origin main
```

**Optional follow-ups** for a hypothetical Plan 6 (not required for shipping):
- IUCN Red List status in `SpeciesDetailView` (defer until the GBIF endpoint's exact response shape is confirmed).
- App-icon refinements; localized UI strings.
- iPad split-view layout.
- TestFlight + App Store submission.
