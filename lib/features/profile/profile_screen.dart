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
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Profile', style: TextStyle(fontFamily: 'SN Pro', fontWeight: FontWeight.w600, color: Colors.white)),
        backgroundColor: Colors.black,
        elevation: 0,
      ),
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
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: QrImageView(data: active.address, size: 120),
                  ),
                  const SizedBox(height: 16),
                  Text(active.name,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 18, fontFamily: 'SN Pro', fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  AddressPill(address: active.address),
                  if (auth?.email != null) ...[
                    const SizedBox(height: 8),
                    Text(auth!.email!,
                        style: const TextStyle(
                            color: Color(0xFFA1A1AA), fontSize: 13, fontFamily: 'SN Pro')),
                  ],
                ],
              ),
            ),
          const SizedBox(height: 32),

          // ── Accounts (Slush-style switcher) ──────────────────────────
          Row(
            children: [
               const Text('Accounts',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontFamily: 'SN Pro', fontWeight: FontWeight.w600)),
              const Spacer(),
              TextButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          const WalletSetupScreen(isAddingAccount: true)),
                ),
                icon: const Icon(Icons.add, size: 18, color: Color(0xFF006FEE)),
                label: const Text('Add', style: TextStyle(fontFamily: 'SN Pro', color: Color(0xFF006FEE), fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 8),
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
            error: (e, _) => [Text('$e', style: const TextStyle(color: Colors.white))],
          ),
          const SizedBox(height: 32),

          // ── Settings ─────────────────────────────────────────────────
          const Text('Settings',
              style: TextStyle(color: Colors.white, fontSize: 18, fontFamily: 'SN Pro', fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          const _BiometricTile(),
          const _NotificationsTile(),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.public, color: Colors.white),
            title: const Text('Network', style: TextStyle(color: Colors.white, fontFamily: 'SN Pro', fontWeight: FontWeight.w500)),
            trailing: const Text('Sui Testnet',
                style: TextStyle(color: Color(0xFFA1A1AA), fontFamily: 'SN Pro')),
          ),
          const Divider(height: 48, color: Color(0xFF27272A)),

          // ── Danger zone ──────────────────────────────────────────────
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.logout, color: Colors.white),
            title: const Text('Sign out', style: TextStyle(color: Colors.white, fontFamily: 'SN Pro', fontWeight: FontWeight.w500)),
            subtitle: const Text('Keys stay on this device',
                style: TextStyle(fontSize: 13, fontFamily: 'SN Pro', color: Color(0xFFA1A1AA))),
            onTap: () => ref.read(googleAuthServiceProvider).signOut(),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.delete_forever,
                color: Color(0xFFF31260)),
            title: const Text('Reset wallet',
                style: TextStyle(color: Color(0xFFF31260), fontFamily: 'SN Pro', fontWeight: FontWeight.w500)),
            subtitle: const Text('Deletes all keys from this device',
                style: TextStyle(fontSize: 13, fontFamily: 'SN Pro', color: Color(0xFFA1A1AA))),
            onTap: () => _confirmReset(context, ref),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Future<void> _confirmReset(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF18181B),
        title: const Text('Reset wallet?', style: TextStyle(color: Colors.white, fontFamily: 'SN Pro')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
                'ALL private keys on this device will be permanently deleted. '
                'Funds are only recoverable if you exported your keys.\n\n'
                'Type RESET to confirm:', style: TextStyle(color: Color(0xFFA1A1AA), fontFamily: 'SN Pro')),
            const SizedBox(height: 12),
            TextField(
              controller: controller, 
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF3F3F46))),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF006FEE))),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFFA1A1AA), fontFamily: 'SN Pro'))),
          FilledButton(
            style:
                FilledButton.styleFrom(backgroundColor: const Color(0xFFF31260)),
            onPressed: () =>
                Navigator.pop(context, controller.text.trim() == 'RESET'),
            child: const Text('Reset', style: TextStyle(fontFamily: 'SN Pro')),
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
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF18181B),
        borderRadius: BorderRadius.circular(16),
        border: isActive
            ? Border.all(color: const Color(0xFF006FEE))
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
            style: const TextStyle(color: Colors.white, fontSize: 16, fontFamily: 'SN Pro', fontWeight: FontWeight.w600)),
        subtitle: Text(shortenAddress(account.address),
            style:
                const TextStyle(color: Color(0xFFA1A1AA), fontSize: 13, fontFamily: 'SN Pro')),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isActive)
              const Icon(Icons.check_circle,
                  color: Color(0xFF006FEE), size: 24),
            Theme(
              data: Theme.of(context).copyWith(
                cardColor: const Color(0xFF18181B),
              ),
              child: PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 20, color: Colors.white),
                onSelected: (value) => switch (value) {
                  'rename' => _rename(context, ref),
                  'export' => _export(context, ref),
                  'remove' => _remove(context, ref),
                  _ => null,
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'rename', child: Text('Rename', style: TextStyle(color: Colors.white, fontFamily: 'SN Pro'))),
                  const PopupMenuItem(
                      value: 'export', child: Text('Export key', style: TextStyle(color: Colors.white, fontFamily: 'SN Pro'))),
                  if (canRemove)
                    const PopupMenuItem(
                      value: 'remove',
                      child: Text('Remove',
                          style: TextStyle(color: Color(0xFFF31260), fontFamily: 'SN Pro')),
                    ),
                ],
              ),
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
        backgroundColor: const Color(0xFF18181B),
        title: const Text('Rename account', style: TextStyle(color: Colors.white, fontFamily: 'SN Pro')),
        content: TextField(
          controller: controller, 
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF3F3F46))),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF006FEE))),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFFA1A1AA), fontFamily: 'SN Pro'))),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF006FEE)),
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Save', style: TextStyle(fontFamily: 'SN Pro'))),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      await ref.read(accountsProvider.notifier).rename(account.id, name);
    }
  }

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
        backgroundColor: const Color(0xFF18181B),
        title: const Text('Private key', style: TextStyle(color: Colors.white, fontFamily: 'SN Pro')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Anyone with this key controls the account. Never share it.',
              style: TextStyle(color: Color(0xFFF31260), fontSize: 13, fontFamily: 'SN Pro'),
            ),
            const SizedBox(height: 16),
            SelectableText(key,
                style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'monospace')),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: key));
              Navigator.pop(context);
            },
            child: const Text('Copy & close', style: TextStyle(color: Color(0xFF006FEE), fontFamily: 'SN Pro')),
          ),
        ],
      ),
    );
  }

  Future<void> _remove(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF18181B),
        title: const Text('Remove account?', style: TextStyle(color: Colors.white, fontFamily: 'SN Pro')),
        content: Text(
            'The key for ${shortenAddress(account.address)} will be deleted '
            'from this device. Export it first if you need it later.',
            style: const TextStyle(color: Color(0xFFA1A1AA), fontFamily: 'SN Pro')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFFA1A1AA), fontFamily: 'SN Pro'))),
          FilledButton(
            style:
                FilledButton.styleFrom(backgroundColor: const Color(0xFFF31260)),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove', style: TextStyle(fontFamily: 'SN Pro')),
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
      secondary: const Icon(Icons.fingerprint, color: Colors.white),
      title: const Text('Biometric unlock', style: TextStyle(color: Colors.white, fontFamily: 'SN Pro', fontWeight: FontWeight.w500)),
      subtitle: Text(
        _available ? 'Face ID / fingerprint on app open' : 'Not available on this device',
        style: const TextStyle(fontSize: 13, color: Color(0xFFA1A1AA), fontFamily: 'SN Pro'),
      ),
      activeColor: const Color(0xFF006FEE),
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
      secondary: const Icon(Icons.notifications_outlined, color: Colors.white),
      title: const Text('Notifications', style: TextStyle(color: Colors.white, fontFamily: 'SN Pro', fontWeight: FontWeight.w500)),
      subtitle: const Text('Agent swaps, deposits, revocations',
          style: TextStyle(fontSize: 13, color: Color(0xFFA1A1AA), fontFamily: 'SN Pro')),
      activeColor: const Color(0xFF006FEE),
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
                      content: Text('Notifications unavailable: $e', style: const TextStyle(fontFamily: 'SN Pro'))));
                }
              } finally {
                if (mounted) setState(() => _busy = false);
              }
            },
    );
  }
}
