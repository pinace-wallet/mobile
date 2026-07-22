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
        backgroundColor: Colors.black,
        appBar: AppBar(
          title: const Text('Assets', style: TextStyle(fontFamily: 'SN Pro', fontWeight: FontWeight.w600, color: Colors.white)),
          backgroundColor: Colors.black,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.qr_code, color: Colors.white),
              onPressed: account == null
                  ? null
                  : () => _showReceiveSheet(context, account.address),
            ),
          ],
          bottom: const TabBar(
            indicatorColor: Color(0xFF006FEE),
            labelColor: Colors.white,
            unselectedLabelColor: Color(0xFFA1A1AA),
            labelStyle: TextStyle(fontFamily: 'SN Pro', fontWeight: FontWeight.w600),
            unselectedLabelStyle: TextStyle(fontFamily: 'SN Pro', fontWeight: FontWeight.w400),
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
                        padding: const EdgeInsets.all(16),
                        itemCount: list.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final balance = list[index];
                          final symbol = balance.coinType.split('::').last;
                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: ShapeDecoration(
                              color: const Color(0xFF18181B),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: symbol == 'SUI'
                                      ? const Color(0xFF006FEE).withValues(alpha: 0.2)
                                      : const Color(0xFF3F3F46),
                                  child: Text(
                                    symbol.isEmpty
                                        ? '?'
                                        : symbol.characters.first,
                                    style: TextStyle(
                                        fontFamily: 'SN Pro',
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: symbol == 'SUI' ? const Color(0xFF006FEE) : Colors.white),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(symbol,
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontFamily: 'SN Pro',
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600)),
                                      Text(
                                        shortenAddress(balance.coinType,
                                            head: 8, tail: 12),
                                        style: const TextStyle(
                                            color: Color(0xFFA1A1AA),
                                            fontFamily: 'SN Pro',
                                            fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  formatSuiFromMist(balance.totalBalance),
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontFamily: 'SN Pro',
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600),
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
          const SizedBox(height: 24),
          AddressPill(address: address, label: address),
          const SizedBox(height: 12),
          const Text(
            'Sui Testnet',
            style: TextStyle(color: Color(0xFFA1A1AA), fontSize: 14, fontFamily: 'SN Pro'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
