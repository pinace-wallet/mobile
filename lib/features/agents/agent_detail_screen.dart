import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/colors.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/widgets.dart';
import '../../data/indexer/models.dart';
import '../../data/providers.dart';
import '../home/home_screen.dart' show EventRow;
import 'policy_sheet.dart';

class AgentDetailScreen extends ConsumerWidget {
  const AgentDetailScreen({super.key, required this.agentId});

  final String agentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agent = ref.watch(agentDetailProvider(agentId));
    final timeline = ref.watch(agentTimelineProvider(agentId));

    return Scaffold(
      appBar: AppBar(title: const Text('Agent')),
      body: agent.when(
        data: (a) => RefreshIndicator(
          onRefresh: () async {
            ref.read(indexerProvider).invalidate();
            ref.invalidate(agentDetailProvider(agentId));
            ref.invalidate(agentTimelineProvider(agentId));
            ref.invalidate(agentBalanceProvider(a.address));
          },
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _Header(agent: a),
              const SizedBox(height: 20),
              _BudgetCard(agent: a),
              const SizedBox(height: 20),
              _PoliciesSection(agent: a),
              const SizedBox(height: 20),
              if (!a.isRevoked) _RevokeSection(agent: a),
              const SizedBox(height: 20),
              const Text('History',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              timeline.when(
                data: (t) => t.events.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Text('No activity yet',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: PinaceColors.textMuted)),
                      )
                    : Column(
                        children: [
                          for (final e in t.events.reversed.take(25))
                            EventRow(event: e),
                        ],
                      ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => const SizedBox.shrink(),
              ),
            ],
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(
          message: '$e',
          onRetry: () => ref.invalidate(agentDetailProvider(agentId)),
        ),
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.agent});

  final Agent agent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nicknames = ref.watch(agentNicknamesProvider).valueOrNull ?? const {};
    final displayName = nicknames[agent.id] ??
        (agent.name == agent.address ? shortenAddress(agent.address) : agent.name);
    final expiry = dateTimeFromEpochMs(agent.expiresMs);

    return GradientCard(
      radius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w800)),
              ),
              StatusChip.agent(agent.status, runStatus: agent.runStatus),
            ],
          ),
          const SizedBox(height: 8),
          AddressPill(address: agent.address),
          const SizedBox(height: 12),
          Text(
            agent.isRevoked
                ? 'Revoked ${agent.revokedAt != null ? timeAgo(dateTimeFromEpochMs(agent.revokedAt!)) : ''}'
                : 'Delegation expires ${expiry.isAfter(DateTime.now()) ? 'in ${expiry.difference(DateTime.now()).inDays}d' : '(expired)'}',
            style: const TextStyle(color: PinaceColors.zinc400, fontSize: 12),
          ),
          const SizedBox(height: 4),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: const Icon(Icons.edit, size: 16, color: PinaceColors.zinc400),
            onPressed: () => _renameDialog(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _renameDialog(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nickname'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Save')),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      await ref.read(firestoreRepoProvider)?.setAgentNickname(agent.id, name);
      ref.invalidate(agentNicknamesProvider);
    }
  }
}

class _BudgetCard extends ConsumerWidget {
  const _BudgetCard({required this.agent});

  final Agent agent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balance = ref.watch(agentBalanceProvider(agent.address));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PinaceColors.zinc900,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Icon(Icons.local_gas_station_outlined,
              color: PinaceColors.cyan),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('Agent gas budget',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          ),
          balance.when(
            data: (mist) => Text('${formatSuiFromMist(mist)} SUI',
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700)),
            loading: () => const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2)),
            error: (e, _) => const Text('—'),
          ),
        ],
      ),
    );
  }
}

class _PoliciesSection extends ConsumerWidget {
  const _PoliciesSection({required this.agent});

