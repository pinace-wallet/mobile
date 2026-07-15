import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'features/auth/auth_providers.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  var firebaseReady = false;
  try {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
    firebaseReady = true;
  } catch (e) {
    // firebase_options.dart still has placeholder values — run
    // `flutterfire configure` (see mobile/README.md). The app boots into
    // the Login screen with a setup hint instead of crashing.
    debugPrint('Firebase init failed: $e');
  }

  runApp(ProviderScope(
    overrides: [
      firebaseReadyProvider.overrideWith((ref) => firebaseReady),
    ],
    child: const PinaceApp(),
  ));
}
