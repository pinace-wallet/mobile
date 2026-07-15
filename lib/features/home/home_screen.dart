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
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          if (account != null)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(child: AddressPill(address: account.address)),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => invalidateAfterTx(ref),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // ── Owner balance ────────────────────────────────────────────
            Text('Total Balance',
                style: TextStyle(color: PinaceColors.zinc400, fontSize: 13)),
            const SizedBox(height: 4),
            balance.when(
              data: (mist) => Text(
                mist == null ? '—' : '${formatSuiFromMist(mist)} SUI',
                style:
                    const TextStyle(fontSize: 34, fontWeight: FontWeight.w800),
              ),
              loading: () => const Text('...',
                  style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800)),
              error: (e, _) => const Text('—',
                  style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 20),

            // ── Pool card ────────────────────────────────────────────────
            pool.when(
              data: (p) => p == null
                  ? _CreatePoolCard(onCreated: () => invalidateAfterTx(ref))
                  : GradientCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text('Pool Balance',
                                  style: TextStyle(
                                      color: PinaceColors.zinc400,
                                      fontSize: 13)),
                              const Spacer(),
                              StatusChip(
                                label: p.status,
                                color: p.status == 'active'
                                    ? PinaceColors.success
                                    : PinaceColors.warning,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${formatSuiFromMist(p.balanceOf('0x2::sui::SUI'))} SUI',
                            style: const TextStyle(
                                fontSize: 28, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 4),
                          Text(shortenAddress(p.poolId, head: 10, tail: 6),
                              style: const TextStyle(
                                  color: PinaceColors.textMuted, fontSize: 12)),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton(
                                  onPressed: () => showDepositSheet(
                                      context, ref,
                                      poolId: p.poolId),
                                  child: const Text('Add'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => showWithdrawSheet(
                                      context, ref,
                                      poolId: p.poolId,
                                      poolBalance:
                                          p.balanceOf('0x2::sui::SUI')),
                                  child: const Text('Withdraw'),
                                ),
                              ),
                            ],
                          ),
                        ],
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
            const SizedBox(height: 20),

            // ── Stats strip ──────────────────────────────────────────────
            stats.when(
              data: (s) => s == null
                  ? const SizedBox.shrink()
                  : Row(
                      children: [
                        _Stat(label: 'Agents', value: '${s.totalAgents}'),
                        _Stat(label: 'Executing', value: '${s.executingCount}'),
                        _Stat(
                          label: 'Success',
                          value: s.successRate == null
                              ? '—'
                              : '${(s.successRate! * 100).toStringAsFixed(0)}%',
                        ),
                      ],
                    ),
              loading: () => const SizedBox.shrink(),
              error: (e, _) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 24),

            // ── Recent activity ──────────────────────────────────────────
            Row(
              children: [
                const Text('Recent Transactions',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const Spacer(),
                TextButton(
                  onPressed: () => context.go('/activity'),
                  child: const Text('See all'),
                ),
              ],
            ),
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
                  children: [for (final e in items) EventRow(event: e)],
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
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: PinaceColors.zinc900,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(value,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(
                    color: PinaceColors.zinc400, fontSize: 11)),
          ],
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

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: PinaceColors.zinc800,
        child: Icon(icon, size: 18, color: PinaceColors.zinc300),
      ),
      title: Text(label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      subtitle: Text(
        timeAgo(event.time as DateTime),
        style: const TextStyle(color: PinaceColors.textMuted, fontSize: 12),
      ),
      trailing: event.txDigest == ''
          ? null
          : Text(shortenAddress(event.txDigest as String, head: 4, tail: 4),
              style: const TextStyle(
                  color: PinaceColors.textMuted, fontSize: 11)),
    );
  }
}