  final Agent agent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spendingLimit = (agent.policies ?? const <AgentPolicy>[])
        .where((p) => p.isSpendingLimit && p.status == 'attached')
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Policies',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const Spacer(),
            if (!agent.isRevoked && spendingLimit.isEmpty)
              TextButton.icon(
                onPressed: () => showSpendingLimitSheet(context, ref,
                    agent: agent, existing: null),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add limit'),
              ),
          ],
        ),
        if (spendingLimit.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: PinaceColors.warning.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: PinaceColors.warning.withValues(alpha: 0.4)),
            ),
            child: const Text(
              'No spending limit attached — this agent can spend the whole '
              'pool balance. Add a limit to bound it on-chain.',
              style: TextStyle(color: PinaceColors.warning, fontSize: 13),
            ),
          )
        else
          for (final policy in spendingLimit)
            _SpendingLimitCard(agent: agent, policy: policy),
      ],
    );
  }
}

class _SpendingLimitCard extends ConsumerWidget {
  const _SpendingLimitCard({required this.agent, required this.policy});

  final Agent agent;
  final AgentPolicy policy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final maxPerTx = policy.configValue('max_per_tx');
    final maxPerWindow = policy.configValue('max_per_window');
    final windowMs = policy.configValue('window_ms');
    final spent = policy.configValue('spent_in_window') ?? BigInt.zero;
    final progress = maxPerWindow == null || maxPerWindow == BigInt.zero
        ? 0.0
        : (spent.toDouble() / maxPerWindow.toDouble()).clamp(0.0, 1.0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PinaceColors.zinc900,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shield_outlined,
                  size: 18, color: PinaceColors.success),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Spending limit',
                    style:
                        TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              ),
              if (!agent.isRevoked) ...[
                IconButton(
                  icon: const Icon(Icons.edit, size: 18),
                  onPressed: () => showSpendingLimitSheet(context, ref,
                      agent: agent, existing: policy),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      size: 18, color: PinaceColors.danger),
                  onPressed: () => removeSpendingLimit(context, ref, agent),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          if (maxPerTx != null)
            _row('Per transaction', '${formatSuiFromMist(maxPerTx)} SUI'),
          if (maxPerWindow != null)
            _row('Per window', '${formatSuiFromMist(maxPerWindow)} SUI'),
          if (windowMs != null)
            _row('Window', _windowLabel(windowMs.toInt())),
          if (maxPerWindow != null) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: PinaceColors.zinc800,
                color: progress > 0.85
                    ? PinaceColors.danger
                    : PinaceColors.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${formatSuiFromMist(spent)} / ${formatSuiFromMist(maxPerWindow)} SUI spent in window',
              style:
                  const TextStyle(color: PinaceColors.textMuted, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Text(label,
                style: const TextStyle(
                    color: PinaceColors.zinc400, fontSize: 13)),
            const Spacer(),
            Text(value,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
      );

  String _windowLabel(int ms) {
    if (ms >= 3600000) return '${ms ~/ 3600000}h';
    if (ms >= 60000) return '${ms ~/ 60000}m';
    return '${ms ~/ 1000}s';
  }
}

class _RevokeSection extends ConsumerStatefulWidget {
  const _RevokeSection({required this.agent});

  final Agent agent;

  @override
  ConsumerState<_RevokeSection> createState() => _RevokeSectionState();
}

class _RevokeSectionState extends ConsumerState<_RevokeSection> {
  bool _busy = false;

  Future<void> _revoke() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Revoke agent?'),
        content: const Text(
            'This is a one-way kill switch. The agent will permanently lose '
            'access to your pool; any in-flight action will revert on-chain.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: PinaceColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Revoke'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      final signer = await ref.read(activeSignerProvider.future);
      if (signer == null) throw Exception('No active account');
      await ref.read(pinaceTxProvider).revokeAgent(
            signer,
            poolId: widget.agent.poolId,
            agentAddress: widget.agent.address,
          );
      invalidateAfterTx(ref);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Agent revoked')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Revoke failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: PinaceColors.danger,
        side: const BorderSide(color: PinaceColors.danger),
      ),
      onPressed: _busy ? null : _revoke,
      icon: const Icon(Icons.power_settings_new),
      label: Text(_busy ? 'Revoking...' : 'Revoke agent'),
    );
  }
}
