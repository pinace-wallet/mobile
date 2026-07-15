import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/widgets.dart';
import '../../data/indexer/models.dart';
import '../../data/providers.dart';

class AgentsScreen extends ConsumerWidget {
  const AgentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agents = ref.watch(agentsProvider);
    final nicknames = ref.watch(agentNicknamesProvider).value ?? const {};

    return Scaffold(
      appBar: AppBar(title: const Text('Agents')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.read(indexerProvider).invalidate('/agents');
          ref.invalidate(agentsProvider);
        },
        child: agents.when(
          data: (list) => list.isEmpty
              ? ListView(
                  children: const [
                    SizedBox(height: 120),
                    EmptyState(
                      icon: Icons.smart_toy_outlined,
                      title: 'No agents yet',
                      subtitle:
                          'Connect an agent from a Pinace-enabled platform '
                          '(e.g. fenik.one) to see it here.',
                    ),
                  ],
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) => _AgentCard(
                    agent: list[index],
                    nickname: nicknames[list[index].id],
                  ),
                ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ErrorState(
            message: '$e',
            onRetry: () => ref.invalidate(agentsProvider),
          ),
        ),
      ),
    );
  }
}

class _AgentCard extends StatelessWidget {
  const _AgentCard({required this.agent, this.nickname});

  final Agent agent;
  final String? nickname;

  @override
  Widget build(BuildContext context) {
    final displayName = nickname ??
        (agent.name == agent.address ? shortenAddress(agent.address) : agent.name);

    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: () => context.go('/agents/${agent.id}'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: PinaceColors.cardGradient,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: PinaceColors.zinc800),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: PinaceColors.primary.withValues(alpha: 0.2),
              child: const Icon(Icons.smart_toy,
                  color: PinaceColors.primary, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(
                    '${agent.actionCount} actions'
                    '${agent.lastActiveAt != null ? ' · ${timeAgo(dateTimeFromEpochMs(agent.lastActiveAt!))}' : ''}',
                    style: const TextStyle(
                        color: PinaceColors.zinc400, fontSize: 12),
                  ),
                ],
              ),
            ),
            StatusChip.agent(agent.status, runStatus: agent.runStatus),
          ],
        ),
      ),
    );
  }
}
