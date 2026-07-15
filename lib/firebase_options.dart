// PLACEHOLDER — replace by running `flutterfire configure` in mobile/.
// Until then Firebase init fails gracefully and the Login screen shows a
// setup hint. Do not commit real API keys beyond what flutterfire generates
// (Firebase client keys are not secrets, but keep this file consistent).
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    throw UnsupportedError(
      'firebase_options.dart has not been generated yet. '
      'Run: dart pub global activate flutterfire_cli && flutterfire configure',
    );
  }
}
