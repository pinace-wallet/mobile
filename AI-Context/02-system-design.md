# Pinace Wallet Mobile — System Design

## 1. Architecture overview

```
┌───────────────────────────── Flutter app ─────────────────────────────┐
│  features/ (UI)     auth · home · agents · assets · activity · profile│
│        │ Riverpod providers (data/providers.dart, auth_providers.dart)│
│  data/                                                                │
│   ├─ keystore/   WalletKeystore  ── flutter_secure_storage (keys)     │
│   ├─ sui/        SuiService      ── Sui fullnode gRPC-web (testnet)   │
│   ├─ pinace/     PinaceTxService ── owner-signed PTBs                 │
│   │              CanonicalPoolResolver                                │
│   ├─ indexer/    IndexerClient (REST) · IndexerSseClient (SSE)        │
│   └─ firebase/   FirestoreRepo · FcmService                           │
└───────────────┬───────────────────┬───────────────────┬──────────────┘
                │ writes (PTB)      │ reads              │ auth/metadata/push
        Sui testnet fullnode   Pinace indexer      Firebase (Auth,
        (gRPC-web :443)        http://54.80.234.72:3001  Firestore, FCM)
                                          ▲
                             functions/ poller (indexer → FCM)
```

The extension's three layers (popup UI / background signer / dApp bridge) collapse into one app: the phone is both the UI and the secure signer. There is no dApp-injection equivalent in v1.

## 2. Key management & auth flow

```
app start ─ Firebase authStateChanges()
   │ no user            → LoginScreen (Google via Firebase Auth)
   │ user, no accounts  → WalletSetupScreen (create Ed25519 | import suiprivkey/hex/base64)
   │ user, accounts     → UnlockScreen (local_auth biometric; skips if disabled)
   └───────────────────→ Tab shell (Home/Agents/Assets/Activity/Profile)
```

- **Secure storage layout** (`WalletKeystore`, scoped per Firebase uid):
  - `pinace.accounts.<uid>` → JSON `[{id, name, address, createdAt}]`
  - `pinace.key.<uid>.<accountId>` → `suiprivkey1…` (bech32, Ed25519)
  - SharedPreferences: `pinace.active.<uid>` (active account id), `pinace.biometricEnabled`, `pinace.pool.<owner>` (locally created pool cache)
- The gate order lives in `core/router/app_router.dart` (go_router `redirect` + `refreshListenable` bumped by auth/accounts/lock providers) — a port of the extension's `Router.tsx` boot gate.
- Lock lifecycle: locked on cold start; `WidgetsBindingObserver` re-locks after >5 min backgrounded (`LockNotifier`).

## 3. Data layer

### 3.1 Reads — indexer (state of truth)
`IndexerClient` ports `Frontend/lib/indexer/client.ts`: GET `/pools/:id`, `/agents`, `/agents/:id`, `/agents/:id/timeline`, `/actions`, `/events`, `/owners/:address/stats`; 15 s in-memory TTL cache + in-flight de-dup keyed by URL; `invalidate(prefix)` after writes. DTOs in `data/indexer/models.dart` mirror `Frontend/lib/indexer/types.ts` (amounts = decimal strings → `BigInt`; timestamps = epoch-ms except pool `createdAt` / event `timestamp` ISO).

`IndexerSseClient` is a manual SSE reader over a streamed `http` GET on `/stream?owner=` (EventSource is browser-only). Emits typed `PinaceStreamEvent`s (`pool_*`, `agent_*`, `policy_*`, `action_*`); exponential-backoff reconnect; disposed with the tab shell. The `sseProvider` maps event kinds → `ref.invalidate(...)` of the affected providers, giving sub-second live refresh like the extension's `useIndexerStream`.

### 3.2 Reads — Sui fullnode
`SuiService` wraps `SuiGrpcClient` (sui-dart, gRPC-web — JSON-RPC sunsets 2026-07-31): `balanceOf` (owner + agent gas budget), `listBalances` (Assets), `objectInfo` (pool type for package-drift), `signAndExecuteTransaction` + `waitForTransaction`. All transport types stay behind this interface.

### 3.3 Writes — PTBs (`PinaceTxService`)
Ports `Frontend/entrypoints/background/pinace/operations.ts` against Move ground truth `contracts/core/sources/balance_pool.move` (testnet package `0x5be5…a23b`):

