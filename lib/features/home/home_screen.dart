import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/widgets.dart';
import '../../data/pinace/canonical_pool.dart';
import '../../data/providers.dart';
import '../auth/auth_providers.dart';
import 'pool_sheets.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(activeAccountProvider);
    final balance = ref.watch(ownerBalanceProvider);
    final pool = ref.watch(poolProvider);
    final stats = ref.watch(ownerStatsProvider);
    final events = ref.watch(poolEventsProvider(1));

    return Scaffold(
      backgroundColor: Colors.black, // From Figma
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => invalidateAfterTx(ref),
          child: ListView(
            padding: const EdgeInsets.only(
              top: 16,
              left: 16,
              right: 14,
              bottom: 25,
            ),
            children: [
              // ── Top Row ────────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    height: 28,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: ShapeDecoration(
                      color: const Color(0xFF3F3F46),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9999),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Testnet',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontFamily: 'SN Pro',
                            fontWeight: FontWeight.w400,
                            height: 1.43,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (account != null)
                        AddressPill(address: account.address),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── Owner balance ────────────────────────────────────────────
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total Balance',
                    style: TextStyle(
                      color: const Color(0xFFA1A1AA),
                      fontSize: 16,
                      fontFamily: 'SN Pro',
                      fontWeight: FontWeight.w400,
                      height: 1.50,
                    ),
                  ),
                  const SizedBox(height: 8),
                  balance.when(
                    data: (mist) {
                      final val = mist == null ? '0.00' : formatSuiFromMist(mist);
                      return Text(
                        '$val SUI',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 48,
                          fontFamily: 'SN Pro',
                          fontWeight: FontWeight.w700,
                          height: 1,
                        ),
                      );
                    },
                    loading: () => Text(
                      '...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 48,
                        fontFamily: 'SN Pro',
                        fontWeight: FontWeight.w700,
                        height: 1,
                      ),
                    ),
                    error: (e, _) => Text(
                      '—',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 48,
                        fontFamily: 'SN Pro',
                        fontWeight: FontWeight.w700,
                        height: 1,
                      ),
                    ),
                  ),
                  // Figma +$2.47 stub
                  const SizedBox(height: 8),
                  Text(
                    '+\$2.47 (Figma Mock)',
                    style: TextStyle(
                      color: const Color(0xFF17C964),
                      fontSize: 14,
                      fontFamily: 'SN Pro',
                      fontWeight: FontWeight.w400,
                      height: 1.43,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── Pool card ────────────────────────────────────────────────
              pool.when(
                data: (p) => p == null
                    ? _CreatePoolCard(onCreated: () => invalidateAfterTx(ref))
                    : Container(
                        padding: const EdgeInsets.all(8),
                        decoration: ShapeDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment(0.02, 0.07),
                            end: Alignment(0.98, 0.97),
                            colors: [Color(0xFF18181B), Color(0xFF0C1F34)],
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        child: IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                clipBehavior: Clip.antiAlias,
                                decoration: ShapeDecoration(
                                  color: const Color(0xFF006FEE),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Pool Balance',
                                      style: TextStyle(
                                        color: const Color(0xFF001731),
                                        fontSize: 20,
                                        fontFamily: 'SN Pro',
                                        fontWeight: FontWeight.w600,
                                        height: 1.33,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      '${formatSuiFromMist(p.balanceOf('0x2::sui::SUI'))} SUI',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 22,
                                        fontFamily: 'SN Pro',
                                        fontWeight: FontWeight.w600,
                                        height: 1.33,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Add or withdraw',
                                      style: TextStyle(
                                        color: const Color(0xFFA1A1AA),
                                        fontSize: 12,
                                        fontFamily: 'SN Pro',
                                        fontWeight: FontWeight.w400,
                                        height: 1.33,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      'Pool balance help Pinace interact with',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontFamily: 'SN Pro',
                                        fontWeight: FontWeight.w400,
                                        height: 1.50,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    GestureDetector(
                                      onTap: () => showDepositSheet(
                                          context, ref, poolId: p.poolId),
                                      child: Container(
                                        height: 40,
                                        padding: const EdgeInsets.symmetric(horizontal: 16),
                                        decoration: ShapeDecoration(
                                          color: const Color(0xFFFAFAFA),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(9999),
                                          ),
                                        ),
                                        child: Center(
                                          child: Text(
                                            'Add balance',
                                            style: TextStyle(
                                              color: const Color(0xFF27272A),
                                              fontSize: 14,
                                              fontFamily: 'SN Pro',
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        ),
                      ),
                loading: () => const GradientCard(
                  child: SizedBox(
                      height: 120,
                      child: Center(child: CircularProgressIndicator())),
                ),
                error: (e, _) => GradientCard(
                  child: Text('Pool unavailable: $e',
                      style: const TextStyle(color: PinaceColors.zinc400)),
                ),
              ),
              const SizedBox(height: 24),

              // ── Recent activity ──────────────────────────────────────────
              Row(
                children: [
                  Text(
                    'Transactions',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontFamily: 'SN Pro',
                      fontWeight: FontWeight.w600,
                      height: 1.56,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => context.go('/activity'),
                    child: const Text('See all'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              events.when(
                data: (page) {
                  final items = page?.data.take(5).toList() ?? const [];
                  if (items.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Text('No activity yet',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: PinaceColors.textMuted)),
                    );
                  }
                  return Column(
                    children: [
                      for (final e in items)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: ShapeDecoration(
                              color: const Color(0xFF18181B),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: EventRow(event: e), // Wrap the internal design
                          ),
                        )
                    ],
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreatePoolCard extends ConsumerStatefulWidget {
  const _CreatePoolCard({required this.onCreated});

  final VoidCallback onCreated;

  @override
  ConsumerState<_CreatePoolCard> createState() => _CreatePoolCardState();
}

class _CreatePoolCardState extends ConsumerState<_CreatePoolCard> {
  bool _busy = false;

  Future<void> _create() async {
    setState(() => _busy = true);
    try {
      final signer = await ref.read(activeSignerProvider.future);
      if (signer == null) throw Exception('No active account');
      final result = await ref.read(pinaceTxProvider).createPool(signer);
      if (result.poolId != null) {
        await CanonicalPoolResolver.savePoolId(
            signer.getAddress(), result.poolId!);
      }
      widget.onCreated();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Pool created')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Create pool failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GradientCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('No pool yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text(
            'Create an escrow pool to deposit SUI and delegate bounded '
            'execution to agents.',
            style: TextStyle(color: PinaceColors.zinc400, fontSize: 13),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _create,
            child: Text(_busy ? 'Creating...' : 'Create pool'),
          ),
        ],
      ),
    );
  }
}

/// Shared event row used by Home + Activity.
class EventRow extends StatelessWidget {
  const EventRow({super.key, required this.event});

  final dynamic event; // EventLog

  static const _labels = {
    'PoolCreatedEvent': ('Pool created', Icons.add_circle_outline),
    'DepositEvent': ('Deposit', Icons.arrow_downward),
    'WithdrawEvent': ('Withdraw', Icons.arrow_upward),
    'AgentConnectedEvent': ('Agent connected', Icons.link),
    'AgentRevokedEvent': ('Agent revoked', Icons.link_off),
    'PolicyAttachedEvent': ('Policy attached', Icons.shield_outlined),
    'PolicyUpdatedEvent': ('Policy updated', Icons.shield_outlined),
    'PolicyRemovedEvent': ('Policy removed', Icons.remove_moderator_outlined),
    'ActionProposedEvent': ('Action proposed', Icons.pending_outlined),
    'ActionSettledEvent': ('Action settled', Icons.check_circle_outline),
  };

  @override
  Widget build(BuildContext context) {
    final key = _labels.keys.firstWhere(
      (k) => (event.eventType as String).contains(k),
      orElse: () => '',
    );
    final (label, icon) = key.isEmpty
        ? (event.eventType as String, Icons.bolt)
        : _labels[key]!;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontFamily: 'Plus Jakarta Sans',
                fontWeight: FontWeight.w600,
                height: 1.50,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              timeAgo(event.time as DateTime),
              style: TextStyle(
                color: Colors.white.withOpacity(0.40),
                fontSize: 14,
                fontFamily: 'Plus Jakarta Sans',
                fontWeight: FontWeight.w400,
                height: 1.43,
              ),
            ),
          ],
        ),
        if (event.txDigest != '')
          Text(
            shortenAddress(event.txDigest as String, head: 4, tail: 4),
            style: TextStyle(
              color: PinaceColors.textMuted,
              fontSize: 12,
            ),
          ),
      ],
    );
  }
}
