package xyz.pinace.pinace_wallet

import io.flutter.embedding.android.FlutterFragmentActivity

// FlutterFragmentActivity (not FlutterActivity) is required by local_auth
// for the BiometricPrompt API.
class MainActivity : FlutterFragmentActivity()
