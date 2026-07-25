import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/firebase/firestore_repo.dart';
import '../../data/keystore/account.dart';
import '../../data/keystore/wallet_keystore.dart';

/// Set from main() — false when firebase_options.dart hasn't been generated
/// yet (run `flutterfire configure`). The Login screen shows a hint.
final firebaseReadyProvider = Provider<bool>((ref) => true);

final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

final googleAuthServiceProvider = Provider((ref) => GoogleAuthService());

class GoogleAuthService {
  bool _initialized = false;

  Future<UserCredential> signInWithGoogle() async {
    final signIn = GoogleSignIn.instance;
    if (!_initialized) {
      // v7's authenticate() needs the Web OAuth client id (client_type: 3
      // in google-services.json) to mint an ID token on Android — the
      // Android client id alone isn't enough as of this package version.
      await signIn.initialize(
        serverClientId:
            '806824587137-72rreb8m04tr7ku1ipe837khjeesr2j2.apps.googleusercontent.com',
      );
      _initialized = true;
    }
    final account = await signIn.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw Exception('Google sign-in did not return an ID token.');
    }
    final credential = GoogleAuthProvider.credential(idToken: idToken);
    final userCredential =
        await FirebaseAuth.instance.signInWithCredential(credential);
    final user = userCredential.user;
    if (user != null) {
      await FirestoreRepo(user.uid).ensureUserDoc(user);
    }
    return userCredential;
  }

  Future<void> signOut() async {
    await GoogleSignIn.instance.signOut();
    await FirebaseAuth.instance.signOut();
  }
}

final keystoreProvider = Provider<WalletKeystore?>((ref) {
  final user = ref.watch(authStateProvider).value;
  return user == null ? null : WalletKeystore(user.uid);
});

final firestoreRepoProvider = Provider<FirestoreRepo?>((ref) {
  final user = ref.watch(authStateProvider).value;
  return user == null ? null : FirestoreRepo(user.uid);
});

/// Accounts + active account. All wallet data providers watch
/// [activeAccountProvider] so switching accounts re-scopes everything.
class AccountsState {
  const AccountsState({required this.accounts, required this.activeId});

  final List<WalletAccount> accounts;
  final String? activeId;

  WalletAccount? get active {
    if (accounts.isEmpty) return null;
    return accounts.firstWhere((a) => a.id == activeId,
        orElse: () => accounts.first);
  }
}

class AccountsNotifier extends AsyncNotifier<AccountsState> {
  WalletKeystore get _keystore {
    final ks = ref.read(keystoreProvider);
    if (ks == null) throw StateError('Not signed in');
    return ks;
  }

  @override
  Future<AccountsState> build() async {
    final ks = ref.watch(keystoreProvider);
    if (ks == null) return const AccountsState(accounts: [], activeId: null);
    
    var accounts = await ks.listAccounts();
    final activeId = await ks.getActiveAccountId();
    
    try {
      final repo = ref.read(firestoreRepoProvider);
      if (repo != null) {
        final remoteNames = await repo.getAccountNames();
        bool changed = false;
        
        for (var i = 0; i < accounts.length; i++) {
          final acc = accounts[i];
          final remoteName = remoteNames[acc.address];
          if (remoteName != null && remoteName != acc.name) {
            accounts[i] = acc.copyWith(name: remoteName);
            await ks.renameAccount(acc.id, remoteName);
            changed = true;
          }
        }
        if (changed) {
          // Note: we updated `accounts` list in place, but since it's a new state object,
          // Riverpod will rebuild listeners.
        }
      }
    } catch (_) {/* offline or error is fine */}

    return AccountsState(accounts: accounts, activeId: activeId);
  }

  Future<WalletAccount> createAccount({String? name}) async {
    final account = await _keystore.createAccount(name: name);
    await _keystore.setActiveAccountId(account.id);
    await _syncToFirestore(account);
    ref.invalidateSelf();
    return account;
  }

