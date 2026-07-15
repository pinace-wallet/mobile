import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sui/sui.dart';
import 'package:uuid/uuid.dart';

import 'account.dart';

/// Multi-account Ed25519 keystore backed by the platform secure storage
/// (Keychain / Android Keystore). Keys are stored as `suiprivkey1...` bech32
/// strings and never leave the device.
class WalletKeystore {
  WalletKeystore(this._uid);

  /// Firebase user id — accounts are scoped per signed-in user.
  final String _uid;

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  String get _accountsKey => 'pinace.accounts.$_uid';
  String _keyKey(String accountId) => 'pinace.key.$_uid.$accountId';
  String get _activeKey => 'pinace.active.$_uid';

  Future<List<WalletAccount>> listAccounts() async {
    final raw = await _storage.read(key: _accountsKey);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => WalletAccount.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> _saveAccounts(List<WalletAccount> accounts) async {
    await _storage.write(
      key: _accountsKey,
      value: jsonEncode(accounts.map((a) => a.toJson()).toList()),
    );
  }

  /// Generates a fresh Ed25519 account.
  Future<WalletAccount> createAccount({String? name}) async {
    final sui = SuiAccount.ed25519Account();
    return _addAccount(sui, name: name);
  }

  /// Imports `suiprivkey1...` (bech32) or a raw 64-hex / base64 Ed25519 seed.
  /// Throws [FormatException] on invalid input.
  Future<WalletAccount> importAccount(String privateKey, {String? name}) async {
    final sui = _parsePrivateKey(privateKey.trim());
    final address = sui.getAddress();
    final existing = await listAccounts();
    if (existing.any((a) => a.address == address)) {
      throw const FormatException('This account is already imported.');
    }
    return _addAccount(sui, name: name);
  }

  /// Derives the address for a candidate key without storing anything —
  /// used by the import screen to show the address for confirmation.
  static String previewAddress(String privateKey) =>
      _parsePrivateKey(privateKey.trim()).getAddress();

  static SuiAccount _parsePrivateKey(String input) {
    if (input.startsWith('suiprivkey')) {
      return SuiAccount.fromPrivateKey(input, SignatureScheme.Ed25519);
    }
    // Raw seed: 64 hex chars (optionally 0x-prefixed) or base64 of 32 bytes.
    var hex = input.startsWith('0x') ? input.substring(2) : input;
    if (!RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(hex)) {
      try {
        final bytes = base64Decode(input);
        if (bytes.length != 32) {
          throw const FormatException('Expected a 32-byte key');
        }
        hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      } on FormatException {
        rethrow;
      } catch (_) {
        throw const FormatException(
            'Enter a suiprivkey1..., 64-char hex, or base64 key.');
      }
    }
    return SuiAccount.fromPrivateKey(hex, SignatureScheme.Ed25519);
  }

  Future<WalletAccount> _addAccount(SuiAccount sui, {String? name}) async {
    final accounts = await listAccounts();
    final account = WalletAccount(
      id: const Uuid().v4(),
      name: name ?? 'Account ${accounts.length + 1}',
      address: sui.getAddress(),
      createdAt: DateTime.now(),
    );
    // encodeSuiPrivateKey -> suiprivkey1... bech32
    final exported = encodeSuiPrivateKey(
      sui.keyPair.getSecretKey().sublist(0, 32),
      SignatureScheme.Ed25519,
    );
    await _storage.write(key: _keyKey(account.id), value: exported);
    await _saveAccounts([...accounts, account]);
    return account;
  }

  /// Loads the signing account. Returns null if the key is missing.
  Future<SuiAccount?> loadSigner(String accountId) async {
    final raw = await _storage.read(key: _keyKey(accountId));
    if (raw == null) return null;
    return SuiAccount.fromPrivateKey(raw, SignatureScheme.Ed25519);
  }

  /// Returns the `suiprivkey1...` export string (caller must gate with
  /// biometrics before displaying).
  Future<String?> exportKey(String accountId) => _storage.read(key: _keyKey(accountId));

  Future<void> renameAccount(String accountId, String name) async {
    final accounts = await listAccounts();
    await _saveAccounts([
      for (final a in accounts)
        if (a.id == accountId) a.copyWith(name: name) else a,
    ]);
  }

  /// Removes an account and its key. Refuses to remove the last account.
  Future<void> removeAccount(String accountId) async {
    final accounts = await listAccounts();
    if (accounts.length <= 1) {
      throw StateError('Cannot remove the last account.');
    }
    await _storage.delete(key: _keyKey(accountId));
    await _saveAccounts(accounts.where((a) => a.id != accountId).toList());
    if (await getActiveAccountId() == accountId) {
      final remaining = accounts.where((a) => a.id != accountId).toList();
      await setActiveAccountId(remaining.first.id);
    }
  }

  Future<String?> getActiveAccountId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_activeKey);
  }

  Future<void> setActiveAccountId(String accountId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeKey, accountId);
  }

  /// Wipes every account and key for this user (Profile > Reset wallet).
  Future<void> reset() async {
    final accounts = await listAccounts();
    for (final a in accounts) {
      await _storage.delete(key: _keyKey(a.id));
    }
    await _storage.delete(key: _accountsKey);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_activeKey);
  }
}
