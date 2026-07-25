# Pinace Wallet Mobile — Build & Run Walkthrough

A battle-tested, gotcha-aware runbook for getting the app running end-to-end
on a real device/emulator with a real Firebase backend and a real indexer.
The setup runbook in [03-implementation-plan.md](03-implementation-plan.md)
is the terse checklist; this doc is the "what actually goes wrong and why"
version, written from the first real bring-up on Windows.

## 0. What you need before starting

- Flutter SDK + Android Studio (emulator) or a physical device.
- Node.js (for `firebase-tools` and, if you need it, the local indexer).
- A Google account with access to the shared Firebase project (`prm-lab-3`),
  or permission to create a new one.
- No secrets are committed to the repo. `lib/firebase_options.dart`,
  `android/app/google-services.json`, and
  `ios/Runner/GoogleService-Info.plist` are all git-ignored and generated
  locally by `flutterfire configure` (see below) — the app boots without
  them, but Google sign-in/Firestore/FCM stay disabled with a "run
  flutterfire configure" hint on the Login screen.

## 1. Firebase project setup

```bash
npm install -g firebase-tools
firebase login
```

`firebase login` needs a real interactive browser session — it will not
work from a non-interactive shell (no TTY/browser to complete the OAuth
redirect). Run it directly in your own terminal, not piped through
tooling.

