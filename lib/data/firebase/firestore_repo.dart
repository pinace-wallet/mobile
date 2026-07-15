import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Per-user metadata in Firestore. Never stores key material — only public
/// addresses, display names, and preferences.
///
/// Layout:
///   users/{uid}                      email, displayName, fcmTokens{}, prefs
///   users/{uid}/accounts/{accId}     name, address, order, createdAt
///   users/{uid}/agentMeta/{agentId}  nickname
class FirestoreRepo {
  FirestoreRepo(this._uid);

  final String _uid;
  final _db = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> get _userDoc =>
      _db.collection('users').doc(_uid);

  Future<void> ensureUserDoc(User user) async {
    await _userDoc.set({
      'email': user.email,
      'displayName': user.displayName,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> upsertAccount({
    required String accountId,
    required String name,
    required String address,
    int order = 0,
  }) async {
    await _userDoc.collection('accounts').doc(accountId).set({
      'name': name,
      'address': address,
      'order': order,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> renameAccount(String accountId, String name) =>
      _userDoc.collection('accounts').doc(accountId).update({'name': name});

  Future<void> deleteAccount(String accountId) =>
      _userDoc.collection('accounts').doc(accountId).delete();

  Future<void> setAgentNickname(String agentId, String nickname) =>
      _userDoc.collection('agentMeta').doc(agentId).set({
        'nickname': nickname,
      }, SetOptions(merge: true));

  Future<Map<String, String>> getAgentNicknames() async {
    final snap = await _userDoc.collection('agentMeta').get();
    return {
      for (final doc in snap.docs)
        if (doc.data()['nickname'] is String)
          doc.id: doc.data()['nickname'] as String,
    };
  }

  Future<void> registerFcmToken(String token, String platform) =>
      _userDoc.set({
        'fcmTokens': {
          token: {'platform': platform, 'updatedAt': FieldValue.serverTimestamp()},
        },
      }, SetOptions(merge: true));

  Future<void> setNotificationsEnabled(bool enabled) => _userDoc.set({
        'prefs': {'notifications': enabled},
      }, SetOptions(merge: true));
}
