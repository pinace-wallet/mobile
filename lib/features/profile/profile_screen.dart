import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/theme/colors.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/widgets.dart';
import '../../data/keystore/account.dart';
import '../../data/providers.dart';
import '../auth/auth_providers.dart';
import '../auth/wallet_setup_screen.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider).value;
    final accounts = ref.watch(accountsProvider);
    final active = ref.watch(activeAccountProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── Current account card ─────────────────────────────────────
          if (active != null)
            GradientCard(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: QrImageView(data: active.address, size: 120),
                  ),
                  const SizedBox(height: 12),
                  Text(active.name,
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  AddressPill(address: active.address),
                  if (auth?.email != null) ...[
                    const SizedBox(height: 6),
                    Text(auth!.email!,
                        style: const TextStyle(
                            color: PinaceColors.textMuted, fontSize: 12)),
                  ],
                ],
              ),
            ),
          const SizedBox(height: 24),

          // ── Accounts (Slush-style switcher) ──────────────────────────
          Row(
            children: [
              const Text('Accounts',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const Spacer(),
              TextButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          const WalletSetupScreen(isAddingAccount: true)),
                ),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add'),
              ),
            ],
          ),
          ...accounts.when(
            data: (state) => [
              for (final account in state.accounts)
                _AccountTile(
                  account: account,
                  isActive: account.id == state.active?.id,
                  canRemove: state.accounts.length > 1,
                ),
            ],
            loading: () => const [Center(child: CircularProgressIndicator())],
            error: (e, _) => [Text('$e')],
          ),
          const SizedBox(height: 24),

          // ── Settings ─────────────────────────────────────────────────
          const Text('Settings',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const _BiometricTile(),
          const _NotificationsTile(),
          const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.public),
            title: Text('Network'),
            trailing: Text('Sui Testnet',
                style: TextStyle(color: PinaceColors.zinc400)),
          ),
          const Divider(height: 32),

          // ── Danger zone ──────────────────────────────────────────────
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.logout),
            title: const Text('Sign out'),
            subtitle: const Text('Keys stay on this device',
                style: TextStyle(fontSize: 12, color: PinaceColors.textMuted)),
            onTap: () => ref.read(googleAuthServiceProvider).signOut(),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.delete_forever,
                color: PinaceColors.danger),
            title: const Text('Reset wallet',
                style: TextStyle(color: PinaceColors.danger)),
            subtitle: const Text('Deletes all keys from this device',
                style: TextStyle(fontSize: 12, color: PinaceColors.textMuted)),
            onTap: () => _confirmReset(context, ref),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _confirmReset(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset wallet?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
                'ALL private keys on this device will be permanently deleted. '
                'Funds are only recoverable if you exported your keys.\n\n'
                'Type RESET to confirm:'),
            const SizedBox(height: 12),
            TextField(controller: controller, autofocus: true),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
            style:
                FilledButton.styleFrom(backgroundColor: PinaceColors.danger),
            onPressed: () =>
                Navigator.pop(context, controller.text.trim() == 'RESET'),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(accountsProvider.notifier).resetWallet();
    }
  }
}

class _AccountTile extends ConsumerWidget {
  const _AccountTile({
    required this.account,
    required this.isActive,
    required this.canRemove,
  });

