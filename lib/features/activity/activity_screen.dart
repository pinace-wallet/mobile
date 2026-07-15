import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/colors.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/widgets.dart';
import '../../data/indexer/models.dart';
import '../../data/providers.dart';
import '../home/home_screen.dart' show EventRow;

/// Transactions tab — the pool's event feed grouped by day, with paging.
class ActivityScreen extends ConsumerStatefulWidget {
  const ActivityScreen({super.key});

  @override
  ConsumerState<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends ConsumerState<ActivityScreen> {
  int _pages = 1;

  @override
  Widget build(BuildContext context) {
    final results = [
      for (var page = 1; page <= _pages; page++)
        ref.watch(poolEventsProvider(page)),
    ];
    final firstPage = results.first;

    return Scaffold(
      appBar: AppBar(title: const Text('Transactions')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.read(indexerProvider).invalidate('/events');
          setState(() => _pages = 1);
          ref.invalidate(poolEventsProvider);
        },
        child: firstPage.when(
          data: (first) {
            if (first == null) {
              return ListView(children: const [
                SizedBox(height: 120),
                EmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: 'No pool yet',
                  subtitle: 'Create a pool from Home to start tracking activity.',
                ),
              ]);
            }
            final events = <EventLog>[
              for (final r in results) ...?r.value?.data,
            ];
            if (events.isEmpty) {
              return ListView(children: const [
                SizedBox(height: 120),
                EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'No transactions yet'),
              ]);
            }

            final hasMore = results.last.value?.hasMore ?? false;
            final grouped = <String, List<EventLog>>{};
            for (final event in events) {
              grouped.putIfAbsent(dayLabel(event.time), () => []).add(event);
            }

            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                for (final entry in grouped.entries) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 4),
                    child: Text(
                      entry.key,
                      style: const TextStyle(
                          color: PinaceColors.zinc400,
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                  for (final event in entry.value) EventRow(event: event),
                ],
                if (hasMore)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: OutlinedButton(
                      onPressed: () => setState(() => _pages++),
                      child: const Text('Load more'),
                    ),
                  ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ErrorState(
            message: '$e',
            onRetry: () => ref.invalidate(poolEventsProvider),
          ),
        ),
      ),
    );
  }
}
