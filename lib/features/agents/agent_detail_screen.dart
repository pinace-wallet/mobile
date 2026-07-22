import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/colors.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/widgets.dart';
import '../../data/indexer/models.dart';
import '../../data/providers.dart';
import '../auth/auth_providers.dart';
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
      backgroundColor: Colors.black, // Figma theme
      appBar: AppBar(
        title: const Text('Agent Details', style: TextStyle(fontFamily: 'SN Pro')),
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: agent.when(
        data: (a) => RefreshIndicator(
          onRefresh: () async {
            ref.read(indexerProvider).invalidate();
            ref.invalidate(agentDetailProvider(agentId));
            ref.invalidate(agentTimelineProvider(agentId));
            ref.invalidate(agentBalanceProvider(a.address));
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _Header(agent: a),
              const SizedBox(height: 24),
              _BudgetCard(agent: a),
              const SizedBox(height: 24),
              _PoliciesSection(agent: a),
              const SizedBox(height: 24),
              if (!a.isRevoked) _RevokeSection(agent: a),
              const SizedBox(height: 24),
              Text(
                'History',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontFamily: 'SN Pro',
                  fontWeight: FontWeight.w600,
                  height: 1.56,
                ),
              ),
              const SizedBox(height: 12),
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
                                child: EventRow(event: e),
                              ),
                            ),
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
    final nicknames = ref.watch(agentNicknamesProvider).value ?? const {};
    final displayName = nicknames[agent.id] ??
        (agent.name == agent.address ? shortenAddress(agent.address) : agent.name);
    final expiry = dateTimeFromEpochMs(agent.expiresMs);

    final bool isRunning = agent.status == 'active' && agent.runStatus == 'running';
    final bool isDone = agent.status == 'active' && agent.runStatus == 'done';
    final Color statusColor = isRunning ? const Color(0xFFF5A524) : (isDone ? const Color(0xFF17C964) : Colors.grey);
    final String statusText = isRunning ? 'Running' : (isDone ? 'Done' : agent.status);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: ShapeDecoration(
        color: const Color(0xFF18181B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontFamily: 'SN Pro',
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                height: 28,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: ShapeDecoration(
                  color: statusColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9999),
                  ),
                ),
                child: Center(
                  child: Text(
                    statusText,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 14,
                      fontFamily: 'SN Pro',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AddressPill(address: agent.address),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                agent.isRevoked
                    ? 'Revoked ${agent.revokedAt != null ? timeAgo(dateTimeFromEpochMs(agent.revokedAt!)) : ''}'
                    : 'Delegation expires ${expiry.isAfter(DateTime.now()) ? 'in ${expiry.difference(DateTime.now()).inDays}d' : '(expired)'}',
                style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 13, fontFamily: 'SN Pro'),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.edit, size: 20, color: Color(0xFFA1A1AA)),
                onPressed: () => _renameDialog(context, ref),
              ),
            ],
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
                    const Text(
                      'Budget',
                      style: TextStyle(
                        color: Color(0xFF001731),
                        fontSize: 24,
                        fontFamily: 'SN Pro',
                        fontWeight: FontWeight.w600,
                        height: 1.33,
                      ),
                    ),
                    const SizedBox(height: 16),
                    balance.when(
                      data: (mist) => Text(
                        '${formatSuiFromMist(mist)} SUI',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontFamily: 'SN Pro',
                          fontWeight: FontWeight.w600,
                          height: 1.33,
                        ),
                      ),
                      loading: () => const Text('...', style: TextStyle(color: Colors.white, fontSize: 24)),
                      error: (e, _) => const Text('—', style: TextStyle(color: Colors.white, fontSize: 24)),
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
                    const Text(
                      'Add or withdraw',
                      style: TextStyle(
                        color: Color(0xFFA1A1AA),
                        fontSize: 12,
                        fontFamily: 'SN Pro',
                        fontWeight: FontWeight.w400,
                        height: 1.33,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Budget cap of agent',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontFamily: 'SN Pro',
                        fontWeight: FontWeight.w400,
                        height: 1.50,
                      ),
                    ),
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: () {
                        // TODO: trigger deposit/withdraw for agent
                      },
                      child: Container(
                        height: 40,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: ShapeDecoration(
                          color: const Color(0xFFFAFAFA),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(9999),
                          ),
                        ),
                        child: const Center(
                          child: Text(
                            'Add balance',
                            style: TextStyle(
                              color: Color(0xFF27272A),
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
            const Text(
              'Policies',
              style: TextStyle(color: Colors.white, fontSize: 18, fontFamily: 'SN Pro', fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            if (!agent.isRevoked && spendingLimit.isEmpty)
              TextButton.icon(
                onPressed: () => showSpendingLimitSheet(context, ref,
                    agent: agent, existing: null),
                icon: const Icon(Icons.add, size: 16, color: Color(0xFF006FEE)),
                label: const Text('Add limit', style: TextStyle(color: Color(0xFF006FEE), fontFamily: 'SN Pro')),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (spendingLimit.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF5A524).withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFF5A524).withOpacity(0.4)),
            ),
            child: const Text(
              'No spending limit attached — this agent can spend the whole '
              'pool balance. Add a limit to bound it on-chain.',
              style: TextStyle(color: Color(0xFFF5A524), fontSize: 14, fontFamily: 'SN Pro'),
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
        color: const Color(0xFF18181B),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shield_outlined, size: 20, color: Color(0xFF17C964)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Spending limit',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontFamily: 'SN Pro', fontWeight: FontWeight.w600),
                ),
              ),
              if (!agent.isRevoked) ...[
                IconButton(
                  icon: const Icon(Icons.edit, size: 18, color: Color(0xFFA1A1AA)),
                  onPressed: () => showSpendingLimitSheet(context, ref,
                      agent: agent, existing: policy),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFF31260)),
                  onPressed: () => removeSpendingLimit(context, ref, agent),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          if (maxPerTx != null)
            _row('Per transaction', '${formatSuiFromMist(maxPerTx)} SUI'),
          if (maxPerWindow != null)
            _row('Per window', '${formatSuiFromMist(maxPerWindow)} SUI'),
          if (windowMs != null)
            _row('Window', _windowLabel(windowMs.toInt())),
          if (maxPerWindow != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(9999),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: const Color(0xFF3F3F46),
                color: progress > 0.85 ? const Color(0xFFF31260) : const Color(0xFF006FEE),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${formatSuiFromMist(spent)} / ${formatSuiFromMist(maxPerWindow)} SUI spent in window',
              style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 12, fontFamily: 'SN Pro'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Text(label, style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 14, fontFamily: 'SN Pro')),
        const Spacer(),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontFamily: 'SN Pro', fontWeight: FontWeight.w600)),
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
          'access to your pool; any in-flight action will revert on-chain.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFF31260)),
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
    return Container(
      width: double.infinity,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFF31260),
          side: const BorderSide(color: Color(0xFFF31260)),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        onPressed: _busy ? null : _revoke,
        icon: const Icon(Icons.power_settings_new),
        label: Text(_busy ? 'Revoking...' : 'Revoke agent', style: const TextStyle(fontFamily: 'SN Pro', fontSize: 16)),
      ),
    );
  }
}
