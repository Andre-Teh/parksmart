# ParkSmart

A Flutter + Firebase mobile app for finding parking and EV charging spots, starting a timed session, and paying for it in real time.

## Features

- **Real-time parking & EV availability** — live map of parking lots and EV charging bays backed by Firestore snapshots, so available slot counts update instantly across devices.
- **Session timer with cost calculation** — start a session at a lot, track elapsed time live, and compute the running cost based on the lot's rate.
- **EV charging sessions** — separate flow and live notification for EV charging vs. regular parking.
- **Pending payment detection** — the home screen detects sessions that ended but haven't been paid for yet and prompts the user to complete payment.
- **Payment methods** — add/remove saved cards (Visa/Mastercard), set a default card, and pay via card, FPX, or e-wallet options.
- **Receipts & history** — past sessions with cost, duration, and payment status are stored and viewable from a history screen.
- **Notifications** — in-app notification center (read/unread, per-user) plus local push notifications for live session updates.
- **Profile & vehicle management** — edit profile details and save vehicle plate/type information.

## Tech stack

- **Framework:** Flutter (Dart SDK ^3.11.5)
- **Backend:** Firebase (Firebase Core, Firebase Auth, Cloud Firestore)
- **Navigation:** go_router
- **Maps:** google_maps_flutter + geolocator
- **UI:** google_fonts, Material theming (light/dark)
- **Other:** image_picker, url_launcher, flutter_local_notifications, google_sign_in, shared_preferences

## Screenshots

<!-- Add screenshots to a /screenshots folder and reference them here, e.g. -->
<!-- ![Home screen](screenshots/home.png) -->

| Home | Map | Session | Payment |
|------|-----|---------|---------|
| screenshots/home.png | screenshots/map.png | screenshots/session.png | screenshots/payment.png |

## Getting started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install)
- A Firebase project with **Authentication** (Email/Password, Google Sign-In) and **Cloud Firestore** enabled
- [Firebase CLI](https://firebase.google.com/docs/cli) + [FlutterFire CLI](https://firebase.flutter.dev/docs/cli/)
- A Google Maps API key ([Maps SDK for Android/iOS](https://developers.google.com/maps/documentation/android-sdk/get-api-key))

### 1. Clone and install dependencies

```bash
git clone https://github.com/Andre-Teh/parksmart.git
cd parksmart
flutter pub get
```

### 2. Connect your own Firebase project

This repo does not include Firebase config files (they're gitignored since they're project-specific). Generate your own with:

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

This creates `lib/firebase_options.dart` and `android/app/google-services.json` (and `ios/Runner/GoogleService-Info.plist` if targeting iOS) for your own Firebase project.

### 3. Add your Google Maps API key

In `android/app/src/main/AndroidManifest.xml`, set your own key in the `com.google.android.geo.API_KEY` meta-data tag:

```xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="YOUR_API_KEY_HERE"/>
```

For iOS, add the equivalent `GMSServices.provideAPIKey(...)` call in `ios/Runner/AppDelegate.swift`.

### 4. Run the app

```bash
flutter run
```

## Testing

```bash
flutter test
```

Includes widget tests for shared UI components (e.g. `test/widget_test.dart`).

## Known limitations

This is a university Final Year Project prototype, not a production app:

- **Payments are simulated.** Card entry stores only a label, last 4 digits, expiry, and card type in Firestore for display purposes — the full card number and CVV are never persisted. There is no real payment gateway integration, so no money actually moves. A production version would integrate a tokenised payment gateway (e.g. Stripe, Adyen) and never handle raw card data in the client at all.
- **Firestore security rules are intentionally permissive in places** to keep the client-side architecture simple (e.g. any signed-in user can adjust a parking lot's available slot count when starting/ending a session, since there's no backend/Cloud Function brokering that write). A production version would move slot-count updates into a trusted backend function.
- No automated backend/integration tests — only Flutter widget tests are included.

## Project context

This project was built as a Final Year Project (FYP) at Asia Pacific University of Technology & Innovation (APU), 2026.
