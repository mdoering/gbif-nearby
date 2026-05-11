# GBIF Nearby

A native iOS app that shows GBIF biodiversity data centered on your current location.

Five tabs share a persistent header with a radius slider (0.1–100 km, default 5 km) and a single-select kingdom filter (All / Animals / Plants / Fungi):

- **Map** — GBIF occurrence density tiles + tappable pins at close zoom
- **Species** — ranked species list with counts
- **Gallery** — scrolling photo grid of occurrences nearby
- **Datasets** — vicinity-aware list of GBIF occurrence datasets, with global opt-out
- **About** — what the app does, what GBIF is, and settings

## Status

Design phase. See [`docs/superpowers/specs/2026-05-11-gbif-nearby-ios-app-design.md`](docs/superpowers/specs/2026-05-11-gbif-nearby-ios-app-design.md) for the full design.

## Stack

SwiftUI, iOS 17+, no third-party dependencies. Data from the [GBIF API](https://techdocs.gbif.org/en/openapi/).

## License

[Apache License 2.0](LICENSE)

## Known limitations (in development)

- Manual long-press pin-drop is implemented but is currently hidden behind the location-permission prompt when permission is denied. To be fixed in a later milestone.
