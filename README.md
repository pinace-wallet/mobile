# Pinace Wallet Mobile

Flutter Sui wallet for the Pinace agent-delegation protocol (testnet). Mirrors the browser extension (`../Frontend`) and adds Google login (Firebase Auth), biometric unlock, and Slush-style multi-account switching.

**Docs:** [AI-Context/](AI-Context/) — requirements, system design, implementation plan, and build walkthrough.

## Quick start

```bash
flutter pub get

# One-time Firebase setup (required for Google sign-in / Firestore / FCM):
dart pub global activate flutterfire_cli
flutterfire configure        # generates lib/firebase_options.dart + platform files

flutter run                  # Android emulator or iOS simulator
```

Without `flutterfire configure` the app still boots, but the Login screen shows a setup hint and sign-in is disabled.

- Enable the **Google** provider in Firebase Auth; create **Firestore**; add Android **SHA-1/SHA-256** fingerprints (`cd android && ./gradlew signingReport`).
- Test SUI: https://faucet.sui.io (testnet).
- Override endpoints: `flutter run --dart-define=INDEXER_URL=... --dart-define=PINACE_PACKAGE_ID=0x...`

## Layout

```
lib/
  core/       config, theme (extension design tokens), router (auth gate), shared widgets
  data/       keystore (secure storage), sui (gRPC), pinace (PTBs), indexer (REST+SSE), firebase
  features/   auth · home · agents · assets · activity · profile
functions/    Cloud Function: indexer events -> FCM push
figma/        drop Figma CSS exports here (design source of truth)
AI-Context/   project documentation
```
