import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// タグマスター (`users/{uid}/tags`) のリポジトリ。
///
/// タグはドキュメントID = タグ名で、本文は作成日時のみという特殊構造のため、
/// UserScopedRepository を継承せず独立して実装する。
class TagRepository {
  final FirebaseFirestore db;
  final FirebaseAuth auth;

  TagRepository({FirebaseFirestore? db, FirebaseAuth? auth})
    : db = db ?? FirebaseFirestore.instance,
      auth = auth ?? FirebaseAuth.instance;

  String? get _userId => auth.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> get _collection {
    final uid = _userId;
    if (uid == null) throw Exception('User not logged in');
    return db.collection('users').doc(uid).collection('tags');
  }

  /// タグ名一覧を監視する (作成日時の新しい順)
  Stream<List<String>> watchAll() {
    if (_userId == null) return Stream.value([]);
    return _collection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.id).toList());
  }

  /// タグ名一覧を1回だけ取得する
  Future<List<String>> getAll() async {
    if (_userId == null) return [];
    final snapshot = await _collection
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs.map((doc) => doc.id).toList();
  }

  /// タグを追加 (存在しない場合のみ)
  Future<void> add(String tagName) async {
    final docRef = _collection.doc(tagName);
    final doc = await docRef.get();
    if (!doc.exists) {
      await docRef.set({'createdAt': FieldValue.serverTimestamp()});
    }
  }

  /// 複数のタグをまとめて追加 (存在しないものだけ作成)
  Future<void> addAll(List<String> tagNames) async {
    if (tagNames.isEmpty) return;

    final existing = (await getAll()).toSet();
    final batch = db.batch();
    var hasNew = false;
    for (final name in tagNames.toSet()) {
      if (existing.contains(name)) continue;
      batch.set(_collection.doc(name), {
        'createdAt': FieldValue.serverTimestamp(),
      });
      hasNew = true;
    }
    if (hasNew) await batch.commit();
  }

  /// タグを削除 (マスターリストからのみ削除。釉薬に付いたタグは消えない)
  Future<void> delete(String tagName) async {
    await _collection.doc(tagName).delete();
  }
}
