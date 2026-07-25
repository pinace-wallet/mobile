import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/env.dart';
import '../indexer/indexer_client.dart';
import '../sui/sui_service.dart';

/// Port of Frontend/lib/pinace/canonicalPool.ts — "which pool is THE pool
/// for this owner". Candidates come from (a) the owner's agents in the
/// indexer and (b) the locally saved pool from a createPool on this device
/// (a fresh pool with no agents is invisible to the indexer-agents path).
/// Pools from older package deploys are ignored; the richest SUI balance
/// wins. Returns null when the owner has no usable pool (=> create-pool CTA).
class CanonicalPoolResolver {
  CanonicalPoolResolver(this._indexer, this._sui);

  final IndexerClient _indexer;
  final SuiService _sui;

  static String _savedKey(String owner) => 'pinace.pool.$owner';

  static Future<void> savePoolId(String owner, String poolId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_savedKey(owner), poolId);
  }

  Future<String?> resolve(String owner) async {
    final poolIds = <String>{};

    try {
      final agents = await _indexer.getAgents(owner: owner, limit: 100);
      for (final agent in agents.data) {
        if (agent.poolId.isNotEmpty) poolIds.add(agent.poolId);
      }
    } catch (_) {
      // Indexer outage is non-fatal; fall through to the saved pool.
    }

    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_savedKey(owner));
    if (saved != null && saved.isNotEmpty) poolIds.add(saved);

    String? best;
    BigInt bestBalance = BigInt.from(-1);
    for (final poolId in poolIds) {
      // On-chain existence + package match is authoritative — if this
      // fails, the pool genuinely isn't usable, so skip it.
      String? type;
      try {
        type = await _sui.getObjectType(poolId);
      } catch (_) {
        continue;
      }
      if (type == null || packageIdFromType(type) != Env.packageId) continue;

      // The indexer's balance is only a display nicety — if it's down or
      // hasn't caught up, keep the candidate with an unknown (0) balance
      // rather than dropping an otherwise-valid, on-chain-verified pool.
      BigInt sui = BigInt.zero;
      try {
        final pool = await _indexer.getPool(poolId);
        sui = pool.balances
            .where((b) => b.coinType.contains('::sui::SUI'))
            .fold(BigInt.zero, (sum, b) => sum + b.amountMist);
      } catch (_) {
        // indexer unavailable — balance stays unknown, pool still valid
      }
      if (sui > bestBalance) {
        bestBalance = sui;
        best = poolId;
      }
    }
    return best;
  }
}
