# Pinace Wallet Mobile — Implementation Plan

Milestones with verification gates. Code references point at this repo (`mobile/`) and the reference sources in the monorepo.

## M0 — Scaffold + SDK feasibility ✅ (implemented)
- `flutter create` (org `xyz.pinace`, Android + iOS), feature-first structure, dark theme (`core/theme/`), go_router 5-tab shell with auth-gate redirect (`core/router/app_router.dart`), `figma/` folder for design drops.
- Platform config: Android `FlutterFragmentActivity`, permissions, cleartext scoped to the indexer IP (`res/xml/network_security_config.xml`); iOS ATS exception + Face ID usage string.
- **SDK feasibility check** (replaces a runtime spike): sui-dart 0.4.3 source audit confirmed all required capabilities — `SuiAccount.fromPrivateKey` with `suiprivkey` bech32, `encodeSuiPrivateKey`, gRPC-web client with `signAndExecuteTransaction`/`simulateTransaction`/`waitForTransaction`/`listBalances`, Transaction builder with `moveCall` (type args), `splitCoins`, `transferObjects`, `object()` auto-resolving shared objects (Clock), `pureInt/pureAddress/pureVector`.
- Verify: `flutter analyze` clean; app boots to Login on an emulator.

## M1 — Auth + keys + multi-account ✅ (implemented)
- Firebase Google sign-in (`features/auth/auth_providers.dart` — google_sign_in v7 `authenticate()` flow), placeholder `firebase_options.dart` with graceful degradation.
- `WalletKeystore` (`data/keystore/`): per-uid multi-account Ed25519, secure storage, create/import/export/rename/remove/reset; import preview address.
- Biometric gate (`LockNotifier` + `UnlockScreen`), enable prompt after first setup, 5-min background re-lock, Profile toggle.
- Firestore metadata sync (`data/firebase/firestore_repo.dart`).
- Verify (needs a configured Firebase project): sign in on emulator w/ Play services; import the extension's exported `suiprivkey1…` → identical address; kill/reopen → biometric prompt; add + switch accounts.

## M2 — Read-only wallet ✅ (implemented)
- Indexer DTOs (`data/indexer/models.dart`), `IndexerClient` (TTL cache + de-dup), manual `IndexerSseClient`, `CanonicalPoolResolver`.
- Screens: Home (balance, pool card, stats, recent activity), Agents list, Agent detail (header/budget/policies/timeline), Assets (live `listBalances` + receive QR), Activity (day-grouped, paged), Profile.
- SSE → provider invalidation (`sseProvider` in `data/providers.dart`).
- Verify: side-by-side parity with the extension for the same imported account; deposit from the extension → phone updates in seconds.

## M3 — Pool writes ✅ (implemented)
- `PinaceTxService.createPool/depositToPool/withdrawFromPool` with package-drift resolution; deposit/withdraw sheets (`features/home/pool_sheets.dart`) with MAX-minus-gas; created pool cached for canonical resolution.
- Verify on testnet: faucet-fund a fresh account → create pool → deposit 0.5 SUI → visible in indexer + extension → withdraw returns funds. **This is the first end-to-end signing test — do it before demoing.**

## M4 — Agent management ✅ (implemented)
- `connectAgent` (+1 SUI gas fund), `revokeAgent` (confirm dialog), spending-limit attach/update/remove (`features/agents/policy_sheet.dart`), Clock `0x6` explicit.
- Verify: connect a test agent address; attach limit → policy shows in `/agents/:id`; revoke → status flips, agent PTBs abort.

## M5 — FCM + polish 🔶 (partially implemented)
- Done: FCM token registration + foreground notifications (`data/firebase/fcm_service.dart`), notification toggle in Profile, agent nicknames (Firestore), empty/error states throughout.
- Remaining:
  - `functions/` Cloud Function: scheduled (1-min) indexer `/events` poller → token-targeted FCM sends (sketch in 02-system-design §5). Deploy with `firebase deploy --only functions`.
  - App icons + splash, Analytics/Crashlytics if wanted later, refinement against `figma/` CSS.

## Setup runbook (once per developer / project)
1. `cd mobile && flutter pub get`.
2. Create a Firebase project; enable **Google** auth provider; create Firestore; paste the security rules from 02-system-design §5.
3. `dart pub global activate flutterfire_cli && flutterfire configure` (generates real `lib/firebase_options.dart`, `android/app/google-services.json`, `ios/Runner/GoogleService-Info.plist`).
4. Android: add debug SHA-1/SHA-256 (`cd android && ./gradlew signingReport`) to the Firebase Android app; iOS: add the reversed client id URL scheme to `Info.plist`.
5. FCM (M5): upload APNs key for iOS; Android 13+ asks for POST_NOTIFICATIONS at runtime.
6. Faucet SUI for testing: https://faucet.sui.io (testnet).
7. Run: `flutter run` (optionally `--dart-define=INDEXER_URL=…`).
