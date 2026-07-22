import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/widgets.dart';
import '../../data/indexer/models.dart';
import '../../data/providers.dart';
import '../auth/auth_providers.dart';

class AgentsScreen extends ConsumerWidget {
  const AgentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agents = ref.watch(agentsProvider);
    final nicknames = ref.watch(agentNicknamesProvider).value ?? const {};
    final account = ref.watch(activeAccountProvider);

    return Scaffold(
      backgroundColor: Colors.black, // Figma
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.read(indexerProvider).invalidate('/agents');
            ref.invalidate(agentsProvider);
          },
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
              // ── Title ────────────────────────────────────────────
              Text(
                'Agents',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontFamily: 'SN Pro',
                  fontWeight: FontWeight.w600,
                  height: 1.11,
                ),
              ),
              const SizedBox(height: 16),
              // ── List ────────────────────────────────────────────
              agents.when(
                data: (list) => list.isEmpty
                    ? Column(
                        children: const [
                          SizedBox(height: 80),
                          EmptyState(
                            icon: Icons.smart_toy_outlined,
                            title: 'No agents yet',
                            subtitle:
                                'Connect an agent from a Pinace-enabled platform '
                                'to see it here.',
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          for (final agent in list)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: _AgentCard(
                                agent: agent,
                                nickname: nicknames[agent.id],
                              ),
                            )
                        ],
                      ),
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.only(top: 80),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (e, _) => ErrorState(
                  message: '$e',
                  onRetry: () => ref.invalidate(agentsProvider),
                ),
              ),
            ],
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

    final bool isRunning = agent.status == 'active' && agent.runStatus == 'running';
    final bool isDone = agent.status == 'active' && agent.runStatus == 'done';
    final Color statusColor = isRunning ? const Color(0xFFF5A524) : (isDone ? const Color(0xFF17C964) : Colors.grey);
    final String statusText = isRunning ? 'Running' : (isDone ? 'Done' : agent.status);
    final Color statusTextColor = Colors.black; // Based on Figma

    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: () => context.go('/agents/${agent.id}'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: ShapeDecoration(
          color: const Color(0xFF18181B), // Figma colors-content-content1
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          shadows: [
            BoxShadow(
              color: Color(0x19000000),
              blurRadius: 2,
              offset: Offset(0, 1),
              spreadRadius: -1,
            ),
            BoxShadow(
              color: Color(0x19000000),
              blurRadius: 3,
              offset: Offset(0, 1),
              spreadRadius: 0,
            )
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: ShapeDecoration(
                color: PinaceColors.primary.withValues(alpha: 0.2), // Fallback color
                image: const DecorationImage(
                  image: NetworkImage("https://placehold.co/64x64"),
                  fit: BoxFit.cover,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9999),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
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
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontFamily: 'SN Pro',
                            fontWeight: FontWeight.w600,
                            height: 1.56,
                          ),
                        ),
                      ),
                      Container(
                        height: 24,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: ShapeDecoration(
                          color: statusColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(9999),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            statusText,
                            style: TextStyle(
                              color: statusTextColor,
                              fontSize: 12,
                              fontFamily: 'SN Pro',
                              fontWeight: FontWeight.w500,
                              height: 1.33,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.monetization_on_outlined, size: 16, color: Colors.white70),
                          const SizedBox(width: 4),
                          Text(
                            '${agent.actionCount} actions',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontFamily: 'SN Pro',
                              fontWeight: FontWeight.w400,
                              height: 1.33,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            agent.lastActiveAt != null
                                ? '${timeAgo(dateTimeFromEpochMs(agent.lastActiveAt!))}'
                                : 'Never active',
                            style: TextStyle(
                              color: const Color(0xFF52525B),
                              fontSize: 12,
                              fontFamily: 'SN Pro',
                              fontWeight: FontWeight.w400,
                              height: 1.33,
                            ),
                          ),
                          const SizedBox(height: 4),
                          // Progress Bar mimic
                          Container(
                            width: 60,
                            height: 4,
                            decoration: ShapeDecoration(
                              color: const Color(0xFF3F3F46),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(9999),
                              ),
                            ),
                            alignment: Alignment.centerLeft,
                            child: Container(
                              width: isRunning ? 30 : 60,
                              height: 4,
                              decoration: ShapeDecoration(
                                color: const Color(0xFF006FEE),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(9999),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