**If you're driving this from an AI coding agent**: `firebase-tools`
detects agent-driven sessions and deliberately restricts the OAuth token to
`scopes: []` for privileged actions like `firebase projects:create` (you'll
see a 401 and `Detected Agent: ...` in `firebase-debug.log`). This is an
intentional safety guardrail, not a bug — create the project yourself via
the [Firebase Console](https://console.firebase.google.com) or your own
terminal instead of trying to script around it. Lower-privilege actions
(`firebase apps:create`, `firebase apps:sdkconfig`, etc.) are **not**
restricted this way.

Once you have a project (reuse `prm-lab-3` if you're working alongside the
browser extension — see §6):
1. Firebase Console → **Authentication** → enable the **Google** sign-in
   provider.
2. Firebase Console → **Firestore Database** → create a database.
   - **Use the default database ID** (leave it as `(default)`) unless you
     have a specific reason not to. If you create it with a custom name
     (e.g. `pinace-wallet`), `FirebaseFirestore.instance` will fail at
     runtime with a `NOT_FOUND` error for the `(default)` database — you'd
     then have to point every `FirebaseFirestore.instanceFor(...)` call at
     that custom `databaseId` explicitly (this repo's
     `lib/data/firebase/firestore_repo.dart` already does this, pointed at
     `pinace-wallet`, because that's what the shared project actually has —
     check `firebase firestore:databases:list --project=prm-lab-3` before
     assuming `(default)`).
   - Apply the security rules from
     [02-system-design.md §5](02-system-design.md).

## 2. flutterfire configure

```bash
dart pub global activate flutterfire_cli
```

If `flutterfire` isn't found on `PATH` afterward, add the pub cache bin dir:

```powershell
$env:Path += ";C:\Users\<you>\AppData\Local\Pub\Cache\bin"   # current session
setx PATH "$env:Path"                                         # persist
```

```bash
flutterfire configure --project=<your-project-id>
```

This generates `lib/firebase_options.dart` (git-ignored) plus the platform
config files. It'll prompt you to select Android/iOS and pick or create a
Firebase "app" per platform inside the project.

**Android SHA-1/SHA-256**: Google Sign-In on Android needs the debug
keystore's fingerprint registered against the Firebase Android app.
`./gradlew signingReport` works but is slow (spins up the full Gradle
daemon). Faster:

```bash
keytool -list -v -keystore ~/.android/debug.keystore \
  -alias androiddebugkey -storepass android -keypass android
```

Copy the SHA1/SHA256 lines into Firebase Console → Project Settings → your
Android app → Add fingerprint.

## 3. Android build gotchas (Windows-specific)

Two build failures you'll hit on a fresh `flutter run` on Windows if your
Flutter project and your Pub cache live on **different drive letters**
(e.g. project on `D:`, Pub cache on the default `C:`):

**Kotlin incremental-compiler crash** (`IllegalArgumentException: ...
different roots ...`) — the incremental compiler can't compute a relative
path across drive letters. Already worked around in this repo via
`android/gradle.properties`:
```
kotlin.incremental=false
```
If you're on a single drive this isn't needed, but leaving it off costs
only a little rebuild speed and isn't worth re-litigating per machine.

**`flutter_local_notifications` requires core library desugaring** — a
`MinSdkVersion`/desugaring build error the first time you build with that
plugin present. Already fixed in `android/app/build.gradle.kts`:
```kotlin
compileOptions {
    isCoreLibraryDesugaringEnabled = true
    // ...
}
dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
```
Both fixes are already committed — listed here so you recognize the errors
instead of re-diagnosing them if they resurface after a template
regeneration or Flutter upgrade.

## 4. Running against the indexer

By default the app points at the production indexer, deployed on Railway
(`https://backend-production-baa0.up.railway.app`, see
`lib/core/config/env.dart`'s `Env.indexerUrl`). This replaced an earlier
AWS EC2 deployment (`54.80.234.72:3001`) that stopped being reachable —
Railway was chosen for a fast, free redeploy of the exact same
`backend/` Dockerfile/docker-compose setup. Because it's HTTPS,
`android/app/src/main/res/xml/network_security_config.xml` and
`ios/Runner/Info.plist` no longer need any cleartext/ATS exception — both
are HTTPS-only now.

**If Railway shows empty data** (`/actions` returns `"data":[],"total":0"`),
check in the Railway dashboard that the `backend` service actually has
`PACKAGE_ID`, `SUI_RPC_URL`, and `DATABASE_URL` set — `docker-compose.yml`'s
env vars don't auto-transfer to Railway, they have to be set per-service
manually. `PACKAGE_ID` must match this repo's target
(`lib/core/config/env.dart`'s `Env.packageId`, currently
`0x5be5ab...a23b`) or every screen will look empty even though the chain
state is fine. Otherwise it may just still be doing its initial
full-history replay from the package's genesis — give it a few minutes.

If you ever need to fall back to running the indexer locally instead
(e.g. Railway is down, or you're testing an indexer-side change before
deploying it):
```bash
cd ../backend
docker compose up --build
```
Docker Desktop must be running first. First run does a fresh Postgres
init + `prisma migrate deploy` + a full-history replay — expect a
transient `P2028` transaction-timeout during replay (self-recovers on
retry); caught up once `lagMs` settles low and you see `"No new events
found"` polling steadily. Then point the app at it:
```bash
flutter run --dart-define=INDEXER_URL=http://10.0.2.2:3001
```
`10.0.2.2` is the Android emulator's alias for the host machine's
localhost. Since this is plain HTTP, you'll need to temporarily re-add a
cleartext domain-config exception for it in `network_security_config.xml`
(removed by default now that production is HTTPS) — don't leave that
exception in for a release build. A physical device on the same LAN needs
your machine's actual LAN IP instead of `10.0.2.2`.

**Remember to drop `--dart-define=INDEXER_URL=...` once you're done
testing locally** — otherwise the mobile app and the browser extension
will silently disagree on state because they're reading from different
indexers.

## 5. Debugging "transaction succeeded but nothing shows up in the UI"

If a write (e.g. create pool) visibly costs gas — balance drops, a success
toast/dialog appears — but the resulting object never shows up anywhere in
the UI, check these in order:

1. **Is the indexer actually reachable?** `curl` the indexer's `/health`
   or any REST endpoint from the same network the app runs on. A silent
   timeout (not a 4xx/5xx) means the app is failing closed with nothing to
   show, not that the write failed. See §4.
2. **Is the `readMask` on `signAndExecuteTransaction` requesting the field
   your parsing logic needs?** Sui's gRPC API gates nested fields behind
   explicit dotted paths — asking for `effects` does **not** imply you get
   `effects.changed_objects.object_type`; that field comes back empty
   unless requested by its full dotted path. `lib/data/sui/sui_service.dart`
   already requests `'effects.changed_objects.object_type'` explicitly for
   exactly this reason (poolId parsing in `PinaceTxService.createPool`
   matches on `type.endsWith('::balance_pool::BalancePool')`, which
   silently never matches if `object_type` comes back empty). If you add a
   new PTB whose result you need to parse from `changedObjects`, check the
   `readMask` includes the specific dotted path for whatever field you're
   reading — don't assume the parent field's presence is enough.

## 6. Keeping the mobile app and browser extension in sync

Both clients now read/write the **same Firebase project and Firestore
schema** (`users/{uid}`, `users/{uid}/accounts/{accId}`,
`users/{uid}/agentMeta/{agentId}` — see
[02-system-design.md §5](02-system-design.md)), and both read the same
on-chain state via the same indexer, so signing in with the same Google
account on both surfaces should show the same accounts/nicknames/pools.
See `../Frontend/AI-Context/google-auth-firestore-sync.md` for the
extension side of this (its Google Sign-In was added later than mobile's,
reusing this same project — check that doc if account data isn't syncing
as expected).

## 7. Day-to-day run command

Once Firebase config files exist and you've picked an indexer target:

```bash
flutter run
# or, pointed at a local indexer:
flutter run --dart-define=INDEXER_URL=http://10.0.2.2:3001
```

Faucet SUI for testnet testing: https://faucet.sui.io (rate-limited —
don't burn it repeatedly creating throwaway accounts if you can reuse one
funded account for iterative testing instead).
