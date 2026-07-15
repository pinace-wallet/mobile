import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/env.dart';
import '../../core/theme/colors.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/widgets.dart';
import '../../data/providers.dart';

Future<void> showDepositSheet(BuildContext context, WidgetRef ref,
    {required String poolId}) {
  return showPinaceSheet(
    context: context,
    title: 'Add to pool',
    child: _AmountSheet(
      poolId: poolId,
      actionLabel: 'Deposit',
      hint: 'Amount to escrow into your pool',
      maxProvider: (ref) async {
        final owned = await ref.read(ownerBalanceProvider.future);
        if (owned == null) return BigInt.zero;
        final max = owned - Env.gasBufferMist;
        return max.isNegative ? BigInt.zero : max;
      },
      submit: (ref, amount) async {
        final signer = await ref.read(activeSignerProvider.future);
        if (signer == null) throw Exception('No active account');
        return ref
            .read(pinaceTxProvider)
            .depositToPool(signer, poolId: poolId, amountMist: amount);
      },
    ),
  );
}

Future<void> showWithdrawSheet(BuildContext context, WidgetRef ref,
    {required String poolId, required BigInt poolBalance}) {
  return showPinaceSheet(
    context: context,
    title: 'Withdraw from pool',
    child: _AmountSheet(
      poolId: poolId,
      actionLabel: 'Withdraw',
      hint: 'Returns SUI from the pool to your wallet',
      maxProvider: (_) async => poolBalance,
      submit: (ref, amount) async {
        final signer = await ref.read(activeSignerProvider.future);
        if (signer == null) throw Exception('No active account');
        return ref
            .read(pinaceTxProvider)
            .withdrawFromPool(signer, poolId: poolId, amountMist: amount);
      },
    ),
  );
}

class _AmountSheet extends ConsumerStatefulWidget {
  const _AmountSheet({
    required this.poolId,
    required this.actionLabel,
    required this.hint,
    required this.maxProvider,
    required this.submit,
  });

  final String poolId;
  final String actionLabel;
  final String hint;
  final Future<BigInt> Function(WidgetRef ref) maxProvider;
  final Future<dynamic> Function(WidgetRef ref, BigInt amountMist) submit;

  @override
  ConsumerState<_AmountSheet> createState() => _AmountSheetState();
}

class _AmountSheetState extends ConsumerState<_AmountSheet> {
  final _controller = TextEditingController();
  bool _busy = false;
  String? _error;
  BigInt? _max;

  @override
  void initState() {
    super.initState();
    widget.maxProvider(ref).then((max) {
      if (mounted) setState(() => _max = max);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amount = parseSuiToMist(_controller.text);
    if (amount == null) {
      setState(() => _error = 'Enter a valid amount');
      return;
    }
    if (_max != null && amount > _max!) {
      setState(() => _error =
          'Max available: ${formatSuiFromMist(_max!)} SUI (gas reserved)');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.submit(ref, amount);
      invalidateAfterTx(ref);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text('${widget.actionLabel} of ${_controller.text} SUI sent')));
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
        Text(widget.hint,
            style: const TextStyle(color: PinaceColors.zinc400, fontSize: 13)),
        const SizedBox(height: 16),
        TextField(
          controller: _controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Amount (SUI)',
            suffixIcon: TextButton(
              onPressed: _max == null
                  ? null
                  : () => _controller.text = suiDecimalString(_max!),
              child: const Text('MAX'),
            ),
          ),
        ),
        if (_max != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('Available: ${formatSuiFromMist(_max!)} SUI',
                style: const TextStyle(
                    color: PinaceColors.textMuted, fontSize: 12)),
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_error!,
                style:
                    const TextStyle(color: PinaceColors.danger, fontSize: 12)),
          ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: Text(_busy ? 'Signing & submitting...' : widget.actionLabel),
        ),
      ],
    );
  }
}
