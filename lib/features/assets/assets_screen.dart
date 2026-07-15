import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/theme/colors.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/widgets.dart';
import '../../data/providers.dart';
import '../auth/auth_providers.dart';

class AssetsScreen extends ConsumerWidget {
  const AssetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balances = ref.watch(allBalancesProvider);
    final account = ref.watch(activeAccountProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Assets'),
          actions: [
            IconButton(
              icon: const Icon(Icons.qr_code),
              onPressed: account == null
                  ? null
                  : () => _showReceiveSheet(context, account.address),
            ),
          ],
          bottom: const TabBar(
            indicatorColor: PinaceColors.cyan,
            labelColor: Colors.white,
            unselectedLabelColor: PinaceColors.zinc400,
            tabs: [Tab(text: 'Tokens'), Tab(text: 'NFTs')],
          ),
        ),
        body: TabBarView(
          children: [
            RefreshIndicator(
              onRefresh: () async => ref.invalidate(allBalancesProvider),
              child: balances.when(
                data: (list) => list.isEmpty
                    ? ListView(children: const [
                        SizedBox(height: 120),
                        EmptyState(
                          icon: Icons.token_outlined,
                          title: 'No tokens yet',
                          subtitle:
                              'Fund this address from the Sui testnet faucet to get started.',
                        ),
                      ])
                    : ListView.separated(
                        padding: const EdgeInsets.all(20),
                        itemCount: list.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final balance = list[index];
                          final symbol =
                              balance.coinType.split('::').last;
                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: PinaceColors.zinc900,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: symbol == 'SUI'
                                      ? PinaceColors.primary
                                          .withValues(alpha: 0.2)
                                      : PinaceColors.zinc800,
                                  child: Text(
                                    symbol.isEmpty
                                        ? '?'
                                        : symbol.characters.first,
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: PinaceColors.cyan),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(symbol,
                                          style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700)),
                                      Text(
                                        shortenAddress(balance.coinType,
                                            head: 8, tail: 12),
                                        style: const TextStyle(
                                            color: PinaceColors.textMuted,
                                            fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  formatSuiFromMist(balance.totalBalance),
                                  style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => ErrorState(
                  message: '$e',
                  onRetry: () => ref.invalidate(allBalancesProvider),
                ),
              ),
            ),
            const EmptyState(
              icon: Icons.image_outlined,
              title: 'NFTs coming soon',
              subtitle: 'NFT display is on the roadmap, matching the extension.',
            ),
          ],
        ),
      ),
    );
  }

  void _showReceiveSheet(BuildContext context, String address) {
    showPinaceSheet(
      context: context,
      title: 'Receive',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: QrImageView(
              data: address,
              size: 200,
              backgroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          AddressPill(address: address, label: address),
          const SizedBox(height: 8),
          const Text(
            'Sui Testnet',
            style: TextStyle(color: PinaceColors.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
