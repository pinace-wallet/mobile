import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sui/sui.dart';

import '../features/auth/auth_providers.dart';
import 'firebase/fcm_service.dart';
import 'indexer/indexer_client.dart';
import 'indexer/models.dart';
import 'indexer/sse_client.dart';
import 'pinace/canonical_pool.dart';
import 'pinace/pinace_tx_service.dart';
import 'sui/sui_service.dart';

final indexerProvider = Provider((ref) => IndexerClient());

/// FCM is only usable once Firebase is configured and the user signed in.
final fcmServiceProvider = Provider<FcmService?>((ref) {
  final repo = ref.watch(firestoreRepoProvider);
  return repo == null ? null : FcmService(repo);
});
final suiServiceProvider = Provider((ref) => SuiService());
final pinaceTxProvider =
    Provider((ref) => PinaceTxService(ref.watch(suiServiceProvider)));

/// Signing account for the active wallet account. Loaded on demand; not
/// cached beyond the provider's lifetime.
final activeSignerProvider = FutureProvider<SuiAccount?>((ref) async {
  final keystore = ref.watch(keystoreProvider);
  final active = ref.watch(activeAccountProvider);
  if (keystore == null || active == null) return null;
  return keystore.loadSigner(active.id);
});

/// Canonical pool id for the active account (null => show create-pool CTA).
final canonicalPoolIdProvider = FutureProvider<String?>((ref) async {
  final active = ref.watch(activeAccountProvider);
  if (active == null) return null;
  final resolver = CanonicalPoolResolver(
      ref.watch(indexerProvider), ref.watch(suiServiceProvider));
  return resolver.resolve(active.address);
});

final poolProvider = FutureProvider<Pool?>((ref) async {
  final poolId = await ref.watch(canonicalPoolIdProvider.future);
  if (poolId == null) return null;
  return ref.watch(indexerProvider).getPool(poolId);
});

/// Owner's own SUI balance from the fullnode (not the pool).
final ownerBalanceProvider = FutureProvider<BigInt?>((ref) async {
  final active = ref.watch(activeAccountProvider);
  if (active == null) return null;
  return ref.watch(suiServiceProvider).getSuiBalance(active.address);
});

final ownerStatsProvider = FutureProvider<OwnerStats?>((ref) async {
  final active = ref.watch(activeAccountProvider);
  if (active == null) return null;
  try {
    return await ref.watch(indexerProvider).getOwnerStats(active.address);
  } on IndexerException {
    return null;
  }
});

final agentsProvider = FutureProvider<List<Agent>>((ref) async {
  final active = ref.watch(activeAccountProvider);
  if (active == null) return const [];
  final page =
      await ref.watch(indexerProvider).getAgents(owner: active.address, limit: 50);
  return page.data;
});

final agentDetailProvider =
    FutureProvider.family<Agent, String>((ref, agentId) async {
  return ref.watch(indexerProvider).getAgent(agentId);
});

final agentTimelineProvider =
    FutureProvider.family<AgentTimeline, String>((ref, agentId) async {
  return ref.watch(indexerProvider).getAgentTimeline(agentId);
});

/// Agent's own on-chain SUI (its gas budget).
final agentBalanceProvider =
    FutureProvider.family<BigInt, String>((ref, address) async {
  return ref.watch(suiServiceProvider).getSuiBalance(address);
});

/// Activity feed for the canonical pool.
final poolEventsProvider =
    FutureProvider.family<Paginated<EventLog>?, int>((ref, page) async {
  final poolId = await ref.watch(canonicalPoolIdProvider.future);
  if (poolId == null) return null;
  return ref.watch(indexerProvider).getEvents(poolId: poolId, page: page, limit: 50);
});

/// All coin balances of the active account (Assets screen).
final allBalancesProvider = FutureProvider<List<SuiBalance>>((ref) async {
  final active = ref.watch(activeAccountProvider);
  if (active == null) return const [];
  return ref.watch(suiServiceProvider).getAllBalances(active.address);
});

/// Agent nicknames from Firestore, overlaid on indexer names.
final agentNicknamesProvider = FutureProvider<Map<String, String>>((ref) async {
  final repo = ref.watch(firestoreRepoProvider);
  if (repo == null) return const {};
  try {
    return await repo.getAgentNicknames();
  } catch (_) {
    return const {};
  }
});

/// Live SSE subscription for the active owner. On any event, invalidates the
/// matching data providers so screens refresh within a second of on-chain
/// activity (mirrors useIndexerStream in the extension).
final sseProvider = Provider<IndexerSseClient?>((ref) {
  final active = ref.watch(activeAccountProvider);
  if (active == null) return null;

  final client = IndexerSseClient(owner: active.address);
  final indexer = ref.watch(indexerProvider);

  final sub = client.events.listen((event) {
    indexer.invalidate();
    if (event.touchesPool) {
      ref.invalidate(poolProvider);
      ref.invalidate(canonicalPoolIdProvider);
      ref.invalidate(ownerBalanceProvider);
      ref.invalidate(poolEventsProvider);
    }
    if (event.touchesAgents) {
      ref.invalidate(agentsProvider);
      ref.invalidate(agentDetailProvider);
      ref.invalidate(ownerStatsProvider);
    }
    if (event.touchesActions) {
      ref.invalidate(agentsProvider);
      ref.invalidate(agentDetailProvider);
      ref.invalidate(agentTimelineProvider);
      ref.invalidate(poolEventsProvider);
      ref.invalidate(ownerStatsProvider);
    }
  });
  client.start();

  ref.onDispose(() {
    unawaited(sub.cancel());
    client.dispose();
  });
  return client;
});

/// Invalidate everything after an owner-signed transaction lands.
void invalidateAfterTx(WidgetRef ref) {
  ref.read(indexerProvider).invalidate();
  ref.invalidate(canonicalPoolIdProvider);
  ref.invalidate(poolProvider);
  ref.invalidate(ownerBalanceProvider);
  ref.invalidate(agentsProvider);
  ref.invalidate(agentDetailProvider);
  ref.invalidate(agentTimelineProvider);
  ref.invalidate(poolEventsProvider);
  ref.invalidate(ownerStatsProvider);
  ref.invalidate(allBalancesProvider);
}
