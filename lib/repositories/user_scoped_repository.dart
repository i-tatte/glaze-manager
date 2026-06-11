import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// `users/{uid}/{collectionName}` 配下のコレクションに対する共通CRUDを提供する基底クラス。
///
/// 各エンティティのリポジトリはこれを継承し、コレクション名と
/// Firestoreドキュメント⇔モデルの変換だけを実装する。
abstract class UserScopedRepository<T> {
  final FirebaseFirestore db;
  final FirebaseAuth auth;

  UserScopedRepository({FirebaseFirestore? db, FirebaseAuth? auth})
    : db = db ?? FirebaseFirestore.instance,
      auth = auth ?? FirebaseAuth.instance;

  /// `users/{uid}/` 直下のコレクション名
  String get collectionName;

  T fromFirestore(DocumentSnapshot<Map<String, dynamic>> snapshot);

  Map<String, dynamic> toFirestore(T item);

  /// 一覧取得時の並び順。デフォルトは並び替えなし。
  Query<Map<String, dynamic>> orderQuery(
    CollectionReference<Map<String, dynamic>> ref,
  ) => ref;

  String? get userId => auth.currentUser?.uid;

  /// ログイン中ユーザーのコレクション参照。未ログインなら例外。
  CollectionReference<Map<String, dynamic>> get collection {
    final uid = userId;
    if (uid == null) throw Exception('User not logged in');
    return db.collection('users').doc(uid).collection(collectionName);
  }

  /// 一覧をリアルタイム監視する。未ログイン時は空リストを流す。
  Stream<List<T>> watchAll() {
    if (userId == null) return Stream.value([]);
    return orderQuery(
      collection,
    ).snapshots().map((s) => s.docs.map(fromFirestore).toList());
  }

  /// 一覧を1回だけ取得する (リスナーを張らない)。未ログイン時は空リスト。
  Future<List<T>> getAll() async {
    if (userId == null) return [];
    final s = await orderQuery(collection).get();
    return s.docs.map(fromFirestore).toList();
  }

  /// 特定ドキュメントをリアルタイム監視する。
  Stream<T> watchById(String id) {
    if (userId == null) return Stream.error('User not logged in');
    return collection.doc(id).snapshots().map(fromFirestore);
  }

  Future<void> add(T item) async {
    await collection.add(toFirestore(item));
  }

  Future<void> updateById(String? id, T item) async {
    if (id == null) {
      throw Exception('$collectionName: ID is required for update');
    }
    await collection.doc(id).update(toFirestore(item));
  }

  Future<void> deleteById(String id) async {
    await collection.doc(id).delete();
  }
}
