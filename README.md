# Quartier (Flutter)

Flutter port of the SwiftUI app in `../Quartier`. Uses the same Firebase
project (`quartier-36ce6`) and the same Firestore/Storage data layout, so the
iOS app and this app can run side by side on the same data.

## Setup

1. `flutter pub get`
2. Run on iOS / Android (`flutter run`). Firebase is configured for both
   platforms in `lib/firebase_options.dart` (Android app id
   `1:390078272406:android:2ab289dfa244e2893243b7`).

Requires Flutter 3.47+ (earlier versions fail on Xcode 27 at
"Prepare Flutter Framework" because of a `lipo -verify_arch` change).

### Build folder lives outside iCloud
`~/Documents` is synced by iCloud, which adds Finder metadata to new files and
makes Xcode code signing fail ("resource fork, Finder information, or similar
detritus not allowed"). `build/` is therefore a symlink to
`~/Developer/BuildCache/quartier_flutter`. If `flutter clean` removes the
symlink, recreate it:

    mkdir -p ~/Developer/BuildCache/quartier_flutter
    ln -s ~/Developer/BuildCache/quartier_flutter build

## Layout

- `lib/models/` – Firestore models (field names match the Swift app exactly)
- `lib/services/` – ports of `FirebaseManager`, `AuthService`, `ChatViewModel`,
  `ScheduleViewModel`/`NoticeViewModel`, plus `DraftStore` (replaces Core Data)
- `lib/providers.dart` – Riverpod streams the screens watch
- `lib/features/` – auth, landlord, tenant, listings and shared screens

## Compatibility notes

- New ids are uppercase UUIDs, matching Swift's `uuidString`.
- Listing drafts are local-only (as on iOS) and are not shared with the iOS app.
- Maps use OpenStreetMap tiles; switch to a commercial tile provider for
  production traffic.
- "Pay Now" is a mock (records payment on-device only), same as iOS.
