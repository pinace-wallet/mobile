/**
 * Indexer → FCM bridge.
 *
 * Every minute, pulls recent events from the Pinace indexer and pushes
 * notifications to users whose registered wallet address owns the pool.
 * Token-targeted sends (not topics — 0x addresses violate FCM topic charset).
 *
 * State: lastSeen event id kept in Firestore `meta/indexerBridge`.
 * Deploy: firebase deploy --only functions
 */
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");

initializeApp();

const INDEXER_URL =
  process.env.INDEXER_URL ?? "https://backend-production-baa0.up.railway.app";

const NOTIFY = {
  ActionSettledEvent: (e) => ({
    title: "Agent action settled",
    body: "An agent finished executing on your pool.",
  }),
  AgentRevokedEvent: () => ({
    title: "Agent revoked",
    body: "An agent's access to your pool was revoked.",
  }),
  DepositEvent: () => ({
    title: "Pool deposit",
    body: "SUI was deposited into your pool.",
  }),
  WithdrawEvent: () => ({
    title: "Pool withdrawal",
    body: "SUI was withdrawn from your pool.",
  }),
};

exports.indexerBridge = onSchedule("every 1 minutes", async () => {
  const db = getFirestore();
  const stateRef = db.doc("meta/indexerBridge");
  const state = (await stateRef.get()).data() ?? {};
  const lastSeenId = state.lastSeenId ?? null;

  const res = await fetch(`${INDEXER_URL}/events?limit=50&page=1`);
  if (!res.ok) throw new Error(`indexer ${res.status}`);
  const { data: events } = await res.json();
  if (!events?.length) return;

  // Events are newest-first; process the ones after lastSeenId.
  const fresh = [];
  for (const event of events) {
    if (event.id === lastSeenId) break;
    fresh.push(event);
  }
  if (!fresh.length) return;

  // Pool -> owner lookup (cached per run).
  const poolOwners = new Map();
  const ownerOf = async (poolId) => {
    if (!poolOwners.has(poolId)) {
      const poolRes = await fetch(`${INDEXER_URL}/pools/${poolId}`);
      poolOwners.set(poolId, poolRes.ok ? (await poolRes.json()).owner : null);
    }
    return poolOwners.get(poolId);
  };

  const messaging = getMessaging();
  for (const event of fresh.reverse()) {
    const kind = Object.keys(NOTIFY).find((k) => event.eventType.includes(k));
    if (!kind) continue;
    const owner = await ownerOf(event.poolId);
    if (!owner) continue;

    // Find users who registered this address.
    const accounts = await db
      .collectionGroup("accounts")
      .where("address", "==", owner)
      .get();
    const uids = new Set(accounts.docs.map((d) => d.ref.parent.parent.id));

    for (const uid of uids) {
      const user = (await db.doc(`users/${uid}`).get()).data();
      if (user?.prefs?.notifications === false) continue;
      const tokens = Object.keys(user?.fcmTokens ?? {});
      if (!tokens.length) continue;

      const note = NOTIFY[kind](event);
      const send = await messaging.sendEachForMulticast({
        tokens,
        notification: note,
        data: { poolId: event.poolId, eventType: event.eventType },
      });
      // Prune dead tokens.
      const dead = [];
      send.responses.forEach((r, i) => {
        if (!r.success && r.error?.code?.includes("registration-token")) {
          dead.push(tokens[i]);
        }
      });
      if (dead.length) {
        const update = {};
        for (const t of dead) update[`fcmTokens.${t}`] = null;
        await db.doc(`users/${uid}`).update(update).catch(() => {});
      }
    }
  }

  await stateRef.set({ lastSeenId: events[0].id }, { merge: true });
});
