import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/colors.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/widgets.dart';
import '../../data/indexer/models.dart';
import '../../data/providers.dart';

/// Attach or edit the spending-limit policy (the only guard the wallet UI
/// surfaces today, matching the extension's EditPolicyModal).
Future<void> showSpendingLimitSheet(
  BuildContext context,
  WidgetRef ref, {
  required Agent agent,
  required AgentPolicy? existing,
}) {
  return showPinaceSheet(
    context: context,
    title: existing == null ? 'Add spending limit' : 'Edit spending limit',
    child: _SpendingLimitForm(agent: agent, existing: existing),
  );
}

Future<void> removeSpendingLimit(
    BuildContext context, WidgetRef ref, Agent agent) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Remove spending limit?'),
      content: const Text(
          'The agent will be unbounded until you attach a new limit.'),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: PinaceColors.danger),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Remove'),
        ),
      ],
    ),
  );
  if (confirmed != true) return;
  try {
    final signer = await ref.read(activeSignerProvider.future);
    if (signer == null) throw Exception('No active account');
    await ref.read(pinaceTxProvider).removeSpendingLimit(
          signer,
          poolId: agent.poolId,
          agentAddress: agent.address,
        );
    invalidateAfterTx(ref);
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Policy removed')));
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Remove failed: $e')));
    }
  }
}

class _SpendingLimitForm extends ConsumerStatefulWidget {
  const _SpendingLimitForm({required this.agent, required this.existing});

  final Agent agent;
  final AgentPolicy? existing;

  @override
  ConsumerState<_SpendingLimitForm> createState() => _SpendingLimitFormState();
}

class _SpendingLimitFormState extends ConsumerState<_SpendingLimitForm> {
  late final TextEditingController _perTx;
  late final TextEditingController _perWindow;
  late int _windowMinutes;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _perTx = TextEditingController(
      text: existing?.configValue('max_per_tx') != null
          ? suiDecimalString(existing!.configValue('max_per_tx')!)
          : '',
    );
    _perWindow = TextEditingController(
      text: existing?.configValue('max_per_window') != null
          ? suiDecimalString(existing!.configValue('max_per_window')!)
          : '',
    );
    final windowMs = existing?.configValue('window_ms')?.toInt() ?? 3600000;
    final minutes = (windowMs / 60000).round();
    // Snap to the nearest preset so the dropdown always has a valid value.
    const presets = [1, 10, 60, 360, 1440];
    _windowMinutes = presets.reduce(
        (a, b) => (minutes - a).abs() <= (minutes - b).abs() ? a : b);
  }

  @override
  void dispose() {
    _perTx.dispose();
    _perWindow.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final maxPerTx = parseSuiToMist(_perTx.text);
    final maxPerWindow = parseSuiToMist(_perWindow.text);
    if (maxPerTx == null || maxPerWindow == null) {
      setState(() => _error = 'Enter valid SUI amounts');
      return;
    }
    if (maxPerWindow < maxPerTx) {
      setState(() => _error = 'Per-window limit must be ≥ per-transaction');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final signer = await ref.read(activeSignerProvider.future);
      if (signer == null) throw Exception('No active account');
      await ref.read(pinaceTxProvider).setSpendingLimit(
            signer,
            poolId: widget.agent.poolId,
            agentAddress: widget.agent.address,
            maxPerTx: maxPerTx,
            maxPerWindow: maxPerWindow,
            window: Duration(minutes: _windowMinutes),
            update: widget.existing != null,
          );
      invalidateAfterTx(ref);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(widget.existing == null
                ? 'Spending limit attached'
                : 'Spending limit updated')));
      }
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Enforced on-chain by the Move contract — the agent cannot exceed '
          'these bounds even if compromised.',
          style: TextStyle(color: PinaceColors.zinc400, fontSize: 12),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _perTx,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration:
              const InputDecoration(labelText: 'Max per transaction (SUI)'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _perWindow,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Max per window (SUI)'),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(
          initialValue: _windowMinutes,
          decoration: const InputDecoration(labelText: 'Window'),
          items: const [
            DropdownMenuItem(value: 1, child: Text('1 minute')),
            DropdownMenuItem(value: 10, child: Text('10 minutes')),
            DropdownMenuItem(value: 60, child: Text('1 hour')),
            DropdownMenuItem(value: 360, child: Text('6 hours')),
            DropdownMenuItem(value: 1440, child: Text('24 hours')),
          ],
          onChanged: (v) => setState(() => _windowMinutes = v ?? 60),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(_error!,
                style:
                    const TextStyle(color: PinaceColors.danger, fontSize: 12)),
          ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: Text(_busy
              ? 'Signing & submitting...'
              : widget.existing == null
                  ? 'Attach limit'
                  : 'Update limit'),
        ),
      ],
    );
  }
}
