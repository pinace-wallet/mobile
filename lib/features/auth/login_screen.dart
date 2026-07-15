import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/colors.dart';
import 'auth_providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _signIn() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(googleAuthServiceProvider).signInWithGoogle();
      // Router redirects to /setup or /unlock via authStateProvider.
    } catch (e) {
      setState(() => _error = 'Sign-in failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final firebaseReady = ref.watch(firebaseReadyProvider);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(flex: 2),
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  gradient: PinaceColors.blueGradient,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: const Icon(Icons.account_balance_wallet,
                    size: 44, color: Colors.white),
              ),
              const SizedBox(height: 24),
              const Text(
                'Pinace Wallet',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const Text(
                'Delegate on-chain execution to agents —\nwithout ever sharing your key.',
                textAlign: TextAlign.center,
                style: TextStyle(color: PinaceColors.zinc400, height: 1.4),
              ),
              const Spacer(flex: 3),
              if (!firebaseReady)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: PinaceColors.warning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Firebase is not configured yet. Run `flutterfire configure` '
                    'in mobile/ and rebuild to enable Google sign-in.',
                    style:
                        TextStyle(color: PinaceColors.warning, fontSize: 12),
                  ),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: PinaceColors.danger, fontSize: 12),
                  ),
                ),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: firebaseReady && !_busy ? _signIn : null,
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.login),
                  label: Text(_busy ? 'Signing in...' : 'Continue with Google'),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Your Sui keys are generated on this device and never leave it. '
                'Google only signs you in to the app.',
                textAlign: TextAlign.center,
                style: TextStyle(color: PinaceColors.textMuted, fontSize: 11),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
