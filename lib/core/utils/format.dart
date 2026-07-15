import 'package:intl/intl.dart';

/// Formatting helpers ported from Frontend/lib/pinace/format.ts.

final _suiFormat = NumberFormat('#,##0.####');

BigInt mistPerSui = BigInt.from(1000000000);

/// 1234567890 MIST -> "1.2346" (SUI, 4 dp max, thousands separators).
String formatSuiFromMist(BigInt mist, {int decimals = 4}) {
  final sui = mist.toDouble() / 1e9;
  return _suiFormat.format(sui);
}

/// Plain decimal string without grouping, for prefilling text fields.
String suiDecimalString(BigInt mist, {int decimals = 4}) =>
    (mist.toDouble() / 1e9).toStringAsFixed(decimals);

/// Parses a user-entered SUI amount ("0.5") into MIST. Returns null if invalid.
BigInt? parseSuiToMist(String input) {
  final value = double.tryParse(input.trim());
  if (value == null || value <= 0) return null;
  return BigInt.from((value * 1e9).round());
}

/// "0x5be5ab02...a23b"
String shortenAddress(String address, {int head = 6, int tail = 4}) {
  if (address.length <= head + tail + 3) return address;
  return '${address.substring(0, head)}...${address.substring(address.length - tail)}';
}

/// Relative time like the extension's lastActiveLabel ("2m ago", "3h ago").
String timeAgo(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inSeconds < 60) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return DateFormat('MMM d').format(time);
}

DateTime dateTimeFromEpochMs(num ms) =>
    DateTime.fromMillisecondsSinceEpoch(ms.toInt());

String dayLabel(DateTime time) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(time.year, time.month, time.day);
  if (day == today) return 'Today';
  if (day == today.subtract(const Duration(days: 1))) return 'Yesterday';
  return DateFormat('MMMM d, yyyy').format(time);
}
