import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class FirestoreService {
  final _fs = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _users =>
      _fs.collection('users');
  CollectionReference<Map<String, dynamic>> get _userEmails =>
      _fs.collection('user_emails');
  CollectionReference<Map<String, dynamic>> get _userPhones =>
      _fs.collection('user_phones');

  String _normalizeEmail(String email) => email.trim().toLowerCase();

  String _normalizePhone(String phone) =>
      phone.trim().replaceAll(RegExp(r'[\s\-\(\)]'), '');

  Future<void> createUser(UserModel user) async {
    final emailKey = _normalizeEmail(user.email);
    final phoneKey = _normalizePhone(user.phone);

    if (emailKey.isEmpty) {
      throw Exception('Email is required.');
    }
    if (phoneKey.isEmpty) {
      throw Exception('Phone number is required.');
    }

    final userRef = _users.doc(user.uid);
    final emailRef = _userEmails.doc(emailKey);
    final phoneRef = _userPhones.doc(phoneKey);

    await _fs.runTransaction((transaction) async {
      final existingUser = await transaction.get(userRef);
      final existingEmail = await transaction.get(emailRef);
      final existingPhone = await transaction.get(phoneRef);

      final emailUid = existingEmail.data()?['uid'] as String?;
      final phoneUid = existingPhone.data()?['uid'] as String?;

      if (existingUser.exists) {
        throw Exception('Account already exists for this phone number.');
      }
      if (emailUid != null && emailUid != user.uid) {
        throw Exception('Email already registered. Please use another email.');
      }
      if (phoneUid != null && phoneUid != user.uid) {
        throw Exception('Phone number already registered. Please login.');
      }

      final data = user.toMap()
        ..['emailLower'] = emailKey
        ..['phoneNormalized'] = phoneKey;

      transaction.set(userRef, data);
      transaction.set(emailRef, {
        'uid': user.uid,
        'email': user.email,
        'createdAt': user.createdAt,
      });
      transaction.set(phoneRef, {
        'uid': user.uid,
        'phone': user.phone,
        'createdAt': user.createdAt,
      });
    });
  }

  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    await _users.doc(uid).set(data, SetOptions(merge: true));
  }

  Future<UserModel?> getUser(String uid) async {
    final doc = await _users.doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromMap(doc.data() as Map, uid);
  }

  Stream<UserModel?> userStream(String uid) {
    return _users.doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return UserModel.fromMap(doc.data() as Map, uid);
    });
  }

  Future<UserModel?> getUserByPhone(String phone) async {
    if (phone.isEmpty) return null;
    final phoneKey = _normalizePhone(phone);
    final index = await _userPhones.doc(phoneKey).get();
    if (index.exists) {
      final uid = index.data()?['uid'] as String?;
      if (uid != null && uid.isNotEmpty) return getUser(uid);
    }
    final snap = await _users
        .where('phoneNormalized', isEqualTo: phoneKey)
        .limit(1)
        .get();
    if (snap.docs.isNotEmpty) {
      final doc = snap.docs.first;
      return UserModel.fromMap(doc.data() as Map, doc.id);
    }

    final legacySnap =
        await _users.where('phone', isEqualTo: phone).limit(1).get();
    if (legacySnap.docs.isEmpty) return null;
    final doc = legacySnap.docs.first;
    return UserModel.fromMap(doc.data() as Map, doc.id);
  }

  Future<UserModel?> getUserByEmail(String email) async {
    if (email.isEmpty) return null;
    final emailKey = _normalizeEmail(email);
    final index = await _userEmails.doc(emailKey).get();
    if (index.exists) {
      final uid = index.data()?['uid'] as String?;
      if (uid != null && uid.isNotEmpty) return getUser(uid);
    }
    final snap = await _users
        .where('emailLower', isEqualTo: emailKey)
        .limit(1)
        .get();
    if (snap.docs.isNotEmpty) {
      final doc = snap.docs.first;
      return UserModel.fromMap(doc.data() as Map, doc.id);
    }

    final legacySnap =
        await _users.where('email', isEqualTo: emailKey).limit(1).get();
    if (legacySnap.docs.isEmpty) return null;
    final doc = legacySnap.docs.first;
    return UserModel.fromMap(doc.data() as Map, doc.id);
  }

  Future<List<UserModel>> getAllUsers(String currentUid) async {
    if (currentUid.isEmpty) return [];
    final snap = await _users
        .where(FieldPath.documentId, isNotEqualTo: currentUid)
        .get();
    return snap.docs
        .map((d) => UserModel.fromMap(d.data() as Map, d.id))
        .toList();
  }

  Future<List<UserModel>> searchUsers(String query, String currentUid) async {
    if (currentUid.isEmpty) return [];
    final all = await getAllUsers(currentUid);
    final q = query.toLowerCase();
    return all
        .where((u) =>
            u.name.toLowerCase().contains(q) ||
            u.phone.contains(q) ||
            u.email.toLowerCase().contains(q))
        .toList();
  }
}
