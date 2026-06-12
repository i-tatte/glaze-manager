import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:glaze_manager/models/test_piece.dart';
import 'package:glaze_manager/repositories/user_scoped_repository.dart';

class TestPieceRepository extends UserScopedRepository<TestPiece> {
  TestPieceRepository({super.db, super.auth});

  @override
  String get collectionName => 'test_pieces';

  @override
  TestPiece fromFirestore(DocumentSnapshot<Map<String, dynamic>> snapshot) =>
      TestPiece.fromFirestore(snapshot);

  @override
  Map<String, dynamic> toFirestore(TestPiece item) => item.toFirestore();

  @override
  Query<Map<String, dynamic>> orderQuery(
    CollectionReference<Map<String, dynamic>> ref,
  ) => ref.orderBy('createdAt', descending: true);

  /// 新規ドキュメントIDを発行する (書き込みはまだ行わない)。
  /// 画像アップロードパスにIDを含めるため、保存前にIDを確定させる用途。
  String newDocumentId() => collection.doc().id;

  /// 指定IDでドキュメントを作成する (newDocumentIdとセットで使用)
  Future<void> setById(String id, TestPiece piece) async {
    await collection.doc(id).set(toFirestore(piece));
  }

  /// 特定の釉薬を使用するテストピース一覧を監視する (メイン・追加釉薬の両方を含む)
  ///
  /// firestore.indexes.json の複合インデックス
  /// (relatedGlazeIds CONTAINS + createdAt DESC) が必要。
  Stream<List<TestPiece>> watchForGlaze(String glazeId) {
    if (userId == null) return Stream.value([]);
    return collection
        .where('relatedGlazeIds', arrayContains: glazeId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(fromFirestore).toList());
  }
}