  Future<WalletAccount> importAccount(String key, {String? name}) async {
    final repo = ref.read(firestoreRepoProvider);
    if (repo != null) {
      try {
        final address = WalletKeystore.previewAddress(key);
        final ownerUid = await repo.addressOwnerUid(address);
        if (ownerUid != null && ownerUid != repo.uid) {
          throw StateError(
              'This address is already linked to a different Google account.');
        }
      } on StateError {
        rethrow;
      } catch (_) {
        // Preview/lookup failure (bad key format, offline, etc.) — let the
        // real import below surface the actual error, or proceed and let
        // the post-hoc sync fail silently as usual.
      }
    }
    final account = await _keystore.importAccount(key, name: name);
    await _keystore.setActiveAccountId(account.id);
    await _syncToFirestore(account);
    ref.invalidateSelf();
    return account;
  }

  Future<void> switchTo(String accountId) async {
    await _keystore.setActiveAccountId(accountId);
    ref.invalidateSelf();
  }

  Future<void> rename(String accountId, String name) async {
    final account = state.value?.accounts.firstWhere((a) => a.id == accountId, orElse: () => throw Exception('Account not found'));
    await _keystore.renameAccount(accountId, name);
    try {
      if (account != null) {
        await ref.read(firestoreRepoProvider)?.renameAccount(account.address, name);
      }
    } catch (_) {/* offline is fine */}
    ref.invalidateSelf();
  }

  Future<void> remove(String accountId) async {
    final account = state.value?.accounts.firstWhere((a) => a.id == accountId, orElse: () => throw Exception('Account not found'));
    await _keystore.removeAccount(accountId);
    try {
      if (account != null) {
        await ref.read(firestoreRepoProvider)?.deleteAccount(account.address);
      }
    } catch (_) {/* offline is fine */}
    ref.invalidateSelf();
  }

  Future<void> resetWallet() async {
    await _keystore.reset();
    ref.invalidateSelf();
  }

  Future<void> _syncToFirestore(WalletAccount account) async {
    final repo = ref.read(firestoreRepoProvider);
    if (repo == null) return;
    try {
      await repo.claimAddress(account.address);
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw StateError(
            'This address is already linked to a different Google account.');
      }
      return; // offline/other Firestore error — non-fatal
    } catch (_) {
      return; // offline — non-fatal
    }
    try {
      await repo.upsertAccount(
        accountId: account.address,
        name: account.name,
        address: account.address,
      );
    } catch (_) {/* offline is fine */}
  }
}

final accountsProvider =
    AsyncNotifierProvider<AccountsNotifier, AccountsState>(
        AccountsNotifier.new);

final activeAccountProvider = Provider<WalletAccount?>((ref) {
  return ref.watch(accountsProvider).value?.active;
});

/// Biometric ("passkey") gate. Locked on cold start when the user enabled it;
/// re-locks after 5+ minutes in background (see app.dart lifecycle observer).
class LockNotifier extends Notifier<bool> {
  static const _prefKey = 'pinace.biometricEnabled';
  final _auth = LocalAuthentication();
  DateTime? _pausedAt;

  @override
  bool build() => true; // start locked; gate decides whether to prompt

  Future<bool> isBiometricEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefKey) ?? false;
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, enabled);
  }

  Future<bool> canUseBiometrics() async {
    try {
      return await _auth.isDeviceSupported() &&
          await _auth.canCheckBiometrics;
    } catch (_) {
      return false;
    }
  }

  /// Prompts Face ID / fingerprint. When biometrics are not enabled or not
  /// available, unlocks immediately (Firebase session is then the gate).
  Future<bool> unlock() async {
    if (!await isBiometricEnabled() || !await canUseBiometrics()) {
      state = false;
      return true;
    }
    try {
      final ok = await _auth.authenticate(
        localizedReason: 'Unlock your Pinace wallet',
        persistAcrossBackgrounding: true,
      );
      if (ok) state = false;
      return ok;
    } catch (e) {
      debugPrint('Biometric unlock failed: $e');
      return false;
    }
  }

  void onAppPaused() => _pausedAt = DateTime.now();

  void onAppResumed() {
    final pausedAt = _pausedAt;
    _pausedAt = null;
    if (pausedAt != null &&
        DateTime.now().difference(pausedAt) > const Duration(minutes: 5)) {
      state = true; // re-lock; gate will prompt again
    }
  }

  void lock() => state = true;

  /// Skip the prompt (used right after first wallet setup).
  void unlockWithoutPrompt() => state = false;
}

final lockProvider = NotifierProvider<LockNotifier, bool>(LockNotifier.new);
