import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/providers.dart';
import '../../features/activity/activity_screen.dart';
import '../../features/agents/agent_detail_screen.dart';
import '../../features/agents/agents_screen.dart';
import '../../features/assets/assets_screen.dart';
import '../../features/auth/auth_providers.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/unlock_screen.dart';
import '../../features/auth/wallet_setup_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/profile/profile_screen.dart';

/// Gate order (mirrors the extension's Router.tsx boot gate):
/// splash -> login (no Firebase user) -> setup (no wallet accounts)
/// -> unlock (biometric) -> tab shell.
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier(0);
  ref.listen(authStateProvider, (_, __) => refresh.value++);
  ref.listen(accountsProvider, (_, __) => refresh.value++);
  ref.listen(lockProvider, (_, __) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authStateProvider);
      final accounts = ref.read(accountsProvider);
      final locked = ref.read(lockProvider);
      final location = state.matchedLocation;
      final atGate = location == '/splash' ||
          location == '/login' ||
          location == '/setup' ||
          location == '/unlock';

      if (auth.isLoading) return atGate ? null : '/splash';
      final user = auth.value;
      if (user == null) return location == '/login' ? null : '/login';
      if (accounts.isLoading) return atGate ? null : '/splash';
      final hasAccounts =
          (accounts.value?.accounts ?? const []).isNotEmpty;
      if (!hasAccounts) return location == '/setup' ? null : '/setup';
      if (locked) return location == '/unlock' ? null : '/unlock';
      return atGate ? '/home' : null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
          path: '/setup',
          builder: (context, state) => const WalletSetupScreen()),
      GoRoute(
          path: '/unlock', builder: (context, state) => const UnlockScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => _TabShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/home',
                builder: (context, state) => const HomeScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/agents',
              builder: (context, state) => const AgentsScreen(),
              routes: [
                GoRoute(
                  path: ':agentId',
                  builder: (context, state) => AgentDetailScreen(
                      agentId: state.pathParameters['agentId']!),
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/assets',
                builder: (context, state) => const AssetsScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/activity',
                builder: (context, state) => const ActivityScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfileScreen()),
          ]),
        ],
      ),
    ],
  );
});

class _TabShell extends ConsumerWidget {
  const _TabShell({required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Keep the SSE stream alive while the shell is mounted.
    ref.watch(sseProvider);
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (index) => shell.goBranch(
          index,
          initialLocation: index == shell.currentIndex,
        ),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(
              icon: Icon(Icons.smart_toy_outlined), label: 'Agents'),
          NavigationDestination(
              icon: Icon(Icons.token_outlined), label: 'Assets'),
          NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined), label: 'Activity'),
          NavigationDestination(
              icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
      ),
    );
  }
}
