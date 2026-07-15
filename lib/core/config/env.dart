/// App-wide environment configuration.
///
/// Values can be overridden at build time, e.g.
/// `flutter run --dart-define=INDEXER_URL=https://indexer.pinace.xyz`
abstract final class Env {
  /// Read-only Pinace event indexer (REST + SSE). No auth required.
  static const indexerUrl = String.fromEnvironment(
    'INDEXER_URL',
    defaultValue: 'http://54.80.234.72:3001',
  );

  /// Deployed Pinace `core` Move package on testnet.
  /// Mirrors PACKAGE_IDS.testnet in pinace-sdk/packages/core/src/constants.ts.
  static const packageId = String.fromEnvironment(
    'PINACE_PACKAGE_ID',
    defaultValue:
        '0x5be5ab0292590e61e2dc21d11cc7174970f48e5ff54c88d4797c81b2a751a23b',
  );

  static const suiCoinType = '0x2::sui::SUI';

  /// Shared Clock object required by connect/revoke/attach/update/remove.
  static const clockObjectId = '0x6';

  /// Rough gas headroom kept out of "max" amounts, same convention as the
  /// extension (Frontend/lib/pinace/constants.ts).
  static final gasBufferMist = BigInt.from(15000000);

  /// SUI transferred to a newly connected agent so it can pay its own gas.
  static final agentGasFundMist = BigInt.from(1000000000); // 1 SUI

  /// Default delegation lifetime when connecting an agent.
  static const agentExpiryDays = 30;

  static const explorerBase = 'https://suiscan.xyz/testnet';

  static String explorerTxUrl(String digest) => '$explorerBase/tx/$digest';
  static String explorerObjectUrl(String id) => '$explorerBase/object/$id';
}