  final WalletAccount account;
  final bool isActive;
  final bool canRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorSeed = account.address.hashCode;
    final dotColor =
        Colors.primaries[colorSeed.abs() % Colors.primaries.length];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: PinaceColors.zinc900,
        borderRadius: BorderRadius.circular(16),
        border: isActive
            ? Border.all(color: PinaceColors.primary)
            : Border.all(color: Colors.transparent),
      ),
      child: ListTile(
        onTap: isActive
            ? null
            : () => ref.read(accountsProvider.notifier).switchTo(account.id),
        leading: CircleAvatar(
          radius: 14,
          backgroundColor: dotColor.withValues(alpha: 0.25),
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
        ),
        title: Text(account.name,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        subtitle: Text(shortenAddress(account.address),
            style:
                const TextStyle(color: PinaceColors.textMuted, fontSize: 12)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isActive)
              const Icon(Icons.check_circle,
                  color: PinaceColors.primary, size: 20),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 18),
              onSelected: (value) => switch (value) {
                'rename' => _rename(context, ref),
                'export' => _export(context, ref),
                'remove' => _remove(context, ref),
                _ => null,
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'rename', child: Text('Rename')),
                const PopupMenuItem(
                    value: 'export', child: Text('Export key')),
                if (canRemove)
                  const PopupMenuItem(
                    value: 'remove',
                    child: Text('Remove',
                        style: TextStyle(color: PinaceColors.danger)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _rename(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(text: account.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename account'),
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
      await ref.read(accountsProvider.notifier).rename(account.id, name);
    }
  }

  /// Biometric re-prompt, then reveal the suiprivkey with a copy button.
  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final lock = ref.read(lockProvider.notifier);
    if (await lock.isBiometricEnabled() && await lock.canUseBiometrics()) {
      final ok = await lock.unlock();
      if (!ok) return;
    }
    final key = await ref.read(keystoreProvider)?.exportKey(account.id);
    if (key == null || !context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Private key'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Anyone with this key controls the account. Never share it.',
              style: TextStyle(color: PinaceColors.danger, fontSize: 12),
            ),
            const SizedBox(height: 12),
            SelectableText(key,
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: key));
              Navigator.pop(context);
            },
            child: const Text('Copy & close'),
          ),
        ],
      ),
    );
  }

  Future<void> _remove(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove account?'),
        content: Text(
            'The key for ${shortenAddress(account.address)} will be deleted '
            'from this device. Export it first if you need it later.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
            style:
                FilledButton.styleFrom(backgroundColor: PinaceColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(accountsProvider.notifier).remove(account.id);
    }
  }
}

class _BiometricTile extends ConsumerStatefulWidget {
  const _BiometricTile();

  @override
  ConsumerState<_BiometricTile> createState() => _BiometricTileState();
}

class _BiometricTileState extends ConsumerState<_BiometricTile> {
  bool _enabled = false;
  bool _available = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final lock = ref.read(lockProvider.notifier);
    final enabled = await lock.isBiometricEnabled();
    final available = await lock.canUseBiometrics();
    if (mounted) {
      setState(() {
        _enabled = enabled;
        _available = available;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      secondary: const Icon(Icons.fingerprint),
      title: const Text('Biometric unlock'),
      subtitle: Text(
        _available ? 'Face ID / fingerprint on app open' : 'Not available on this device',
        style: const TextStyle(fontSize: 12, color: PinaceColors.textMuted),
      ),
      value: _enabled && _available,
      onChanged: !_available
          ? null
          : (value) async {
              await ref
                  .read(lockProvider.notifier)
                  .setBiometricEnabled(value);
              setState(() => _enabled = value);
            },
    );
  }
}

class _NotificationsTile extends ConsumerStatefulWidget {
  const _NotificationsTile();

  @override
  ConsumerState<_NotificationsTile> createState() => _NotificationsTileState();
}

class _NotificationsTileState extends ConsumerState<_NotificationsTile> {
  bool _enabled = false;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      secondary: const Icon(Icons.notifications_outlined),
      title: const Text('Notifications'),
      subtitle: const Text('Agent swaps, deposits, revocations',
          style: TextStyle(fontSize: 12, color: PinaceColors.textMuted)),
      value: _enabled,
      onChanged: _busy
          ? null
          : (value) async {
              if (!value) {
                setState(() => _enabled = false);
                await ref
                    .read(firestoreRepoProvider)
                    ?.setNotificationsEnabled(false);
                return;
              }
              setState(() => _busy = true);
              try {
                final fcm = ref.read(fcmServiceProvider);
                final granted = await fcm?.enable() ?? false;
                setState(() => _enabled = granted);
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Notifications unavailable: $e')));
                }
              } finally {
                if (mounted) setState(() => _busy = false);
              }
            },
    );
  }
}
