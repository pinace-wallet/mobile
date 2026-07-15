import 'dart:convert';

import 'package:sui/sui.dart';

import '../../core/config/env.dart';
import '../sui/sui_service.dart';

class PinaceTxException implements Exception {
  PinaceTxException(this.message, {this.digest});

  final String message;
  final String? digest;

  @override
  String toString() => message;
}

class PinaceTxResult {
  const PinaceTxResult({required this.digest, this.poolId});

  final String digest;
  final String? poolId;
}

/// Owner-side Pinace PTBs, ported from
/// Frontend/entrypoints/background/pinace/operations.ts and
/// pinace-sdk/packages/core/src/ptb/*.
///
/// Move ground truth: contracts/core/sources/balance_pool.move. Note that
/// connect/revoke/attach/update/remove all take a trailing `&Clock` — the TS
/// contracts-sdk appends it implicitly, here we pass `0x6` explicitly.
class PinaceTxService {
  PinaceTxService(this._sui);

  final SuiService _sui;

  String get _pkg => Env.packageId;

  Map<String, dynamic> _clock(Transaction tx) => tx.object(Env.clockObjectId);

  Future<PinaceTxResult> _execute(
    SuiAccount signer,
    Transaction tx, {
    bool parsePoolId = false,
  }) async {
    tx.setSenderIfNotSet(signer.getAddress());
    final result = await _sui.signAndExecute(signer, tx);
    if (!result.success) {
      throw PinaceTxException(
        result.error ?? 'Transaction failed on chain.',
        digest: result.digest,
      );
    }
    String? poolId;
    if (parsePoolId) {
      for (final obj in result.changedObjects) {
        if (obj.created &&
            obj.objectType.endsWith('::balance_pool::BalancePool')) {
          poolId = obj.objectId;
          break;
        }
      }
    }
    return PinaceTxResult(digest: result.digest, poolId: poolId);
  }

  /// balance_pool::create — new escrow pool owned by the signer.
  Future<PinaceTxResult> createPool(SuiAccount owner) {
    final tx = Transaction();
    tx.moveCall('$_pkg::balance_pool::create');
    return _execute(owner, tx, parsePoolId: true);
  }

  /// balance_pool::deposit<T> — escrow [amountMist] from the gas coin.
  /// Uses the pool's runtime package to avoid the TypeMismatch drift trap.
  Future<PinaceTxResult> depositToPool(
    SuiAccount owner, {
    required String poolId,
    required BigInt amountMist,
    String coinType = Env.suiCoinType,
  }) async {
    final pkg = await _resolvePoolPackageId(poolId);
    final tx = Transaction();
    final coin = tx.splitCoins(tx.gas, [tx.pureInt(amountMist.toInt())]);
    tx.moveCall(
      '$pkg::balance_pool::deposit',
      arguments: [tx.object(poolId), coin[0]],
      typeArguments: [coinType],
    );
    return _execute(owner, tx);
  }

  /// balance_pool::owner_withdraw<T> — returns Coin<T>, transferred back
  /// to the owner in the same PTB.
  Future<PinaceTxResult> withdrawFromPool(
    SuiAccount owner, {
    required String poolId,
    required BigInt amountMist,
    String coinType = Env.suiCoinType,
  }) async {
    final pkg = await _resolvePoolPackageId(poolId);
    final tx = Transaction();
    final coin = tx.moveCall(
      '$pkg::balance_pool::owner_withdraw',
      arguments: [tx.object(poolId), tx.pureInt(amountMist.toInt())],
      typeArguments: [coinType],
    );
    tx.transferObjects([coin], tx.pureAddress(owner.getAddress()));
    return _execute(owner, tx);
  }

