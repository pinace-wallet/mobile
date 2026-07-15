import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/colors.dart';
import '../../core/utils/format.dart';
import '../../data/keystore/wallet_keystore.dart';
import 'auth_providers.dart';

/// First-run wallet setup: create a fresh Ed25519 account or import an
/// existing key (suiprivkey1... / raw hex / base64). Also reachable from
/// Profile > Add account.
class WalletSetupScreen extends ConsumerStatefulWidget {
  const WalletSetupScreen({super.key, this.isAddingAccount = false});

  final bool isAddingAccount;

  @override
  ConsumerState<WalletSetupScreen> createState() => _WalletSetupScreenState();
}

class _WalletSetupScreenState extends ConsumerState<WalletSetupScreen> {
  final _keyController = TextEditingController();
  final _nameController = TextEditingController();
  bool _importMode = false;
  bool _busy = false;
  String? _error;
  String? _previewAddress;

  @override
  void dispose() {
    _keyController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _onKeyChanged(String value) {
    setState(() {
      _error = null;
      if (value.trim().isEmpty) {
        _previewAddress = null;
        return;
      }
      try {
        _previewAddress = WalletKeystore.previewAddress(value);
      } catch (_) {
        _previewAddress = null;
      }
    });
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final notifier = ref.read(accountsProvider.notifier);
      final name =
          _nameController.text.trim().isEmpty ? null : _nameController.text.trim();
      if (_importMode) {
        await notifier.importAccount(_keyController.text, name: name);
      } else {
        await notifier.createAccount(name: name);
      }
      // After first setup, offer biometric unlock.
      final lock = ref.read(lockProvider.notifier);
      if (!widget.isAddingAccount && await lock.canUseBiometrics() && mounted) {
        final enable = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Enable biometric unlock?'),
            content: const Text(
                'Use Face ID / fingerprint to unlock your wallet quickly and securely.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Not now')),
              FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Enable')),
            ],
          ),
        );
        if (enable == true) await lock.setBiometricEnabled(true);
      }
      ref.read(lockProvider.notifier).unlockWithoutPrompt();
      if (widget.isAddingAccount && mounted) Navigator.pop(context);
      // Otherwise the router redirects to /home.
    } on FormatException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isAddingAccount ? 'Add account' : 'Set up wallet'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Create new')),
                  ButtonSegment(value: true, label: Text('Import key')),
                ],
                selected: {_importMode},
                onSelectionChanged: (selection) =>
                    setState(() => _importMode = selection.first),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Account name (optional)',
                  hintText: 'Main Account',
                ),
              ),
              const SizedBox(height: 16),
              if (_importMode) ...[
                TextField(
                  controller: _keyController,
                  onChanged: _onKeyChanged,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Private key',
                    hintText: 'suiprivkey1... or 64-char hex seed',
                  ),
                ),
                if (_previewAddress != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      'Address: ${shortenAddress(_previewAddress!, head: 10, tail: 8)}',
                      style: const TextStyle(
                          color: PinaceColors.success, fontSize: 13),
                    ),
                  ),
              ] else
                const Text(
                  'A new Ed25519 keypair will be generated and stored in your '
                  "device's secure enclave. Back it up from Profile > Export key.",
                  style: TextStyle(color: PinaceColors.zinc400, fontSize: 13),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(_error!,
                      style: const TextStyle(
                          color: PinaceColors.danger, fontSize: 13)),
                ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _busy ||
                        (_importMode && _previewAddress == null)
                    ? null
                    : _submit,
                child: Text(_busy
                    ? 'Working...'
                    : _importMode
                        ? 'Import account'
                        : 'Create account'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
