import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// テストピース閲覧履歴 (`users/{uid}/view_history`) のリポジトリ。
///
/// ドキュメントID = テストピースID、本文は最終閲覧日時のみ。
class ViewHistoryRepository {
  final FirebaseFirestore db;
  final FirebaseAuth auth;

  ViewHistoryRepository({FirebaseFirestore? db, FirebaseAuth? auth})
    : db = db ?? FirebaseFirestore.instance,
      auth = auth ?? FirebaseAuth.instance;

  String? get _userId => auth.currentUser?.uid;

  /// 閲覧履歴を更新または作成する。未ログイン時は何もしない。
  Future<void> record(String testPieceId) async {
    final uid = _userId;
    if (uid == null) return;
    await db
        .collection('users')
        .doc(uid)
        .collection('view_history')
        .doc(testPieceId)
        .set({'viewedAt': FieldValue.serverTimestamp()});
  }

  /// 最近見たテストピースのIDリストを監視する (新しい順)
  Stream<List<String>> watchRecentIds({int limit = 20}) {
    final uid = _userId;
    if (uid == null) return Stream.value([]);
    return db
        .collection('users')
        .doc(uid)
        .collection('view_history')
        .orderBy('viewedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.id).toList());
  }
}
