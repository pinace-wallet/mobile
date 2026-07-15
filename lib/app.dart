import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/theme.dart';
import 'features/auth/auth_providers.dart';

class PinaceApp extends ConsumerStatefulWidget {
  const PinaceApp({super.key});

  @override
  ConsumerState<PinaceApp> createState() => _PinaceAppState();
}

class _PinaceAppState extends ConsumerState<PinaceApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final lock = ref.read(lockProvider.notifier);
    if (state == AppLifecycleState.paused) lock.onAppPaused();
    if (state == AppLifecycleState.resumed) lock.onAppResumed();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Pinace Wallet',
      debugShowCheckedModeBanner: false,
      theme: buildPinaceTheme(),
      routerConfig: router,
    );
  }
}
