# Pinace Wallet Mobile — Requirements

> Companion docs: [02-system-design.md](02-system-design.md) · [03-implementation-plan.md](03-implementation-plan.md) · [04-walkthrough.md](04-walkthrough.md)

## 1. Product context

Pinace is an **agent-delegation protocol on Sui** (testnet). A user keeps their private key local, creates an on-chain **BalancePool** (escrow), deposits SUI, and connects **agents** — delegated Ed25519 identities bounded by on-chain Move policies (spending limit, token whitelist, slippage guard, time window) — which execute DeepBook swaps on the user's behalf. Delegation is revocable at any time (one-way kill switch).

The product already ships as:
- **Browser extension** (`Frontend/`, WXT + React) — the reference client this app mirrors.
- **Indexer backend** (`backend/`, Fastify + Prisma + Postgres) — read-only REST + SSE over indexed on-chain events.
- **Move contracts** (`contracts/core`) + TS SDK (`pinace-sdk/packages/core`).
- **Fenik** (`pinace-agent/`) — reference conversational trading agent (fenik.one).

This app is the **mobile client (Flutter)**: same core usage as the extension, plus mobile-first auth.

## 2. Functional requirements

### FR-1 Authentication (new vs extension)
- FR-1.1 Sign in with Google via **Firebase Authentication** (extension has no OAuth).
- FR-1.2 Sui wallet keys are **local Ed25519 keypairs** generated on device, stored in platform secure storage (Keychain / Android Keystore). Google login gates the app; it does **not** derive the Sui key (zkLogin deferred).
- FR-1.3 **Biometric unlock** ("passkey" UX): Face ID / fingerprint on app open and before key export; re-lock after 5 min in background. Skippable when hardware is unavailable.
- FR-1.4 Create new account or **import** existing key (`suiprivkey1…` bech32, raw 64-hex, or base64 seed) with address preview before confirming.
- FR-1.5 Sign out keeps keys on device; **Reset wallet** wipes all keys after typed confirmation.

### FR-2 Multi-account (new vs extension — "like Slush")
- FR-2.1 Multiple named accounts per Firebase user; active-account switcher in Profile.
- FR-2.2 Every data view is scoped to the active account; switching re-resolves balances, pool, agents.
- FR-2.3 Rename / export (biometric-gated) / remove (blocked for last account) per account.
- FR-2.4 Account metadata (names, addresses — never keys) synced to Firestore.

### FR-3 Screens
| Screen | Contents |
|---|---|
| Login | Google sign-in, redesigned for the new auth flow |
| Home | Owner SUI balance, pool card (balance + Add/Withdraw), owner stats, recent transactions, create-pool CTA |
| Agents | Live agent list (status chip, action count, last active) |
| Agents/:id | Agent header + expiry, gas budget, timeline, spending-limit policy CRUD, revoke kill-switch |
| Assets | All coin balances (live), NFT tab placeholder, receive QR |
| Transactions | Pool event feed, day-grouped, paginated, live via SSE |
| Profile | Account card (QR), account switcher, biometric + notification toggles, export key, sign out, reset |

### FR-4 On-chain operations (owner-signed PTBs, Sui testnet)
- FR-4.1 `create` pool; parse new poolId from transaction effects.
- FR-4.2 `deposit<T>` / `owner_withdraw<T>` with pool **package-drift resolution** (call the pool's runtime package, not env's).
- FR-4.3 `connect_agent` (+ fund agent 1 SUI gas in the same PTB), `revoke_agent`.
- FR-4.4 Spending-limit policy: `new_config` + `attach_policy` / `update_policy` / `remove_policy` (Clock `0x6` passed explicitly).

### FR-5 Live data
- FR-5.1 All state-of-truth reads from the indexer REST API; owner/agent SUI balances from the Sui fullnode (gRPC).
- FR-5.2 SSE `/stream?owner=` subscription refreshes affected screens in ≤ a few seconds; reconnect with backoff; suspend when backgrounded.

### FR-6 Firebase services (chosen: Auth, Firestore, FCM)
- FR-6.1 **Authentication** — Google provider.
- FR-6.2 **Cloud Firestore** — user profile, account names, agent nicknames, notification prefs, FCM tokens. Security rules: user can only read/write `users/{uid}/**`.
- FR-6.3 **Cloud Messaging** — push for agent activity (action settled, agent revoked, deposits) via a Cloud Function bridging indexer events → FCM tokens; foreground display via local notifications.

## 3. Non-functional requirements
- NFR-1 Private keys never leave the device; never logged, never in Firestore; export requires biometric re-auth.
- NFR-2 Testnet only in v1; network/URLs overridable via `--dart-define` (INDEXER_URL, PINACE_PACKAGE_ID).
- NFR-3 Uses Sui **gRPC-web** transport (JSON-RPC is decommissioned 2026-07-31).
- NFR-4 Plain-HTTP indexer requires scoped cleartext exceptions (Android network-security-config, iOS ATS) limited to the indexer host.
- NFR-5 Basic and clean codebase: feature-first folders, Riverpod for state, no codegen beyond flutterfire.
- NFR-6 Dark-only theme ported from the extension's design tokens; refined later against `figma/` CSS drops.

## 4. Out of scope (v1)
- zkLogin / Sui passkey (secp256r1 WebAuthn) signers — the signer layer leaves room to add them.
- Mainnet, swaps initiated from the wallet, NFT display, dApp/WalletConnect connections, token whitelist / slippage / time-window policy editing UI (contracts support them; extension doesn't surface them either).
