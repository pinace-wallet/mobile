import 'package:sui/sui.dart';

import '../../core/config/env.dart';

/// Thin wrapper around the Sui gRPC client so the rest of the app never
/// depends on transport types directly (JSON-RPC is sunset 2026-07-31;
/// this app uses gRPC-web from day one, like the extension).
class SuiService {
  SuiService() : client = SuiGrpcClient(network: SuiNetwork.testnet);

  final SuiGrpcClient client;

  Future<BigInt> getSuiBalance(String address) async {
    final balance = await client.balanceOf(address);
    return balance.totalBalance;
  }

  /// All coin balances for [address] (Assets screen).
  Future<List<SuiBalance>> getAllBalances(String address) async {
    final res = await client.listBalances(address);
    return res.balances.map(SuiBalance.fromProto).toList();
  }

  /// Object type string, e.g. "<pkg>::balance_pool::BalancePool".
  Future<String?> getObjectType(String objectId) async {
    final info = await client.objectInfo(objectId);
    return info.type;
  }

  /// Signs and executes [tx], waits for finality, and returns the executed
  /// transaction (with effects + changedObjects for created-object parsing).
  Future<({String digest, bool success, String? error, List<({String objectId, String objectType, bool created})> changedObjects})>
      signAndExecute(SuiAccount signer, Transaction tx) async {
    final executed = await client.signAndExecuteTransaction(
      signer,
      tx,
      // 'effects' alone doesn't include changed_objects.object_type — the
      // Sui gRPC API gates that behind an explicit dotted path since it
      // requires a separate type lookup. Without it, poolId parsing in
      // PinaceTxService silently fails (empty objectType never matches).
      readMask: ['digest', 'effects', 'effects.changed_objects.object_type'],
    );
    final status = executed.effects.status;
    final changed = executed.effects.changedObjects
        .map((c) => (
              objectId: c.objectId,
              objectType: c.objectType,
              created: c.idOperation.name == 'CREATED',
            ))
        .toList();
    final digest = executed.digest;
    if (status.success) {
      await client.waitForTransaction(digest);
    }
    return (
      digest: digest,
      success: status.success,
      error: status.hasError() ? status.error.description : null,
      changedObjects: changed,
    );
  }
}

/// Extracts the package id from a Move type like
/// "0xabc...::balance_pool::BalancePool". Returns null when malformed.
String? packageIdFromType(String? type) {
  if (type == null) return null;
  final pkg = type.split('::').first;
  return pkg.startsWith('0x') ? pkg : null;
}

/// True when [type] is a Pinace BalancePool of the current env package.
bool isCurrentPackagePool(String? type) =>
    type != null &&
    type.endsWith('::balance_pool::BalancePool') &&
    packageIdFromType(type) == Env.packageId;