  /// balance_pool::connect_agent + fund the agent 1 SUI for its own gas
  /// (same PTB), mirroring the extension's setupAgentOnPool. Attaches no
  /// policies — the owner adds a spending limit afterwards.
  Future<PinaceTxResult> connectAgent(
    SuiAccount owner, {
    required String poolId,
    required String agentAddress,
    Duration expiry = const Duration(days: Env.agentExpiryDays),
    bool fundGas = true,
  }) {
    final expiresMs = DateTime.now().add(expiry).millisecondsSinceEpoch;
    final tx = Transaction();
    tx.moveCall(
      '$_pkg::balance_pool::connect_agent',
      arguments: [
        tx.object(poolId),
        tx.pureAddress(agentAddress),
        tx.pureInt(expiresMs),
        _clock(tx),
      ],
    );
    if (fundGas) {
      final gasCoin =
          tx.splitCoins(tx.gas, [tx.pureInt(Env.agentGasFundMist.toInt())]);
      tx.transferObjects([gasCoin[0]], tx.pureAddress(agentAddress));
    }
    return _execute(owner, tx);
  }

  /// balance_pool::revoke_agent — one-way kill switch.
  Future<PinaceTxResult> revokeAgent(
    SuiAccount owner, {
    required String poolId,
    required String agentAddress,
    String reason = 'user-revoked-via-mobile',
  }) {
    final tx = Transaction();
    tx.moveCall(
      '$_pkg::balance_pool::revoke_agent',
      arguments: [
        tx.object(poolId),
        tx.pureAddress(agentAddress),
        tx.pureVector(utf8.encode(reason), 'u8'),
        _clock(tx),
      ],
    );
    return _execute(owner, tx);
  }

  String get _spendingLimitWitness => '$_pkg::spending_limit_policy::Witness';
  String get _spendingLimitConfig => '$_pkg::spending_limit_policy::Config';

  /// spending_limit_policy::new_config + balance_pool::attach_policy
  /// (or update_policy when [update] is true) in one PTB.
  Future<PinaceTxResult> setSpendingLimit(
    SuiAccount owner, {
    required String poolId,
    required String agentAddress,
    required BigInt maxPerTx,
    required BigInt maxPerWindow,
    required Duration window,
    bool update = false,
  }) {
    final tx = Transaction();
    final config = tx.moveCall(
      '$_pkg::spending_limit_policy::new_config',
      arguments: [
        tx.pureInt(maxPerTx.toInt()),
        tx.pureInt(maxPerWindow.toInt()),
        tx.pureInt(window.inMilliseconds),
      ],
    );
    tx.moveCall(
      '$_pkg::balance_pool::${update ? 'update_policy' : 'attach_policy'}',
      arguments: [
        tx.object(poolId),
        tx.pureAddress(agentAddress),
        config,
        tx.pureVector(utf8.encode(update ? 'mobile-sl-update' : 'mobile-sl-attach'), 'u8'),
        tx.pureVector(const <int>[], 'u8'),
        _clock(tx),
      ],
      typeArguments: [_spendingLimitWitness, _spendingLimitConfig],
    );
    return _execute(owner, tx);
  }

  /// balance_pool::remove_policy for the spending-limit policy.
  Future<PinaceTxResult> removeSpendingLimit(
    SuiAccount owner, {
    required String poolId,
    required String agentAddress,
  }) {
    final tx = Transaction();
    tx.moveCall(
      '$_pkg::balance_pool::remove_policy',
      arguments: [
        tx.object(poolId),
        tx.pureAddress(agentAddress),
        _clock(tx),
      ],
      typeArguments: [_spendingLimitWitness, _spendingLimitConfig],
    );
    return _execute(owner, tx);
  }

  /// Reads the pool object's on-chain type and extracts its actual package
  /// ("<pkg>::balance_pool::BalancePool"). A pool created by an older package
  /// must be called through that package or the tx aborts with TypeMismatch.
  /// Falls back to the env package id if the lookup fails.
  Future<String> _resolvePoolPackageId(String poolId) async {
    try {
      final type = await _sui.getObjectType(poolId);
      final pkg = packageIdFromType(type);
      if (pkg != null) return pkg;
    } catch (_) {
      // fall through to env package
    }
    return _pkg;
  }
}
