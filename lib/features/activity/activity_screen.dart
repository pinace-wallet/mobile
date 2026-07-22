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
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Transactions', style: TextStyle(fontFamily: 'SN Pro', fontWeight: FontWeight.w600, color: Colors.white)),
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
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
              padding: const EdgeInsets.all(16),
              children: [
                for (final entry in grouped.entries) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 16, bottom: 8, left: 4),
                    child: Text(
                      entry.key,
                      style: const TextStyle(
                          color: Color(0xFFA1A1AA),
                          fontSize: 14,
                          fontFamily: 'SN Pro',
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                  for (final event in entry.value) 
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
                        child: EventRow(event: event),
                      ),
                    ),
                ],
                if (hasMore)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9999)),
                        side: const BorderSide(color: Color(0xFF3F3F46)),
                      ),
                      onPressed: () => setState(() => _pages++),
                      child: const Text('Load more', style: TextStyle(fontFamily: 'SN Pro', color: Colors.white)),
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