| Operation | PTB shape |
|---|---|
| createPool | `moveCall create`; poolId parsed from `effects.changedObjects` (CREATED + type `…::balance_pool::BalancePool`), then cached locally |
| deposit | `splitCoins(gas, amt)` → `deposit<T>(pool, coin)` — **pool's runtime package** |
| withdraw | `owner_withdraw<T>(pool, amt)` → `transferObjects([coin], owner)` — runtime package |
| connectAgent | `connect_agent(pool, agent, expiresMs, Clock 0x6)` + `splitCoins(gas, 1 SUI)` → transfer to agent (gas funding), one PTB |
| revokeAgent | `revoke_agent(pool, agent, reason: vector<u8>, Clock)` |
| set/updateSpendingLimit | `spending_limit_policy::new_config(u64×3)` → `attach_policy/update_policy<Witness, Config>(pool, agent, config, hash, marketplaceId, Clock)` |
| removeSpendingLimit | `remove_policy<Witness, Config>(pool, agent, Clock)` |

Two traps inherited from the extension, handled identically:
1. **Package drift** — deposit/withdraw must target the pool object's actual package (read from its on-chain type) or the tx aborts with `TypeMismatch`.
2. **Clock argument** — the TS contracts-sdk appends `&Clock` implicitly; in Dart `object('0x6')` is passed explicitly on connect/revoke/attach/update/remove.

### 3.4 Canonical pool
`CanonicalPoolResolver` ports `Frontend/lib/pinace/canonicalPool.ts`: candidates = pools of the owner's agents (indexer) ∪ locally saved pool from createPool (a fresh pool with no agents is invisible to the agents path); filter by current package via on-chain object type; pick the richest SUI balance; null ⇒ create-pool CTA. Resolved per active account.

## 4. State management

Riverpod. `accountsProvider` (AsyncNotifier) owns the account list + active id; every data provider watches `activeAccountProvider`, so **account switching invalidates the whole data graph automatically**. `invalidateAfterTx(ref)` refreshes everything after an owner-signed tx. Async UI states rendered via `AsyncValue.when` per screen.

## 5. Firebase design

- **Auth**: Google provider; `google_sign_in` v7 `authenticate()` → idToken → `signInWithCredential`.
- **Firestore** (metadata only, never keys):
  ```
  users/{uid}                      email, displayName, fcmTokens{token: {platform, updatedAt}}, prefs
  users/{uid}/accounts/{accId}     name, address, order, createdAt
  users/{uid}/agentMeta/{agentId}  nickname
  ```
  Rules (version-controlled at `mobile/firestore.rules`, deploy via
  `firebase deploy --only firestore:rules --project=prm-lab-3`):
  `match /users/{uid}/{document=**} { allow read, write: if request.auth != null && request.auth.uid == uid; }` — deny all else.
  A second top-level collection, `addressOwners/{address} -> {uid, claimedAt}`,
  enforces that a wallet address can only ever be linked to one Google
  account at a time (first-claim-wins, via Firestore's create/update
  distinction). Both clients write it via `claimAddress(address)` before
  writing `users/{uid}/accounts/{address}` — see `firestore_repo.dart`
  (mobile) and `Frontend/lib/firebase/repo.ts` (extension).
- **FCM**: `functions/` scheduled poller reads new indexer `/events`, maps owner address → users via `collectionGroup('accounts').where('address' == owner)`, sends token-targeted pushes (topics avoided: 0x addresses violate topic charset). Foreground messages surfaced with `flutter_local_notifications`.

## 6. Theming

`core/theme/` ports `Frontend/entrypoints/popup/globals.css`: dark-only, bg `#000`, primary `#006FEE`, success `#17C964`, danger `#F31260`, warning `#F5A524`, zinc scale, navy card gradient `#18181B→#0D1F35`, Inter (google_fonts), radius 24/32 cards, pill (Stadium) buttons. To be refined against the CSS the team drops into `figma/`.

## 7. Platform configuration

- **Android**: `FlutterFragmentActivity` (required by local_auth), `INTERNET` + `USE_BIOMETRIC` + `POST_NOTIFICATIONS` permissions, `network_security_config.xml` allowing cleartext **only** to the indexer IP.
- **iOS**: `NSFaceIDUsageDescription`, ATS exception scoped to the indexer host.
- **Firebase config**: `lib/firebase_options.dart` is a placeholder that throws; `main()` catches it and boots with a "run flutterfire configure" hint instead of crashing.

## 8. Risks & mitigations
1. **sui-dart PTB correctness** (pure encoding, shared Clock, generics, result-chaining) — verified against package source; every new PTB shape should be dry-run/tested on testnet before UI wiring (see implementation plan M3/M4 verification).
2. **JSON-RPC sunset** — already on gRPC-web; transport isolated in `SuiService`.
3. **Multi-account × canonical pool** — providers keyed by active address; a new account never silently reuses another account's pool.
4. **SSE in background** — suspended by OS; FCM covers background awareness, SSE reconnects on resume.
5. **google_sign_in v7 churn** — pinned; uses the v7 `authenticate()` flow.
