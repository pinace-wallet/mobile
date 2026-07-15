import 'package:flutter/material.dart';

/// Design tokens ported from Frontend/entrypoints/popup/globals.css.
abstract final class PinaceColors {
  static const bg = Color(0xFF000000);
  static const primary = Color(0xFF006FEE);
  static const success = Color(0xFF17C964);
  static const danger = Color(0xFFF31260);
  static const warning = Color(0xFFF5A524); // "running" chip

  // Zinc scale
  static const zinc900 = Color(0xFF18181B);
  static const zinc800 = Color(0xFF27272A);
  static const zinc700 = Color(0xFF3F3F46);
  static const zinc400 = Color(0xFFA1A1AA);
  static const zinc300 = Color(0xFFD4D4D8);
  static const textMuted = Color(0xFF52525B);

  static const cyan = Color(0xFF00DBE9); // assets accent

  /// Navy gradient used on hero/pool cards:
  /// linear-gradient(100.46deg, #18181B 2.86%, #0D1F35 97.54%)
  static const cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF18181B), Color(0xFF0D1F35)],
  );

  static const blueGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0D1F35), Color(0xFF006FEE)],
  );
}
