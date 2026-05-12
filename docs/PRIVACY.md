# Privacy Policy — GBIF Nearby

_Last updated: 2026-05-12_

GBIF Nearby is designed to respect your privacy. The app does not have user
accounts, does not use analytics or advertising SDKs, does not track you
across apps or websites, and does not share your personal information with
anyone.

## What the app uses your location for

GBIF Nearby asks for permission to use your location _while the app is in
use_. Your location is used for one purpose only: to query the public GBIF
API for biodiversity records near you. Each query sends a bounding box
derived from your current location and your chosen radius to `api.gbif.org`.

Your location is not stored on any server, is not associated with an
identifier, is not used for analytics, and is not shared with any third
party other than as part of the GBIF API request itself.

If you deny location access, the app falls back to a default location
(Berlin) and continues to work; only the "nearby" aspect is affected.

## What the app stores on your device

The app stores a small set of preferences locally on your device using the
standard iOS settings mechanism (`UserDefaults`):

- Search radius
- Selected kingdom filter (All / Animals / Plants / Fungi)
- Distance unit (metric or imperial)
- Preferred language for common names
- Per-dataset opt-out selections

These preferences never leave your device.

The app may cache GBIF API responses and images on disk so it works
smoothly and uses less network bandwidth. Cached data is stored only on
your device and is cleared by iOS like any other app cache.

## Network requests the app makes

GBIF Nearby talks to the public GBIF API at `api.gbif.org` and loads
images from URLs published by GBIF data providers. No requests are sent to
any analytics, advertising, or tracking service.

## What the app does not do

- It does not collect names, email addresses, or any account information.
- It does not track you across apps or websites.
- It does not contain advertising or third-party tracking SDKs.
- It does not upload your photos, contacts, or any other personal data.
- It does not run in the background or use your location when closed.

## Children

The app contains general-audience educational content about biodiversity
and is suitable for all ages. It collects no personal information from any
user, including children.

## Changes to this policy

If the privacy posture of the app ever changes, this document will be
updated and the change will be noted in the app's release notes.

## Contact

For privacy questions, please contact **apps@mdoering.eu**.
