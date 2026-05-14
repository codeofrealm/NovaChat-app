import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class FirestoreService {
  final _fs = FirebaseFirestore.instance;

  CollectionReference get _users => _fs.collection('users');

  Future<void> createUser(UserModel user) async {
    await _users.doc(user.uid).set(user.toMap());
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
        .where((u) => u.name.toLowerCase().contains(q) || u.phone.contains(q))
        .toList();
  }
}
